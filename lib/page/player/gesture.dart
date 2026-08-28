import 'package:material_ui/material_ui.dart';

/// 视频播放器手势检测器
/// 处理各种手势操作：单击、双击、长按、滑动等
class VideoPlayerGestureDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final Function(double)? onVerticalDragLeft; // 左侧滑动调整亮度
  final Function(double)? onVerticalDragRight; // 右侧滑动调整音量
  final Function(Duration)? onHorizontalDrag; // 水平滑动调整进度（实时预览）
  final Function(Duration)? onHorizontalDragEnd; // 水平滑动结束（实际跳转）
  final VoidCallback? onPanStart;
  final VoidCallback? onPanEnd;

  const VideoPlayerGestureDetector({
    super.key,
    required this.child,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onVerticalDragLeft,
    this.onVerticalDragRight,
    this.onHorizontalDrag,
    this.onHorizontalDragEnd,
    this.onPanStart,
    this.onPanEnd,
  });

  @override
  State<VideoPlayerGestureDetector> createState() =>
      _VideoPlayerGestureDetectorState();
}

enum _GestureType { none, horizontal, verticalLeft, verticalRight }

class _VideoPlayerGestureDetectorState
    extends State<VideoPlayerGestureDetector> {
  Offset? _dragStartPosition;
  _GestureType _lockedGesture = _GestureType.none;

  // 手势状态缓存
  double _lastDeltaX = 0.0;
  double _lastDeltaY = 0.0;

  // 最小移动距离阈值（像素）
  static const double _minMovementThreshold = 2.0;

  // 手势锁定阈值（像素）
  static const double _gestureLockThreshold = 10.0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) {
        widget.onLongPressStart?.call();
      },
      onLongPressEnd: (details) {
        widget.onLongPressEnd?.call();
      },
      onPanStart: (details) {
        // 防止边缘误触
        if (details.localPosition.dx < 64 ||
            details.localPosition.dx > screenSize.width - 64) {
          return;
        }
        if (details.localPosition.dy < 64 ||
            details.localPosition.dy > screenSize.height - 64) {
          return;
        }
        _dragStartPosition = details.localPosition;
        _lockedGesture = _GestureType.none;
        widget.onPanStart?.call();
      },
      onPanUpdate: (details) {
        if (_dragStartPosition == null) return;

        final deltaX = details.localPosition.dx - _dragStartPosition!.dx;
        final deltaY = details.localPosition.dy - _dragStartPosition!.dy;

        // 手势锁定逻辑优化
        if (_lockedGesture == _GestureType.none) {
          // 只有当移动距离超过锁定阈值时才锁定手势
          if (deltaX.abs() > _gestureLockThreshold ||
              deltaY.abs() > _gestureLockThreshold) {
            if (deltaX.abs() > deltaY.abs()) {
              _lockedGesture = _GestureType.horizontal;
            } else {
              if (_dragStartPosition!.dx < screenSize.width / 2) {
                _lockedGesture = _GestureType.verticalLeft;
              } else {
                _lockedGesture = _GestureType.verticalRight;
              }
            }
          } else {
            // 移动距离不够，不处理
            return;
          }
        }

        // 计算增量变化
        final deltaXChange = (deltaX - _lastDeltaX).abs();
        final deltaYChange = (deltaY - _lastDeltaY).abs();

        // 根据锁定的手势处理事件
        switch (_lockedGesture) {
          case _GestureType.horizontal:
            // 水平滑动：检查最小移动距离阈值
            if (deltaXChange >= _minMovementThreshold) {
              _lastDeltaX = deltaX;
              if (widget.onHorizontalDrag != null) {
                final screenWidth = MediaQuery.of(context).size.width;
                if (screenWidth <= 0) return;
                // 从最左到最右滑动，快进90秒
                final offset = Duration(
                  seconds: (deltaX / screenWidth * 120).round(),
                );
                widget.onHorizontalDrag!(offset);
              }
            }
            break;
          case _GestureType.verticalLeft:
            // 左侧垂直滑动：检查最小移动距离阈值
            if (deltaYChange >= _minMovementThreshold) {
              _lastDeltaY = deltaY;
              if (widget.onVerticalDragLeft != null) {
                final screenHeight = MediaQuery.of(context).size.height;
                if (screenHeight <= 0) return;
                final offsetBrightness = -deltaY / screenHeight;
                widget.onVerticalDragLeft!(offsetBrightness);
              }
            }
            break;
          case _GestureType.verticalRight:
            // 右侧垂直滑动：检查最小移动距离阈值
            if (deltaYChange >= _minMovementThreshold) {
              _lastDeltaY = deltaY;
              if (widget.onVerticalDragRight != null) {
                final screenHeight = MediaQuery.of(context).size.height;
                if (screenHeight <= 0) return;
                final offsetVolume = -deltaY / screenHeight;
                widget.onVerticalDragRight!(offsetVolume);
              }
            }
            break;
          case _GestureType.none:
            // Do nothing
            break;
        }
      },
      onPanEnd: (details) {
        // 如果是水平滑动，触发滑动结束回调（用于实际跳转）
        if (_lockedGesture == _GestureType.horizontal &&
            widget.onHorizontalDragEnd != null) {
          final deltaX = _lastDeltaX;
          final screenWidth = MediaQuery.of(context).size.width;
          if (screenWidth <= 0) return;
          final offset = Duration(
            seconds: (deltaX / screenWidth * 120).round(),
          );
          widget.onHorizontalDragEnd!(offset);
        }

        // 重置状态
        _dragStartPosition = null;
        _lockedGesture = _GestureType.none;
        _lastDeltaX = 0.0;
        _lastDeltaY = 0.0;

        widget.onPanEnd?.call();
      },
      child: widget.child,
    );
  }
}
