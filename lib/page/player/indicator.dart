import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

enum IndicatorType { none, brightness, volume, speed }

/// 通用状态指示器
/// 用于显示亮度、音量、播放速度
class StatusIndicator extends StatelessWidget {
  final IndicatorType type;
  final double value;
  final bool isVisible;

  const StatusIndicator({
    super.key,
    required this.type,
    required this.value,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Widget child;

    switch (type) {
      case IndicatorType.none:
        return const SizedBox.shrink();
      case IndicatorType.brightness:
        icon = _getBrightnessIcon(value);
        child = _buildProgressIndicator(value);
        break;
      case IndicatorType.volume:
        icon = _getVolumeIcon(value);
        child = _buildProgressIndicator(value);
        break;
      case IndicatorType.speed:
        icon = Icons.speed;
        child = Text(
          '长按加速中：${value.toStringAsFixed(2)}x',
          style: context.theme.typography.sm,
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.theme.colors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 20), const SizedBox(width: 8), child],
      ),
    );
  }

  Widget _buildProgressIndicator(double value) {
    return SizedBox(
      width: 100,
      child: FDeterminateProgress(
        value: value,
        style: .delta(
          motion: .delta(duration: .zero),
          constraints: BoxConstraints(minHeight: 8, maxHeight: 8),
        ),
      ),
    );
  }

  IconData _getBrightnessIcon(double brightness) {
    if (brightness < 0.3) {
      return Icons.brightness_low;
    } else if (brightness < 0.7) {
      return Icons.brightness_medium;
    } else {
      return Icons.brightness_high;
    }
  }

  IconData _getVolumeIcon(double volume) {
    if (volume == 0) {
      return Icons.volume_off;
    } else if (volume < 0.5) {
      return Icons.volume_down;
    } else {
      return Icons.volume_up;
    }
  }
}
