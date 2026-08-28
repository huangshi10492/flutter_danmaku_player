import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:fldanplay/model/update.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:signals/signals_core.dart';

class GlobalService {
  final ConfigureService _configureService;

  GlobalService(this._configureService);
  String videoName = '';
  double speed = 0;
  final Signal<int> position = signal(0);
  final Signal<bool> isPlaying = signal(false);
  final Signal<Map<String, int>> danmakuCount = signal({
    'BiliBili': 0,
    'Gamer': 0,
    'DanDanPlay': 0,
    'Other': 0,
  });
  final Signal<UpdateResponse?> updateInfo = signal(null);
  int get danmakuCountValue {
    return danmakuCount.value.values.fold(
      0,
      (previous, element) => previous + element,
    );
  }

  late BuildContext playerNotificationContext;
  late BuildContext appContext;
  Function(String)? updateListener;
  String device = 'Unknown';
  String deviceId = 'Unknown';
  int androidSdkVersion = 0;
  PackageInfo packageInfo = .new(
    appName: 'fldanplay',
    packageName: 'fldanplay',
    version: '0.0.1',
    buildNumber: '1',
  );
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  final _logger = Logger('GlobalService');

  static Future<void> register(ConfigureService cs) async {
    final service = GlobalService(cs);
    GetIt.I.registerSingleton<GlobalService>(service);
    await service.init();
  }

  Future<void> init() async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    if (deviceInfo is AndroidDeviceInfo) {
      device = deviceInfo.name;
      deviceId = deviceInfo.id;
      androidSdkVersion = deviceInfo.version.sdkInt;
    } else if (deviceInfo is IosDeviceInfo) {
      device = deviceInfo.name;
      deviceId = deviceInfo.identifierForVendor!;
    } else if (deviceInfo is MacOsDeviceInfo) {
      device = deviceInfo.hostName;
      deviceId = deviceInfo.systemGUID ?? 'null';
    } else if (deviceInfo is WindowsDeviceInfo) {
      device = deviceInfo.computerName;
      deviceId = deviceInfo.deviceId;
    } else if (deviceInfo is LinuxDeviceInfo) {
      device = deviceInfo.name;
      deviceId = deviceInfo.machineId ?? deviceInfo.id;
    }
    packageInfo = await PackageInfo.fromPlatform();
    Future(() async {
      try {
        if (_configureService.checkUpdate.value) await checkUpdate();
      } catch (_) {}
    });
  }

  void showNotification(String message) {
    if (!playerNotificationContext.mounted) return;
    showRawFToast(
      context: playerNotificationContext,
      alignment: FToastAlignment.bottomLeft,
      duration: Duration(seconds: 3),
      builder: (context, entry) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade900.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(message, style: TextStyle(color: Colors.white)),
        );
      },
    );
  }

  Future<bool> checkUpdate() async {
    try {
      updateInfo.value = null;
      final response = await _dio.get(
        'https://fldanplay.huangshi10492.top/api/updates',
        queryParameters: {'version': packageInfo.version},
      );
      if (response.statusCode == 200 && response.data != null) {
        final updateResponse = UpdateResponse.fromJson(response.data);
        updateInfo.value = updateResponse;
        return (updateResponse.hasUpdate) ? true : false;
      } else {
        _logger.warn('checkUpdate', '请求更新接口失败，状态码: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e, t) {
      _logger.dio('checkUpdate', e, t, action: '检查更新');
    } catch (e, t) {
      _logger.error('checkUpdate', '检查更新失败', error: e, stackTrace: t);
      return false;
    }
  }
}
