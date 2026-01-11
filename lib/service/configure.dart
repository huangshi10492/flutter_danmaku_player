import 'dart:convert';
import 'package:fldanplay/model/danmaku.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 配置服务
/// 提供类型安全的配置项管理，支持默认值和持久化存储
class ConfigureService {
  late final Box _box;

  ConfigureService._(this._box);

  static Future<ConfigureService> register() async {
    final box = await Hive.openBox('configure');
    final service = ConfigureService._(box);
    GetIt.I.registerSingleton<ConfigureService>(service);
    return service;
  }

  Signal<T> _config<T>({required String key, required T defaultValue}) {
    final value = _box.get(key, defaultValue: defaultValue) as T;
    final signal = Signal<T>(value);
    effect(() {
      _box.put(key, signal.value);
    });
    return signal;
  }

  Signal<T> _configWithLoader<T>({
    required T Function() load,
    required Future<void> Function(T value) save,
  }) {
    final signal = Signal<T>(load());
    effect(() {
      save(signal.value);
    });
    return signal;
  }

  late final Signal<double> defaultPlaySpeed = _config(
    key: 'defaultPlaySpeed',
    defaultValue: 1.0,
  );
  late final Signal<double> doublePlaySpeed = _config(
    key: 'doublePlaySpeed',
    defaultValue: 2.0,
  );
  // 倍数播放是否跟随当前速度
  late final Signal<bool> doubleWithNowSpeed = _config(
    key: 'doubleWithNowSpeed',
    defaultValue: false,
  );
  late final Signal<int> forwardSeconds = _config(
    key: 'forwardSeconds',
    defaultValue: 10,
  );
  late final Signal<int> backwardSeconds = _config(
    key: 'backwardSeconds',
    defaultValue: 10,
  );
  late final Signal<int> seekOPSeconds = _config(
    key: 'seekOPSeconds',
    defaultValue: 85,
  );
  // 自动为字幕和弹幕选择语言（0: 关闭，1: 中文简体，2: 中文繁体）
  late final Signal<int> autoLanguage = _config(
    key: 'autoLanguage',
    defaultValue: 1,
  );
  // 自动为音频选择日语
  late final Signal<bool> autoAudioLanguage = _config(
    key: 'autoAudioLanguage',
    defaultValue: true,
  );
  late final Signal<bool> hardwareDecoderEnable = _config(
    key: 'hardwareDecoderEnable',
    defaultValue: true,
  );
  late final Signal<String> hardwareDecoder = _config(
    key: 'hardwareDecoder',
    defaultValue: 'auto',
  );
  late final Signal<bool> lowMemoryMode = _config(
    key: 'lowMemoryMode',
    defaultValue: false,
  );
  late final Signal<bool> playerDebugMode = _config(
    key: 'playerDebugMode',
    defaultValue: false,
  );
  late final Signal<bool> audioTrack = _config(
    key: 'audioTrack',
    defaultValue: false,
  );
  late final Signal<DanmakuSettings> danmakuSettings = _configWithLoader(
    load: getDanmakuSettings,
    save: setDanmakuSettings,
  );
  late final Signal<String> themeMode = _config(
    key: 'themeMode',
    defaultValue: '0',
  );
  late final Signal<String> themeColor = _config(
    key: 'themeColor',
    defaultValue: 'blue',
  );
  late final Signal<bool> offlineCacheFirst = _config(
    key: 'offlineCacheFirst',
    defaultValue: true,
  );
  late final Signal<bool> syncEnable = _config(
    key: 'syncEnable',
    defaultValue: false,
  );
  late final Signal<bool> danmakuServiceEnable = _config(
    key: 'danmakuServiceEnable',
    defaultValue: false,
  );
  late final Signal<bool> defaultDanmakuEnable = _config(
    key: 'defaultDanmakuEnable',
    defaultValue: true,
  );
  late final Signal<List<String>> danmakuServerList = _config(
    key: 'danmakuServerList',
    defaultValue: ['https://danmaku.huangshi10492.top/huangshi10492'],
  );
  // 日志级别配置 (0: DEBUG, 1: INFO, 2: WARNING, 3: ERROR)
  late final Signal<String> logLevel = _config(
    key: 'logLevel',
    defaultValue: '1', // 默认为INFO级别
  );
  late final Signal<String> webDavURL = _config(
    key: 'webDavURL',
    defaultValue: '',
  );
  late final Signal<String> webDavUsername = _config(
    key: 'webDavUsername',
    defaultValue: '',
  );
  late final Signal<String> webDavPassword = _config(
    key: 'webDavPassword',
    defaultValue: '',
  );
  late final Signal<int> lastSyncTime = _config(
    key: 'lastSyncTime',
    defaultValue: 0,
  );
  late final Signal<String> subtitleFontName = _config(
    key: 'subtitleFontName',
    defaultValue: '',
  );
  late final Signal<double> desktopVolume = _config(
    key: 'desktopVolume',
    defaultValue: 0.9,
  );

  DanmakuSettings getDanmakuSettings() {
    final jsonString = _box.get('danmakuSettings');
    if (jsonString == null) {
      return DanmakuSettings();
    }
    return DanmakuSettings.fromJson(
      jsonDecode(utf8.decode(base64Decode(jsonString))),
    );
  }

  Future<void> setDanmakuSettings(DanmakuSettings settings) async {
    await _box.put(
      'danmakuSettings',
      base64Encode(utf8.encode(jsonEncode(settings.toJson()))),
    );
  }
}
