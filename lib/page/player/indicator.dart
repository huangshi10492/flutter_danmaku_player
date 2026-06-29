import 'package:fldanplay/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

enum IndicatorType {
  none,
  brightness(delay: true, showProgress: true),
  volume(delay: true, showProgress: true),
  speed,
  progress;

  final bool delay;
  final bool showProgress;

  const IndicatorType({this.delay = false, this.showProgress = false});
}

class Indicator extends StatelessWidget {
  final IndicatorType type;
  final double value;

  const Indicator({super.key, required this.type, required this.value});

  String get label {
    switch (type) {
      case .brightness:
      case .volume:
        return '${(value * 100).round()}%';
      case .speed:
        return '${value.toStringAsFixed(2)}x';
      case .progress:
      case .none:
        return '';
    }
  }

  IconData get icon {
    switch (type) {
      case .brightness:
        if (value < 0.3) {
          return Icons.brightness_low;
        } else if (value < 0.7) {
          return Icons.brightness_medium;
        } else {
          return Icons.brightness_high;
        }
      case .volume:
        if (value == 0) {
          return Icons.volume_off;
        } else if (value < 0.5) {
          return Icons.volume_down;
        } else {
          return Icons.volume_up;
        }
      case .speed:
        return Icons.speed;
      case .none:
      case .progress:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _IndicatorBackground(
      Row(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: 30),
          SizedBox(width: 8),
          Padding(
            padding: .only(bottom: type.showProgress ? 6 : 0),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Text(label, style: context.theme.typography.body.sm),
                if (type.showProgress) ...[
                  SizedBox(height: 4),
                  SizedBox(
                    width: 100,
                    child: FDeterminateProgress(
                      value: value,
                      style: .delta(motion: .delta(duration: .zero)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressIndicator extends StatelessWidget {
  final Duration seek;
  final Duration end;
  final int offset;

  const ProgressIndicator({
    super.key,
    required this.seek,
    required this.end,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    final seekText = Utils.formatDuration(seek);
    final endText = Utils.formatDuration(end);
    final offsetText = '${offset > 0 ? '+' : ''}${offset}s';
    final t = context.theme.typography.body;
    return _IndicatorBackground(
      Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Row(
            mainAxisSize: .min,
            crossAxisAlignment: .end,
            children: [
              Icon(
                offset < 0 ? Icons.fast_rewind : Icons.fast_forward,
                size: 40,
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: .start,
                children: [
                  Text(offsetText, style: t.md.copyWith(height: 1.4)),
                  Text('$seekText / $endText', style: t.xs),
                ],
              ),
            ],
          ),
          SizedBox(height: 6),
          SizedBox(
            width: 220,
            child: FDeterminateProgress(
              value: seek.inSeconds / end.inSeconds,
              style: .delta(motion: .delta(duration: .zero)),
            ),
          ),
          SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _IndicatorBackground extends StatelessWidget {
  final Widget child;
  const _IndicatorBackground(this.child);
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Opacity(
          opacity: 0.8,
          child: Container(
            decoration: BoxDecoration(
              color: context.theme.colors.background,
              borderRadius: .circular(12),
            ),
            child: Padding(
              padding: .symmetric(horizontal: 12, vertical: 6),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
