import 'dart:async';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:auto_orientation/auto_orientation.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/page/player/right_drawer.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/file_explorer.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/player/player.dart';
import 'package:fldanplay/service/player/ui_state.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/utils/icon.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'gesture.dart';
import 'indicator.dart';

class VideoPlayerPage extends StatefulWidget {
  final VideoInfo videoInfo;

  const VideoPlayerPage(this.videoInfo, {super.key});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final Signal<VideoPlayerService> _playerService = signal(
    VideoPlayerService(widget.videoInfo),
  );
  final PlayerUIState _uiState = PlayerUIState();
  late final DanmakuController _danmakuController;
  final _globalService = GetIt.I.get<GlobalService>();
  final _configureService = GetIt.I.get<ConfigureService>();
  late final Signal<VideoInfo> _videoInfo = signal(widget.videoInfo);

  @override
  void initState() {
    super.initState();
    _uiState.init();
    _initializePlayer();
  }

  /// 初始化播放器
  Future<void> _initializePlayer() async {
    await _playerService.value.initialize();
    // 显示控制栏
    _uiState.showControlsTemporarily();
    effect(() {
      if (_playerService.value.playerState.value == PlayerState.completed) {
        _uiState.updateControlsVisibility(true);
      }
    });
  }

  @override
  void dispose() {
    // 释放UI状态管理器
    _uiState.dispose();
    _playerService.value.dispose();
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    AutoOrientation.fullAutoMode();
    // 释放音量和亮度控制服务
    BrightnessVolumeService.dispose();
    if (Utils.isDesktop()) {
      windowManager.setFullScreen(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (Utils.isDesktop()) {
            _playerService.value.togglePlayPause();
          } else {
            if (_uiState.showControls.value) {
              _uiState.updateControlsVisibility(false);
            } else {
              _uiState.showControlsTemporarily();
            }
          }
        },
        onDoubleTap: () {
          if (Utils.isDesktop()) {
            windowManager.setFullScreen(!_uiState.isFullScreen.value);
            _uiState.isFullScreen.value = !_uiState.isFullScreen.value;
          } else {
            _playerService.value.togglePlayPause();
          }
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (focusNode, KeyEvent event) {
            if (event is KeyDownEvent) {
              // 当空格键被按下时
              if (event.logicalKey == LogicalKeyboardKey.space) {
                _playerService.value.togglePlayPause();
              }
              // 左方向键被按下
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _playerService.value.seekRelative(
                  Duration(seconds: -_configureService.backwardSeconds.value),
                );
              }
              // 上方向键被按下
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                final initialVolume = _uiState.currentVolume.value;
                final newVolume = (initialVolume + 0.05).clamp(0.0, 1.0);
                _uiState.setVolume(newVolume);
                BrightnessVolumeService.setVolume(newVolume);
                _playerService.value.setVolume(newVolume);
              }
              // 下方向键被按下
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                final initialVolume = _uiState.currentVolume.value;
                final newVolume = (initialVolume - 0.05).clamp(0.0, 1.0);
                _uiState.setVolume(newVolume);
                BrightnessVolumeService.setVolume(newVolume);
                _playerService.value.setVolume(newVolume);
              }
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                windowManager.setFullScreen(false);
              }
            } else if (event is KeyRepeatEvent) {
              // 右方向键长按
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _uiState.startLongPress(
                  _configureService.doublePlaySpeed.value *
                      (_configureService.doubleWithNowSpeed.value
                          ? _playerService.value.playbackSpeed.value
                          : 1),
                );
                HapticFeedback.vibrate();
                _playerService.value.doubleSpeed(true);
              }
            } else if (event is KeyUpEvent) {
              // 右方向键抬起
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                if (_uiState.longPress.value) {
                  _uiState.endLongPress();
                  _playerService.value.doubleSpeed(false);
                } else {
                  _playerService.value.seekRelative(
                    Duration(seconds: _configureService.forwardSeconds.value),
                  );
                }
              }
            }
            return KeyEventResult.handled;
          },
          child: Utils.isDesktop()
              ? _buildPlayerWidget()
              : VideoPlayerGestureDetector(
                  onLongPressStart: () {
                    _uiState.startLongPress(
                      _configureService.doublePlaySpeed.value *
                          (_configureService.doubleWithNowSpeed.value
                              ? _playerService.value.playbackSpeed.value
                              : 1),
                    );
                    HapticFeedback.vibrate();
                    _playerService.value.doubleSpeed(true);
                  },
                  onLongPressEnd: () {
                    _uiState.endLongPress();
                    _playerService.value.doubleSpeed(false);
                  },
                  onPanStart: () {
                    _uiState.startGesture(
                      initialPosition: _playerService.value.position.value,
                    );
                  },
                  onPanEnd: _uiState.endGesture,
                  onVerticalDragLeft: _adjustBrightness,
                  onVerticalDragRight: _adjustVolume,
                  onHorizontalDrag: (offset) => _adjustProgress(offset, false),
                  onHorizontalDragEnd: (offset) =>
                      _adjustProgress(offset, true),
                  child: _buildPlayerWidget(),
                ),
        ),
      ),
    );
  }

  Widget _buildPlayerWidget() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildVideoPlayer(),
        _buildDanmakuLayer(),
        _buildNotificationOverlay(),
        Watch((context) {
          final playerState = _playerService.value.playerState.value;
          final errorMessage = _playerService.value.errorMessage.value;
          if (playerState == PlayerState.error) {
            return _buildErrorWidget(errorMessage);
          }
          if (playerState == PlayerState.loading) {
            return _buildLoadingWidget();
          }
          return MouseRegion(
            cursor: (_uiState.showControls.value)
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            onHover: (PointerEvent pointerEvent) {
              if (Utils.isDesktop()) {
                _uiState.showControlsTemporarily();
              }
            },
            child: Stack(
              children: [
                ..._buildAnimatedControls(),
                _buildStatusIndicatorOverlay(),
                _buildProgressIndicatorOverlay(),
                _buildBufferingIndicator(),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildErrorWidget(String? errorMessage) {
    return Scaffold(
      appBar: SysAppBar(title: ''),
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FIcons.circleX, color: context.theme.colors.error, size: 64),
            const SizedBox(height: 16),
            Text('视频加载失败', style: context.theme.typography.lg),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? '未知错误',
              style: context.theme.typography.sm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FButton(
              onPress: () {
                _initializePlayer();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: FButton.icon(
            variant: .ghost,
            onPress: () => context.pop(),
            child: const Icon(FIcons.arrowLeft),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('正在加载视频...', style: context.theme.typography.base),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建带动画的控制栏
  List<Widget> _buildAnimatedControls() {
    return [
      // 顶部控制栏
      Watch((context) {
        final showControls = _uiState.showControls.value;
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          top: showControls ? 0 : -75,
          left: 0,
          right: 0,
          child: _buildTopControls(),
        );
      }),
      // 底部控制栏
      Watch((context) {
        final showControls = _uiState.showControls.value;
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          bottom: showControls ? 0 : -75,
          left: 0,
          right: 0,
          child: _buildBottomControls(),
        );
      }),
    ];
  }

  Widget _buildTopControls() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(FIcons.arrowLeft, size: 24),
                    onPressed: () => context.pop(),
                  ),
                  Watch((context) {
                    final videoName = _playerService.value.name.value;
                    return Expanded(
                      child: Text(
                        videoName,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.typography.base,
                      ),
                    );
                  }),
                ],
              ),
            ),
            SizedBox(width: 16),
            Row(
              children: [
                Watch((context) {
                  return Text(
                    _uiState.currentTime.value,
                    style: context.theme.typography.sm,
                  );
                }),
                const SizedBox(width: 16),
                Watch((context) {
                  final batteryLevel = _uiState.batteryLevel.value;
                  final batteryChange = _uiState.batteryChange.value;
                  return Row(
                    children: [
                      batteryChange
                          ? const Icon(FIcons.batteryCharging, size: 20)
                          : Icon(_getBatteryIcon(batteryLevel), size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '$batteryLevel%',
                        style: context.theme.typography.sm,
                      ),
                    ],
                  );
                }),
                const SizedBox(width: 8),
                // 弹幕开关
                Watch((context) {
                  final enabled =
                      _playerService.value.danmakuService.danmakuEnabled.value;
                  return enabled
                      ? IconButton(
                          onPressed: () {
                            _playerService
                                    .value
                                    .danmakuService
                                    .danmakuEnabled
                                    .value =
                                false;
                            _playerService.value.danmakuService.controller
                                .clear();
                          },
                          icon: Icon(MyIcon.danmaku, size: 24),
                        )
                      : IconButton(
                          onPressed: () {
                            _playerService
                                    .value
                                    .danmakuService
                                    .danmakuEnabled
                                    .value =
                                true;
                          },
                          icon: Icon(MyIcon.danmakuOff, size: 24),
                        );
                }),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 24),
                  onPressed: () =>
                      _showRightDrawer(RightDrawerType.danmakuActions),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 根据电量获取电池图标
  IconData _getBatteryIcon(int level) {
    if (level > 70) {
      return FIcons.batteryFull;
    } else if (level > 40) {
      return FIcons.batteryMedium;
    } else if (level > 10) {
      return FIcons.batteryLow;
    } else {
      return FIcons.batteryWarning;
    }
  }

  Widget _buildBottomControls() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            _buildProgressBar(),
            // 播放控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧按钮组
                Row(
                  children: [
                    // 播放/暂停
                    Watch((context) {
                      final playerState = _playerService.value.playerState
                          .watch(context);
                      return IconButton(
                        icon: Icon(
                          playerState == PlayerState.playing
                              ? Icons.pause
                              : Icons.play_arrow,
                          size: 24,
                        ),
                        onPressed: _playerService.value.togglePlayPause,
                      );
                    }),
                    // 上一个视频
                    Watch((context) {
                      final videoIndex = _videoInfo.value.videoIndex;
                      return videoIndex > 0
                          ? IconButton(
                              icon: const Icon(Icons.skip_previous, size: 24),
                              onPressed: () {
                                _switchVideo(videoIndex - 1);
                              },
                            )
                          : Container();
                    }),
                    // 下一个视频
                    Watch((context) {
                      final listLength = _videoInfo.value.listLength;
                      final videoIndex = _videoInfo.value.videoIndex;
                      return videoIndex < listLength - 1
                          ? IconButton(
                              icon: const Icon(Icons.skip_next, size: 24),
                              onPressed: () {
                                _switchVideo(videoIndex + 1);
                              },
                            )
                          : Container();
                    }),
                  ],
                ),
                // 右侧按钮组
                Row(
                  children: [
                    Watch((context) {
                      final chapters = _playerService.value.chapters.value;
                      return chapters.isEmpty
                          ? TextButton.icon(
                              icon: const Icon(Icons.fast_forward, size: 24),
                              style: TextButton.styleFrom(
                                textStyle: const TextStyle(fontSize: 15),
                              ),
                              label: Text(
                                '快进${_configureService.seekOPSeconds.value}秒',
                              ),
                              onPressed: () {
                                _playerService.value.seekRelative(
                                  Duration(
                                    seconds:
                                        _configureService.seekOPSeconds.value,
                                  ),
                                );
                              },
                            )
                          : _buildChapter(chapters);
                    }),
                    // 速度控制
                    Watch((context) {
                      final speed = _playerService.value.playbackSpeed.value;
                      return TextButton(
                        onPressed: () =>
                            _showRightDrawer(RightDrawerType.speed),
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: Text('${speed.toStringAsFixed(2)}X'),
                      );
                    }),
                    // 选集
                    Watch((context) {
                      final canSwitch = _videoInfo.value.canSwitch;
                      return canSwitch
                          ? IconButton(
                              icon: const Icon(FIcons.listVideo, size: 24),
                              onPressed: () =>
                                  _showRightDrawer(RightDrawerType.episode),
                            )
                          : Container();
                    }),
                    if (Utils.isDesktop())
                      IconButton(
                        icon: Watch((context) {
                          return Icon(
                            _uiState.isFullScreen.value
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                            size: 24,
                          );
                        }),
                        onPressed: () {
                          windowManager.setFullScreen(
                            !_uiState.isFullScreen.value,
                          );
                          _uiState.isFullScreen.value =
                              !_uiState.isFullScreen.value;
                        },
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapter(Map<int, String> chapters) {
    return Watch((context) {
      final position = _playerService.value.position.value;
      String text = "";
      Duration switchSeconds = Duration.zero;
      chapters.forEach((key, value) {
        if (switchSeconds != Duration.zero) return;
        if (key <= position.inSeconds) {
          text = value;
        } else {
          switchSeconds = Duration(seconds: key);
          text += "(${Utils.formatDuration(switchSeconds)})-> $value";
          return;
        }
      });
      return TextButton(
        style: TextButton.styleFrom(textStyle: const TextStyle(fontSize: 15)),
        child: Text(text),
        onPressed: () {
          if (switchSeconds == Duration.zero) return;
          _playerService.value.seekTo(switchSeconds);
        },
      );
    });
  }

  /// 构建视频播放器组件
  Widget _buildVideoPlayer() {
    return Watch((context) {
      final playerState = _playerService.value.playerState.value;
      if (playerState == PlayerState.error ||
          playerState == PlayerState.loading) {
        return Container();
      }
      return Center(
        child: Video(
          controller: _playerService.value.controller,
          controls: NoVideoControls,
        ),
      );
    });
  }

  /// 构建弹幕层
  Widget _buildDanmakuLayer() {
    return Watch((context) {
      final opacity =
          _playerService.value.danmakuService.danmakuSettings.value.opacity;
      return Opacity(
        opacity: opacity,
        child: DanmakuScreen(
          createdController: (controller) {
            _danmakuController = controller;
            _playerService.value.danmakuService.controller = controller;
          },
          option: DanmakuOption(),
        ),
      );
    });
  }

  /// 构建状态指示器覆盖层（音量、亮度、速度）
  Widget _buildStatusIndicatorOverlay() {
    return Watch((context) {
      final activeIndicator = _uiState.activeIndicator.value;
      final indicatorValue = _uiState.indicatorValue.value;
      if (activeIndicator == IndicatorType.none) {
        return const SizedBox.shrink();
      }
      double displayValue;
      switch (activeIndicator) {
        case IndicatorType.none:
          displayValue = 0;
          break;
        case IndicatorType.volume:
          displayValue = _uiState.currentVolume.value;
          break;
        case IndicatorType.brightness:
          displayValue = _uiState.currentBrightness.value;
          break;
        case IndicatorType.speed:
          displayValue = indicatorValue;
          break;
      }
      return Positioned(
        top: 100,
        left: 0,
        right: 0,
        child: Center(
          child: StatusIndicator(
            type: activeIndicator,
            value: displayValue,
            isVisible: true,
          ),
        ),
      );
    });
  }

  /// 构建缓冲指示器
  Widget _buildBufferingIndicator() {
    return Watch((context) {
      final playerState = _playerService.value.playerState.value;
      if (playerState != PlayerState.buffering) {
        return const SizedBox.shrink();
      }
      final bufferedPosition = _playerService.value.bufferedPosition.value;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text(
              Utils.formatDuration(bufferedPosition),
              style: context.theme.typography.base,
            ),
          ],
        ),
      );
    });
  }

  /// 构建通知覆盖层
  Widget _buildNotificationOverlay() {
    return Positioned(
      left: 16,
      bottom: 60,
      child: SizedBox(
        width: 300,
        height: MediaQuery.of(context).size.height - 60,
        child: FToaster(
          style: .delta(expandBehavior: .always),
          child: Builder(
            builder: (context) {
              _globalService.notificationContext = context;
              return Container();
            },
          ),
        ),
      ),
    );
  }

  /// 调整亮度
  void _adjustBrightness(double offset) {
    final initialBrightness = _uiState.initialBrightnessOnPan;
    if (initialBrightness == null) return;
    final newBrightness = (initialBrightness + offset).clamp(0.0, 1.0);
    _uiState.setBrightness(newBrightness);
    BrightnessVolumeService.setBrightness(newBrightness);
  }

  /// 调整音量
  void _adjustVolume(double offset) {
    final initialVolume = _uiState.initialVolumeOnPan;
    if (initialVolume == null) return;
    final newVolume = (initialVolume + offset).clamp(0.0, 1.0);
    _uiState.setVolume(newVolume);
    BrightnessVolumeService.setVolume(newVolume);
    _playerService.value.setVolume(newVolume);
  }

  /// 调整播放进度
  void _adjustProgress(Duration offset, bool end) {
    final initialPosition = _uiState.initialPositionOnPan;
    if (initialPosition == null) return;
    final duration = _playerService.value.duration;
    if (duration.inMilliseconds <= 0) return;
    final newPosition = (initialPosition + offset);
    // 限制在视频时长范围内
    final clampedPosition = newPosition.inMilliseconds.clamp(
      0,
      duration.inMilliseconds,
    );
    final finalPosition = Duration(milliseconds: clampedPosition);
    final newPositionText = Utils.formatDuration(finalPosition);
    final durationText = Utils.formatDuration(duration);
    final seekSeconds = finalPosition.inSeconds - initialPosition.inSeconds;
    final seekSecondsText = '${seekSeconds > 0 ? '+' : ''}$seekSeconds s';
    _uiState.setProgressIndicator(
      '$seekSecondsText|$newPositionText / $durationText',
    );
    if (end) {
      _playerService.value.seekTo(finalPosition);
    }
  }

  /// 构建进度指示器覆盖层
  Widget _buildProgressIndicatorOverlay() {
    return Watch((context) {
      final showProgressIndicator = _uiState.showProgressIndicator.value;
      if (!showProgressIndicator) {
        return const SizedBox.shrink();
      }
      final progressText = _uiState.progressIndicatorText.value;
      final parts = progressText.split('|');
      final seekText = parts[0];
      final timeText = parts.length > 1 ? parts[1] : '';

      return Center(
        child: Container(
          constraints: BoxConstraints(minWidth: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(seekText, style: context.theme.typography.xl),
              if (timeText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(timeText, style: context.theme.typography.base),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildProgressBar() {
    return Watch((context) {
      return ProgressBar(
        progress: _playerService.value.position.value,
        total: _playerService.value.duration,
        buffered: _playerService.value.bufferedPosition.value,
        thumbRadius: 8,
        thumbGlowRadius: 18,
        timeLabelTextStyle: context.theme.typography.sm,
        timeLabelLocation: TimeLabelLocation.sides,
        onSeek: _playerService.value.seekTo,
        onDragStart: (_) => _uiState.updateControlsVisibility(true),
        onDragEnd: () => _uiState.showControlsTemporarily(),
      );
    });
  }

  void _switchVideo(int index) async {
    final streamMediaExplorerService = GetIt.I
        .get<StreamMediaExplorerService>();
    final fileExplorerService = GetIt.I.get<FileExplorerService>();
    late VideoInfo newVideoInfo;
    if (_videoInfo.value.historiesType == HistoriesType.fileStorage) {
      final videoInfo = await fileExplorerService.selectVideo(index);
      if (videoInfo == null) {
        return;
      }
      newVideoInfo = videoInfo;
    }
    if (_videoInfo.value.historiesType == HistoriesType.streamMediaStorage) {
      newVideoInfo = streamMediaExplorerService.getVideoInfo(index);
    }
    final service = _playerService.value;
    _danmakuController.clear();
    _playerService.value = VideoPlayerService(newVideoInfo);
    _videoInfo.value = newVideoInfo;
    service.dispose();
    _playerService.value.danmakuService.controller = _danmakuController;
    _initializePlayer();
  }

  void _showRightDrawer(RightDrawerType drawerType) {
    // 隐藏主控制栏以避免重叠
    _uiState.updateControlsVisibility(false);
    showFSheet(
      context: context,
      side: FLayout.rtl,
      draggable: false,
      builder: (context) {
        return RightDrawerContent(
          drawerType: drawerType,
          playerService: _playerService.value,
          onEpisodeSelected: _switchVideo,
          videoInfo: _videoInfo.value,
          onDrawerChanged: (newType) {
            Navigator.pop(context);
            _showRightDrawer(newType);
          },
        );
      },
    );
  }
}
