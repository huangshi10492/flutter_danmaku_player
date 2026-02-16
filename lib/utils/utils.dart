import 'dart:io';

import 'package:intl/intl.dart' as intl;

class Utils {
  /// 判断是否为桌面设备
  static bool isDesktop() {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// 格式化时长显示
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  static String formatTime(int position, int duration) {
    return '${formatDuration(Duration(milliseconds: position))}/${formatDuration(Duration(milliseconds: duration))}';
  }

  static String formatDateTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return intl.DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  // 格式化最后观看时间
  static String formatLastWatchTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}年前';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  static double speedToSlider(double y) {
    y = y.clamp(0.1, 4.0);
    if (y >= 0.1 && y < 0.7) {
      return 10 * y;
    } else if (y >= 0.7 && y < 1.3) {
      return 20 * (y - 0.35);
    } else if (y >= 1.3 && y < 1.5) {
      return 10 * (y + 0.6);
    } else if (y >= 1.5 && y < 2.5) {
      return 4 * (y + 3.75);
    } else if (y >= 2.5 && y <= 4.0) {
      return 2 * (y + 10);
    } else {
      return 7;
    }
  }

  static double sliderToSpeed(double x) {
    x = x.clamp(1, 46);
    if (x >= 1 && x < 7) {
      return 0.1 * x;
    } else if (x >= 7 && x < 19) {
      return 0.05 * x + 0.35;
    } else if (x >= 19 && x < 21) {
      return 0.1 * x - 0.6;
    } else if (x >= 21 && x < 25) {
      return 0.25 * x - 3.75;
    } else if (x >= 25 && x <= 28) {
      return 0.5 * x - 10;
    } else {
      return 1;
    }
  }
}
