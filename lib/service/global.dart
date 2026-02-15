import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
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

  late BuildContext notificationContext;
  late BuildContext playerContext;
  Function(String)? updateListener;
  String device = 'Unknown';
  String deviceId = 'Unknown';

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
    } else if (deviceInfo is IosDeviceInfo) {
      device = deviceInfo.name;
      deviceId = deviceInfo.identifierForVendor!;
    }
  }

  void showNotification(String message) {
    if (!notificationContext.mounted) return;
    showRawFToast(
      context: notificationContext,
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
