import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:fldanplay/page/player/indicator.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:signals_flutter/signals_flutter.dart';

class PlayerUIState {
  final Signal<bool> showControls = Signal(true);
  final Battery _battery = Battery();
  final Signal<int> batteryLevel = Signal(0);
  final Signal<bool> batteryChange = Signal(false);
  final Signal<String> currentTime = Signal('');
  final Signal<bool> showProgressIndicator = Signal(false);
  final Signal<IndicatorType> activeIndicator = Signal(IndicatorType.none);
  final Signal<double> indicatorValue = Signal(0.0);
  final Signal<double> currentVolume = Signal(0.5);
  final Signal<double> currentBrightness = Signal(0.5);
  final Signal<String> progressIndicatorText = Signal('');
  final Signal<bool> longPress = Signal(false);
  final Signal<bool> isFullScreen = Signal(false);

  Timer? _timeTimer;
  Timer? _hideControlsTimer;
  Timer? _hideIndicatorTimer;
  double? initialVolumeOnPan;
  double? initialBrightnessOnPan;
  Duration? initialPositionOnPan;

  Future<void> init() async {
    await BrightnessVolumeService.initialize();
    currentVolume.value = BrightnessVolumeService.currentVolume;
    currentBrightness.value = BrightnessVolumeService.currentBrightness;

    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      currentTime.value = DateFormat('HH:mm').format(DateTime.now());
      try {
        batteryLevel.value = await _battery.batteryLevel;
        batteryChange.value =
            (await _battery.batteryState) == BatteryState.charging;
      } catch (e) {
        // ignore
      }
    });
  }

  /// 显示控制栏并设置自动隐藏
  void showControlsTemporarily() {
    _hideControlsTimer?.cancel();
    showControls.value = true;
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      showControls.value = false;
    });
  }

  /// 更新控制栏显示状态
  void updateControlsVisibility(bool show) {
    _hideControlsTimer?.cancel();
    showControls.value = show;
  }

  /// 开始手势操作
  Future<void> startGesture({Duration? initialPosition}) async {
    if (!Utils.isDesktop()) {
      await FlutterVolumeController.updateShowSystemUI(false);
    }
    initialVolumeOnPan = currentVolume.value;
    initialBrightnessOnPan = currentBrightness.value;
    initialPositionOnPan = initialPosition;
    showControls.value = false;
  }

  /// 结束手势操作
  Future<void> endGesture() async {
    hideAllIndicators();
    initialVolumeOnPan = null;
    initialBrightnessOnPan = null;
    initialPositionOnPan = null;
    if (!Utils.isDesktop()) {
      await FlutterVolumeController.updateShowSystemUI(true);
    }
  }

  /// 开始长按（倍速）
  void startLongPress(double speed) {
    longPress.value = true;
    showIndicator(IndicatorType.speed, speed, permanent: true);
  }

  /// 结束长按（倍速）
  void endLongPress() {
    longPress.value = false;
    hideIndicator();
  }

  /// 显示音量控制
  void setVolume(double volume) {
    currentVolume.value = volume;
    showIndicator(IndicatorType.volume, volume);
  }

  /// 显示亮度控制
  void setBrightness(double brightness) {
    currentBrightness.value = brightness;
    showIndicator(IndicatorType.brightness, brightness);
  }

  /// 显示进度指示器
  void setProgressIndicator(String text) {
    batch(() {
      progressIndicatorText.value = text;
      showProgressIndicator.value = true;
      hideIndicator();
    });
  }

  /// 隐藏所有控制指示器
  void hideAllIndicators() {
    batch(() {
      showProgressIndicator.value = false;
    });
  }

  /// 显示一个通用的指示器（如音量、亮度、速度）
  void showIndicator(
    IndicatorType type,
    double value, {
    bool permanent = false,
  }) {
    activeIndicator.value = type;
    indicatorValue.value = value;
    showProgressIndicator.value = false;

    _hideIndicatorTimer?.cancel();
    if (!permanent) {
      _hideIndicatorTimer = Timer(const Duration(seconds: 1), hideIndicator);
    }
  }

  /// 隐藏指示器
  void hideIndicator() {
    activeIndicator.value = IndicatorType.none;
  }

  void dispose() {
    _hideControlsTimer?.cancel();
    _hideIndicatorTimer?.cancel();
    _timeTimer?.cancel();
    showControls.dispose();
    showProgressIndicator.dispose();
    activeIndicator.dispose();
    indicatorValue.dispose();
    currentVolume.dispose();
    currentBrightness.dispose();
    progressIndicatorText.dispose();
  }
}

/// 亮度控制服务
class BrightnessVolumeService {
  static final _log = Logger('BrightnessVolumeService');
  static final _configureService = GetIt.I<ConfigureService>();
  static double currentBrightness = 0.5;
  static double _systemBrightness = 0.5;
  static double currentVolume = 0.5;

  static Future<void> initialize() async {
    try {
      if (!Utils.isDesktop()) {
        _systemBrightness = await ScreenBrightness().system;
        currentBrightness = await ScreenBrightness().application;
        currentVolume = await FlutterVolumeController.getVolume() ?? 0.5;
        FlutterVolumeController.addListener((volume) {
          currentVolume = volume;
        });
      } else {
        currentVolume = _configureService.desktopVolume.value;
      }
    } catch (e, t) {
      _log.error('initialize', '初始化亮度音量服务失败', error: e, stackTrace: t);
      _systemBrightness = 0.5;
      currentBrightness = 0.5;
      currentVolume = 0.5;
    }
  }

  /// 设置亮度
  static Future<void> setBrightness(double brightness) async {
    brightness = brightness.clamp(0.0, 1.0);
    currentBrightness = brightness;
    try {
      await ScreenBrightness().setApplicationScreenBrightness(brightness);
    } catch (e, t) {
      _log.error('setBrightness', '设置亮度失败', error: e, stackTrace: t);
    }
  }

  /// 重置为系统亮度
  static Future<void> resetToSystemBrightness() async {
    if (Utils.isDesktop()) return;
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
      currentBrightness = _systemBrightness;
    } catch (e, t) {
      _log.error('resetToSystemBrightness', '重置亮度失败', error: e, stackTrace: t);
    }
  }

  /// 设置音量
  static Future<void> setVolume(double volume) async {
    volume = volume.clamp(0.0, 1.0);
    currentVolume = volume;
    if (!Utils.isDesktop()) {
      await FlutterVolumeController.setVolume(volume);
    } else {
      _configureService.desktopVolume.value = volume;
    }
  }

  static void dispose() {
    resetToSystemBrightness();
    if (!Utils.isDesktop()) {
      FlutterVolumeController.removeListener();
    }
  }
}
