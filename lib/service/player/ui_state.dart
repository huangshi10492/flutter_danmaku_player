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
  final brightnessVolumeService = BrightnessVolumeService();
  final Signal<int> batteryLevel = Signal(0);
  final Signal<bool> batteryChange = Signal(false);
  final Signal<String> currentTime = Signal('');
  final Signal<IndicatorType> inndicatorType = Signal(.none);
  final Signal<double> indicatorValue = Signal(0.0);
  final Signal<Duration> seekPosition = Signal(Duration.zero);
  final Signal<int> seekOffset = Signal(0);
  final Signal<bool> longPress = Signal(false);
  final Signal<bool> isFullScreen = Signal(false);
  final Signal<bool> lockPanel = Signal(false);
  final Signal<bool> saveScreenshoting = Signal(false);

  Timer? _timeTimer;
  Timer? _hideControlsTimer;
  Timer? _hideIndicatorTimer;
  double initialVolumeOnPan = 0;
  double initialBrightnessOnPan = 0;
  Duration initialPositionOnPan = .zero;

  Future<void> init() async {
    await brightnessVolumeService.initialize();
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
  Future<void> startGesture(Duration initialPosition) async {
    if (!Utils.isDesktop()) {
      await FlutterVolumeController.updateShowSystemUI(false);
    }
    _hideIndicatorTimer?.cancel();
    initialVolumeOnPan = brightnessVolumeService.currentVolume;
    initialBrightnessOnPan = brightnessVolumeService.currentBrightness;
    initialPositionOnPan = initialPosition;
    showControls.value = false;
  }

  /// 结束手势操作
  Future<void> endGesture() async {
    if (!Utils.isDesktop()) {
      await FlutterVolumeController.updateShowSystemUI(true);
    }
    hideIndicator();
  }

  /// 开始长按（倍速）
  void startLongPress(double speed) {
    batch(() {
      longPress.value = true;
      inndicatorType.value = .speed;
      indicatorValue.value = speed;
    });
  }

  /// 结束长按（倍速）
  void endLongPress() {
    batch(() {
      longPress.value = false;
      inndicatorType.value = .none;
    });
  }

  /// 显示音量控制
  void setVolume(double volume) {
    batch(() {
      inndicatorType.value = .volume;
      indicatorValue.value = volume;
    });
    brightnessVolumeService.setVolume(volume);
  }

  /// 显示亮度控制
  void setBrightness(double brightness) {
    batch(() {
      inndicatorType.value = .brightness;
      indicatorValue.value = brightness;
    });
    brightnessVolumeService.setBrightness(brightness);
  }

  void hideIndicator() {
    _hideIndicatorTimer?.cancel();
    final type = inndicatorType.value;
    if (type.delay) {
      _hideIndicatorTimer = Timer(
        const Duration(seconds: 1),
        () => inndicatorType.value = .none,
      );
    } else {
      () => inndicatorType.value = .none;
    }
  }

  void dispose() {
    _hideControlsTimer?.cancel();
    _hideIndicatorTimer?.cancel();
    _timeTimer?.cancel();
    brightnessVolumeService.dispose();
  }
}

/// 亮度控制服务
class BrightnessVolumeService {
  static final _log = Logger('BrightnessVolumeService');
  static final _configureService = GetIt.I<ConfigureService>();
  double currentBrightness = 0.5;
  double currentVolume = 0.5;

  Future<void> initialize() async {
    try {
      if (!Utils.isDesktop()) {
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
      currentBrightness = 0.5;
      currentVolume = 0.5;
    }
  }

  /// 设置亮度
  Future<void> setBrightness(double brightness) async {
    brightness = brightness.clamp(0.0, 1.0);
    currentBrightness = brightness;
    try {
      await ScreenBrightness().setApplicationScreenBrightness(brightness);
    } catch (e, t) {
      _log.error('setBrightness', '设置亮度失败', error: e, stackTrace: t);
    }
  }

  /// 重置为系统亮度
  Future<void> resetToSystemBrightness() async {
    if (Utils.isDesktop()) return;
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (e, t) {
      _log.error('resetToSystemBrightness', '重置亮度失败', error: e, stackTrace: t);
    }
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    volume = volume.clamp(0.0, 1.0);
    currentVolume = volume;
    if (!Utils.isDesktop()) {
      await FlutterVolumeController.setVolume(volume);
    } else {
      _configureService.desktopVolume.value = volume;
    }
  }

  void dispose() {
    resetToSystemBrightness();
    if (!Utils.isDesktop()) {
      FlutterVolumeController.removeListener();
    }
  }
}
