import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:auto_orientation_v2/auto_orientation_v2.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/page/player/right_drawer/right_drawer.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/file_explorer.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/service/player/player.dart';
import 'package:fldanplay/service/player/ui_state.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/utils/icon.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:flutter/material.dart' hide ProgressIndicator;
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'gesture.dart';
import 'indicator.dart';
import 'progress_bar.dart';

class VideoPlayerPage extends StatefulWidget {
  final VideoInfo videoInfo;

  const VideoPlayerPage(this.videoInfo, {super.key});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final _playerService = VideoPlayerService(
    widget.videoInfo,
    () => _uiState.showControlsTemporarily(),
  );
  final PlayerUIState _uiState = PlayerUIState();
  final _globalService = GetIt.I.get<GlobalService>();
  final _configureService = GetIt.I.get<ConfigureService>();
  late final Signal<VideoInfo> _videoInfo = signal(widget.videoInfo);

  @override
  void initState() {
    super.initState();
    _uiState.init();
    effect(() {
      if (_playerService.playerState.value == .completed) {
        _uiState.updateControlsVisibility(true);
      }
    });
  }

  @override
  void dispose() {
    // 释放UI状态管理器
    _uiState.dispose();
    _playerService.dispose();
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    AutoOrientation.fullAutoMode();
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
            _playerService.togglePlayPause();
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
            if (_uiState.lockPanel.value) return;
            _playerService.togglePlayPause();
          }
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (focusNode, KeyEvent event) {
            if (event is KeyDownEvent) {
              // 当空格键被按下时
              if (event.logicalKey == LogicalKeyboardKey.space) {
                _playerService.togglePlayPause();
              }
              // 左方向键被按下
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _playerService.seekRelative(
                  Duration(seconds: -_configureService.backwardSeconds.value),
                );
              }
              // 上方向键被按下
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                final initialVolume =
                    _uiState.brightnessVolumeService.currentVolume;
                final newVolume = (initialVolume + 0.05).clamp(0.0, 1.0);
                _uiState.setVolume(newVolume);
                _uiState.brightnessVolumeService.setVolume(newVolume);
                _playerService.setVolume(newVolume);
              }
              // 下方向键被按下
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                final initialVolume =
                    _uiState.brightnessVolumeService.currentVolume;
                final newVolume = (initialVolume - 0.05).clamp(0.0, 1.0);
                _uiState.setVolume(newVolume);
                _uiState.brightnessVolumeService.setVolume(newVolume);
                _playerService.setVolume(newVolume);
              }
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                windowManager.setFullScreen(false);
                _uiState.isFullScreen.value = false;
              }
            } else if (event is KeyRepeatEvent) {
              // 右方向键长按
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _uiState.startLongPress(
                  _configureService.doublePlaySpeed.value *
                      (_configureService.doubleWithNowSpeed.value
                          ? _playerService.playbackSpeed.value
                          : 1),
                );
                HapticFeedback.vibrate();
                _playerService.doubleSpeed(true);
              }
            } else if (event is KeyUpEvent) {
              // 右方向键抬起
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                if (_uiState.longPress.value) {
                  _uiState.endLongPress();
                  _playerService.doubleSpeed(false);
                } else {
                  _playerService.seekRelative(
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
                    if (_uiState.lockPanel.value) return;
                    _uiState.startLongPress(
                      _configureService.doublePlaySpeed.value *
                          (_configureService.doubleWithNowSpeed.value
                              ? _playerService.playbackSpeed.value
                              : 1),
                    );
                    HapticFeedback.vibrate();
                    _playerService.doubleSpeed(true);
                  },
                  onLongPressEnd: () {
                    if (_uiState.lockPanel.value) return;
                    _uiState.endLongPress();
                    _playerService.doubleSpeed(false);
                  },
                  onPanStart: () {
                    if (_uiState.lockPanel.value) return;
                    _uiState.startGesture(_playerService.position.value);
                  },
                  onPanEnd: () {
                    if (_uiState.lockPanel.value) return;
                    _uiState.endGesture();
                  },
                  onVerticalDragLeft: (offset) {
                    if (_uiState.lockPanel.value) return;
                    _adjustBrightness(offset);
                  },
                  onVerticalDragRight: (offset) {
                    if (_uiState.lockPanel.value) return;
                    _adjustVolume(offset);
                  },
                  onHorizontalDrag: (offset) {
                    if (_uiState.lockPanel.value) return;
                    _adjustProgress(offset, false);
                    _uiState.inndicatorType.value = .progress;
                  },
                  onHorizontalDragEnd: (offset) {
                    if (_uiState.lockPanel.value) return;
                    _uiState.inndicatorType.value = .none;
                    _adjustProgress(offset, true);
                  },
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
        SignalBuilder(
          builder: (context) {
            final playerState = _playerService.playerState.value;
            final errorMessage = _playerService.errorMessage.value;
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
                  SignalBuilder(
                    builder: (context) {
                      if (!_configureService.alwaysShowProgressBar.value ||
                          _uiState.showControls.value) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: ProgressBar(
                          progress: _playerService.position.value,
                          buffered: _playerService.bufferedPosition.value,
                          total: _playerService.duration,
                          barHeight: 2,
                          thumbRadius: 0,
                          timeLabelLocation: .none,
                        ),
                      );
                    },
                  ),
                  SignalBuilder(
                    builder: (context) => _buildAnimatedControls(
                      _uiState.showControls.value,
                      _uiState.lockPanel.value,
                    ),
                  ),
                  _buildIndicatorOverlay(),
                  _buildBufferingIndicator(),
                ],
              ),
            );
          },
        ),
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
            Icon(
              FLucideIcons.circleX,
              color: context.theme.colors.error,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text('视频加载失败', style: context.theme.typography.body.lg),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? '未知错误',
              style: context.theme.typography.body.sm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Scaffold(
      appBar: SysAppBar(title: ''),
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在加载视频...', style: context.theme.typography.body.md),
          ],
        ),
      ),
    );
  }

  /// 构建带动画的控制栏
  Widget _buildAnimatedControls(bool show, bool lock) {
    return Stack(
      children: [
        if (!lock) ...[
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: show ? 0 : -150,
            left: 0,
            right: 0,
            child: _buildTopControls(),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: show ? 0 : -150,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Visibility(visible: show, child: _buildRightSide(lock)),
        ),
      ],
    );
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
                    icon: const Icon(FLucideIcons.arrowLeft, size: 24),
                    onPressed: () => context.pop(),
                  ),
                  SignalBuilder(
                    builder: (context) {
                      final videoName = _playerService.name.value;
                      return Expanded(
                        child: Text(
                          videoName,
                          overflow: TextOverflow.ellipsis,
                          style: context.theme.typography.body.md,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            Row(
              children: [
                SignalBuilder(
                  builder: (context) {
                    return Text(
                      _uiState.currentTime.value,
                      style: context.theme.typography.body.sm,
                    );
                  },
                ),
                const SizedBox(width: 16),
                SignalBuilder(
                  builder: (context) {
                    final batteryLevel = _uiState.batteryLevel.value;
                    final batteryChange = _uiState.batteryChange.value;
                    return Row(
                      children: [
                        batteryChange
                            ? const Icon(FLucideIcons.batteryCharging, size: 20)
                            : Icon(_getBatteryIcon(batteryLevel), size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '$batteryLevel%',
                          style: context.theme.typography.body.sm,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
                // 弹幕开关
                SignalBuilder(
                  builder: (context) {
                    final enabled =
                        _playerService.danmakuService.danmakuEnabled.value;
                    return enabled
                        ? IconButton(
                            onPressed: () {
                              _playerService
                                      .danmakuService
                                      .danmakuEnabled
                                      .value =
                                  false;
                              _playerService.danmakuService.controller.clear();
                            },
                            icon: Icon(MyIcon.danmaku, size: 24),
                          )
                        : IconButton(
                            onPressed: () {
                              _playerService
                                      .danmakuService
                                      .danmakuEnabled
                                      .value =
                                  true;
                            },
                            icon: Icon(MyIcon.danmakuOff, size: 24),
                          );
                  },
                ),
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
      return FLucideIcons.batteryFull;
    } else if (level > 40) {
      return FLucideIcons.batteryMedium;
    } else if (level > 10) {
      return FLucideIcons.batteryLow;
    } else {
      return FLucideIcons.batteryWarning;
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
                    SignalBuilder(
                      builder: (context) {
                        final playerState = _playerService.playerState.value;
                        return IconButton(
                          icon: Icon(
                            playerState == PlayerState.playing
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 24,
                          ),
                          onPressed: _playerService.togglePlayPause,
                        );
                      },
                    ),
                    // 上一个视频
                    SignalBuilder(
                      builder: (context) {
                        final videoIndex = _videoInfo.value.videoIndex;
                        return videoIndex > 0
                            ? IconButton(
                                icon: const Icon(Icons.skip_previous, size: 24),
                                onPressed: () {
                                  _switchVideo(videoIndex - 1);
                                },
                              )
                            : Container();
                      },
                    ),
                    // 下一个视频
                    SignalBuilder(
                      builder: (context) {
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
                      },
                    ),
                  ],
                ),
                // 右侧按钮组
                Row(
                  children: [
                    _buildJumpButton(_playerService.chapters.value),
                    // 速度控制
                    SignalBuilder(
                      builder: (context) {
                        final speed = _playerService.playbackSpeed.value;
                        return TextButton(
                          onPressed: () =>
                              _showRightDrawer(RightDrawerType.speed),
                          child: Text('${speed.toStringAsFixed(2)}X'),
                        );
                      },
                    ),
                    // 选集
                    SignalBuilder(
                      builder: (context) {
                        final canSwitch = _videoInfo.value.canSwitch;
                        return canSwitch
                            ? IconButton(
                                icon: const Icon(
                                  FLucideIcons.listVideo,
                                  size: 24,
                                ),
                                onPressed: () =>
                                    _showRightDrawer(RightDrawerType.episode),
                              )
                            : Container();
                      },
                    ),
                    if (Utils.isDesktop())
                      IconButton(
                        icon: SignalBuilder(
                          builder: (context) {
                            return Icon(
                              _uiState.isFullScreen.value
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              size: 24,
                            );
                          },
                        ),
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

  Widget _buildRightSide(bool lock) {
    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          if (!lock)
            SignalBuilder(
              builder: (context) {
                return FButton.icon(
                  style: .delta(
                    decoration: .delta([
                      .base(.boxDelta(color: Colors.black26)),
                    ]),
                  ),
                  variant: .ghost,
                  size: .lg,
                  onPress: _saveScreenshot,
                  child: _uiState.saveScreenshoting.value
                      ? const FCircularProgress()
                      : const Icon(FLucideIcons.camera),
                );
              },
            ),
          if (!Utils.isDesktop())
            FButton.icon(
              style: .delta(
                decoration: .delta([.base(.boxDelta(color: Colors.black26))]),
              ),
              variant: .ghost,
              size: .lg,
              child: Icon(lock ? FLucideIcons.lockOpen : FLucideIcons.lock),
              onPress: () {
                _uiState.lockPanel.value = !_uiState.lockPanel.value;
                _uiState.showControlsTemporarily();
              },
            ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildJumpButton(Map<int, String> chapters) {
    final nextChapterMode = _configureService.jumpButtonMode.value;
    final secondButton = TextButton(
      onPressed: () => _playerService.seekRelative(
        Duration(seconds: _configureService.seekOPSeconds.value),
      ),
      child: Row(
        children: [
          const Icon(Icons.fast_forward, size: 24),
          const SizedBox(width: 4),
          Text('${_configureService.seekOPSeconds.value}s'),
        ],
      ),
    );
    if (chapters.isEmpty || nextChapterMode == 1) {
      return secondButton;
    }
    final nextChapterButton = SignalBuilder(
      builder: (context) {
        final position = _playerService.position.value;
        String text = "";
        Duration? nextChapter;
        for (var chapter in chapters.entries) {
          if (chapter.key <= position.inSeconds) {
            text = chapter.value;
          } else {
            text += " -> ${chapter.value}";
            nextChapter = Duration(seconds: chapter.key);
            break;
          }
        }
        return TextButton(
          child: Text(text),
          onPressed: () {
            if (nextChapter == null) return;
            _playerService.seekTo(nextChapter);
          },
        );
      },
    );
    if (nextChapterMode == 2) {
      return Row(children: [nextChapterButton, secondButton]);
    }
    return nextChapterButton;
  }

  Future<void> _saveScreenshot() async {
    if (_uiState.saveScreenshoting.value) return;
    _uiState.saveScreenshoting.value = true;
    final success = await _playerService.saveScreenshot();
    if (success) {
      _globalService.showNotification('截图已保存');
    } else {
      _globalService.showNotification('截图失败');
    }
    _uiState.saveScreenshoting.value = false;
  }

  /// 构建视频播放器组件
  Widget _buildVideoPlayer() {
    return SignalBuilder(
      builder: (context) {
        if (_playerService.controller.value == null) {
          return Container();
        }
        return Center(
          child: Video(
            controller: _playerService.controller.value!,
            controls: NoVideoControls,
          ),
        );
      },
    );
  }

  /// 构建弹幕层
  Widget _buildDanmakuLayer() {
    return SignalBuilder(
      builder: (context) {
        final opacity =
            _playerService.danmakuService.danmakuSettings.value.opacity;
        return Opacity(
          opacity: opacity,
          child: DanmakuScreen(
            createdController: (controller) {
              _playerService.danmakuService.controller = controller;
            },
            option: DanmakuOption(),
          ),
        );
      },
    );
  }

  Widget _buildIndicatorOverlay() {
    return SignalBuilder(
      builder: (context) {
        final type = _uiState.inndicatorType.value;
        if (type == IndicatorType.none) {
          return const SizedBox.shrink();
        }
        return type == .progress
            ? SignalBuilder(
                builder: (context) {
                  return ProgressIndicator(
                    seek: _uiState.seekPosition.value,
                    end: _playerService.duration,
                    offset: _uiState.seekOffset.value,
                  );
                },
              )
            : SignalBuilder(
                builder: (context) {
                  return Indicator(
                    type: type,
                    value: _uiState.indicatorValue.value,
                  );
                },
              );
      },
    );
  }

  /// 构建缓冲指示器
  Widget _buildBufferingIndicator() {
    return SignalBuilder(
      builder: (context) {
        final playerState = _playerService.playerState.value;
        if (playerState != PlayerState.buffering) {
          return const SizedBox.shrink();
        }
        final bufferedPosition = _playerService.bufferedPosition.value;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text(
                Utils.formatDuration(bufferedPosition),
                style: context.theme.typography.body.md,
              ),
            ],
          ),
        );
      },
    );
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
              _globalService.playerNotificationContext = context;
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
    final newBrightness = (initialBrightness + offset).clamp(0.0, 1.0);
    _uiState.setBrightness(newBrightness);
  }

  /// 调整音量
  void _adjustVolume(double offset) {
    final initialVolume = _uiState.initialVolumeOnPan;
    final newVolume = (initialVolume + offset).clamp(0.0, 1.0);
    _uiState.setVolume(newVolume);
    _playerService.setVolume(newVolume);
  }

  /// 调整播放进度
  void _adjustProgress(Duration offset, bool end) {
    final initialPosition = _uiState.initialPositionOnPan;
    final duration = _playerService.duration;
    if (duration.inMilliseconds <= 0) return;
    final newPosition = (initialPosition + offset);
    final clampedPosition = newPosition.inMilliseconds.clamp(
      0,
      duration.inMilliseconds,
    );
    final finalPosition = Duration(milliseconds: clampedPosition);
    batch(() {
      _uiState.seekPosition.value = finalPosition;
      _uiState.seekOffset.value =
          finalPosition.inSeconds - initialPosition.inSeconds;
    });
    if (end) _playerService.seekTo(finalPosition);
  }

  Widget _buildProgressBar() {
    return SignalBuilder(
      builder: (context) {
        return VideoProgressBar(
          progress: _playerService.position.value,
          total: _playerService.duration,
          buffered: _playerService.bufferedPosition.value,
          danmakuTrend: _configureService.showDanmakuTrend.value
              ? _playerService.danmakuService.danmakuTrend.value
              : [],
          chapters: _configureService.showChapter.value
              ? _playerService.chapters.value
              : {},
          onSeek: _playerService.seekTo,
          onDragStart: (_) => _uiState.updateControlsVisibility(true),
          onDragEnd: () => _uiState.showControlsTemporarily(),
        );
      },
    );
  }

  void _switchVideo(int index) async {
    final streamMediaExplorerService = GetIt.I
        .get<StreamMediaExplorerService>();
    final fileExplorerService = GetIt.I.get<FileExplorerService>();
    final historyService = GetIt.I.get<HistoryService>();
    final offlineCacheService = GetIt.I.get<OfflineCacheService>();
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
      if (GetIt.I.get<ConfigureService>().offlineCacheFirst.value) {
        newVideoInfo.cached = offlineCacheService.isCached(
          newVideoInfo.uniqueKey,
        );
      }
      final history = streamMediaExplorerService.getHistory(
        streamMediaExplorerService.episodeList[index],
      );
      if (history != null) await historyService.save(history);
    }
    _videoInfo.value = newVideoInfo;
    _playerService.switchVideo(newVideoInfo);
    _uiState.updateControlsVisibility(true);
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
          playerService: _playerService,
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
