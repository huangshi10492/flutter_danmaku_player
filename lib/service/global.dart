import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:signals/signals_core.dart';

class GlobalService {
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
  String version = '';

  static Future<void> register() async {
    final service = GlobalService();
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
    final packageInfo = await PackageInfo.fromPlatform();
    version = packageInfo.version;
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
}
