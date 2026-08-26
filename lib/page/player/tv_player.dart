import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:dpad/dpad.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/page/player/player_common.dart';
import 'package:fldanplay/page/player/progress_bar.dart';
import 'package:fldanplay/page/player/right_drawer/right_drawer.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/player/player.dart';
import 'package:fldanplay/theme/widget/adaptive_dialog.dart';
import 'package:fldanplay/utils/icon.dart';
import 'package:fldanplay/utils/theme.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';

class TvVideoPlayerPage extends StatelessWidget {
  const TvVideoPlayerPage(this.videoInfo, {super.key});

  final VideoInfo videoInfo;

  @override
  Widget build(BuildContext context) {
    return PlayerPageHost(
      videoInfo: videoInfo,
      builder: (context, session) => _TvPlayerView(session: session),
    );
  }
}

class _TvPlayerView extends StatefulWidget {
  const _TvPlayerView({required this.session});
  final PlayerSessionController session;

  @override
  State<_TvPlayerView> createState() => _TvPlayerViewState();
}

class _TvPlayerViewState extends State<_TvPlayerView> {
  static const _keySet = DpadKeySet();
  final _configureService = GetIt.I.get<ConfigureService>();
  final _globalService = GetIt.I.get<GlobalService>();
  final Signal<bool> _isFullScreen = signal(false);
  Timer? _indicatorTimer;
  Timer? _controlsTimer;
  final Signal<String> _indicatorText = signal('');
  final Signal<IconData> _indicatorIcon = signal(Icons.play_arrow);
  final Signal<bool> _showIndicator = signal(false);
  final Signal<bool> _showControls = signal(true);
  VideoPlayerService get _playerService => widget.session.playerService;
  VideoInfo get _videoInfo => widget.session.videoInfo.value;

  @override
  void initState() {
    super.initState();
    widget.session.loadComplete.stream.listen((_) {
      if (!mounted) return;
      _controlsTimer?.cancel();
      _showControls.value = true;
      _controlsTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) _showControls.value = false;
      });
    });
    effect(() {
      if (_playerService.playerState.value == .completed) {
        _controlsTimer?.cancel();
        _showControls.value = true;
      }
    });
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: PlayerStage(
            playerService: _playerService,
            onBack: _confirmExit,
            notificationBottomInset: 120,
            overlayBuilder: (_) => Stack(
              fit: .expand,
              children: [
                _buildIndicator(),
                _buildTitle(),
                _buildProgress(),
                _buildPersistentProgressBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final direction = _keySet.directionOf(key);
    final recognized = direction != null || _keySet.isSelect(key);
    if (!recognized) return .ignored;
    if (event is! KeyDownEvent) return .handled;
    if (_keySet.isSelect(key)) {
      _playerService.togglePlayPause();
      return .handled;
    }
    switch (direction) {
      case .left:
        _seekRelative(-_configureService.backwardSeconds.value);
      case .right:
        _seekRelative(_configureService.forwardSeconds.value);
      case .up:
        _openControlMenu();
      case .down:
        _showRightDrawer(.moreActions);
      default:
        break;
    }
    return .handled;
  }

  void _seekRelative(int seconds) {
    _playerService.seekRelative(Duration(seconds: seconds));
    final prefix = seconds > 0 ? '+' : '';
    _displayIndicator(
      seconds > 0 ? Icons.fast_forward : Icons.fast_rewind,
      '$prefix$seconds 秒',
    );
  }

  void _displayIndicator(IconData icon, String text) {
    if (!mounted) return;
    _indicatorTimer?.cancel();
    batch(() {
      _indicatorIcon.value = icon;
      _indicatorText.value = text;
      _showIndicator.value = true;
      _showControls.value = true;
    });
    _indicatorTimer = Timer(const Duration(seconds: 1), () {
      batch(() {
        _showIndicator.value = false;
        _showControls.value = false;
      });
    });
  }

  Widget _buildIndicator() {
    return SignalBuilder(
      builder: (context) => Transform.translate(
        offset: const Offset(0, -100),
        child: Center(
          child: AnimatedOpacity(
            opacity: _showIndicator.value ? 0.8 : 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                color: context.theme.colors.background,
                borderRadius: .circular(8),
              ),
              child: Padding(
                padding: .symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    Icon(_indicatorIcon.value, size: 40),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _indicatorText.value,
                        style: context.theme.typography.display.xl,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Positioned(
      left: 40,
      right: 40,
      top: 20,
      child: IgnorePointer(
        child: SignalBuilder(
          builder: (context) {
            final paused = _playerService.playerState.value == .paused;
            return AnimatedOpacity(
              opacity: _showControls.value || paused ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Align(
                alignment: .centerLeft,
                child: Container(
                  padding: const .symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(180),
                    borderRadius: .circular(8),
                  ),
                  child: Text(
                    _playerService.name.value,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: context.theme.typography.body.xl,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Positioned(
      left: 40,
      right: 40,
      bottom: 10,
      child: IgnorePointer(
        child: SignalBuilder(
          builder: (context) {
            final paused = _playerService.playerState.value == .paused;
            return AnimatedOpacity(
              opacity: _showControls.value || paused ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const .fromLTRB(16, 4, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: .circular(8),
                ),
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    VideoProgressBar(
                      progress: _playerService.position.value,
                      total: _playerService.duration,
                      buffered: _playerService.bufferedPosition.value,
                      danmakuTrend: _configureService.showDanmakuTrend.value
                          ? _playerService.danmakuService.danmakuTrend.value
                          : const [],
                      chapters: _configureService.showChapter.value
                          ? _playerService.chapters.value
                          : const {},
                      onSeek: _playerService.seekTo,
                    ),
                    const SizedBox(height: 16),
                    _buildControllerHints(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPersistentProgressBar() {
    return SignalBuilder(
      builder: (context) {
        final paused = _playerService.playerState.value == .paused;
        if (!_configureService.alwaysShowProgressBar.value ||
            _showControls.value ||
            paused) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: ProgressBar(
              progress: _playerService.position.value,
              buffered: _playerService.bufferedPosition.value,
              total: _playerService.duration,
              barHeight: 2,
              thumbRadius: 0,
              timeLabelLocation: .none,
            ),
          ),
        );
      },
    );
  }

  Widget _buildControllerHints() {
    const hints = [
      (FLucideIcons.chevronsLeftRight, '快退/快进'),
      (FLucideIcons.circleDot, '播放/暂停'),
      (FLucideIcons.chevronUp, '功能菜单'),
      (FLucideIcons.chevronDown, '更多设置'),
    ];
    final textStyle = context.theme.typography.body.xs;
    return Wrap(
      alignment: .start,
      spacing: 16,
      children: hints
          .map(
            (hint) => Row(
              mainAxisSize: .min,
              children: [
                Icon(hint.$1, size: 16),
                const SizedBox(width: 4),
                Text(hint.$2, style: textStyle),
              ],
            ),
          )
          .toList(),
    );
  }

  Future<void> _openControlMenu() async {
    final action = await showFSheet<_TvPlayerAction>(
      context: context,
      side: .rtl,
      draggable: false,
      barrierDismissible: true,
      builder: (sheetContext) => _TvControlMenu(
        actionsBuilder: _buildControlActions,
        onSelected: (action) => Navigator.pop(sheetContext, action),
      ),
    );
    if (action != null) action.onSelect.call();
  }

  List<_TvPlayerAction> _buildControlActions() {
    final actions = <_TvPlayerAction>[];
    if (_videoInfo.videoIndex > 0) {
      actions.add(
        _TvPlayerAction(
          icon: Icons.skip_previous,
          title: '上一集',
          onSelect: () => widget.session.switchVideo(_videoInfo.videoIndex - 1),
        ),
      );
    }
    if (_videoInfo.videoIndex < _videoInfo.listLength - 1) {
      actions.add(
        _TvPlayerAction(
          icon: Icons.skip_next,
          title: '下一集',
          onSelect: () => widget.session.switchVideo(_videoInfo.videoIndex + 1),
        ),
      );
    }
    actions.addAll(_buildJumpActions());
    actions.add(
      _TvPlayerAction(
        icon: FLucideIcons.gauge,
        title: '播放速度',
        details: '${_playerService.playbackSpeed.value.toStringAsFixed(2)}X',
        onSelect: () => _showRightDrawer(.speed),
      ),
    );
    if (_videoInfo.canSwitch) {
      actions.add(
        _TvPlayerAction(
          icon: FLucideIcons.listVideo,
          title: '选集',
          onSelect: () => _showRightDrawer(.episode),
        ),
      );
    }
    final danmakuEnabled = _playerService.danmakuService.danmakuEnabled.value;
    actions.add(
      _TvPlayerAction(
        icon: danmakuEnabled ? MyIcon.danmaku : MyIcon.danmakuOff,
        title: danmakuEnabled ? '关闭弹幕' : '开启弹幕',
        onSelect: _toggleDanmaku,
      ),
    );
    actions.add(
      _TvPlayerAction(
        icon: FLucideIcons.camera,
        title: '截图',
        onSelect: _saveScreenshot,
      ),
    );
    if (Utils.isDesktop()) {
      actions.add(
        _TvPlayerAction(
          icon: _isFullScreen.value ? Icons.fullscreen_exit : Icons.fullscreen,
          title: _isFullScreen.value ? '退出全屏' : '全屏',
          onSelect: _toggleFullScreen,
        ),
      );
    }
    return actions;
  }

  List<_TvPlayerAction> _buildJumpActions() {
    final actions = <_TvPlayerAction>[];
    final mode = _configureService.jumpButtonMode.value;
    final chapters = _playerService.chapters.value;
    if (chapters.isNotEmpty && mode != 1) {
      final position = _playerService.position.value.inSeconds;
      MapEntry<int, String>? nextChapter;
      for (final chapter in chapters.entries) {
        if (chapter.key > position) {
          nextChapter = chapter;
          break;
        }
      }
      if (nextChapter != null) {
        final target = nextChapter;
        actions.add(
          _TvPlayerAction(
            icon: FLucideIcons.skipForward,
            title: '跳至下一章节',
            details: target.value,
            onSelect: () =>
                _playerService.seekTo(Duration(seconds: target.key)),
          ),
        );
      }
    }
    if (chapters.isEmpty || mode == 1 || mode == 2) {
      final seconds = _configureService.seekOPSeconds.value;
      actions.add(
        _TvPlayerAction(
          icon: Icons.fast_forward,
          title: '向前跳转',
          details: '$seconds 秒',
          onSelect: () => _seekRelative(seconds),
        ),
      );
    }
    return actions;
  }

  void _toggleDanmaku() {
    final service = _playerService.danmakuService;
    final enabled = !service.danmakuEnabled.value;
    service.danmakuEnabled.value = enabled;
    if (!enabled) service.controller.clear();
    _displayIndicator(
      enabled ? MyIcon.danmaku : MyIcon.danmakuOff,
      enabled ? '弹幕已开启' : '弹幕已关闭',
    );
  }

  Future<void> _saveScreenshot() async {
    final success = await widget.session.saveScreenshot();
    _globalService.showNotification(success ? '截图已保存' : '截图失败');
  }

  void _toggleFullScreen() {
    final value = !_isFullScreen.value;
    windowManager.setFullScreen(value);
    _isFullScreen.value = value;
    _displayIndicator(
      value ? Icons.fullscreen : Icons.fullscreen_exit,
      value ? '已进入全屏' : '已退出全屏',
    );
  }

  void _showRightDrawer(RightDrawerType drawerType) {
    showPlayerRightDrawer(
      context: context,
      drawerType: drawerType,
      playerService: _playerService,
      videoInfo: _videoInfo,
      onEpisodeSelected: widget.session.switchVideo,
    );
  }

  Future<void> _confirmExit() async {
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (dialogContext, style, animation) => AdaptiveDialog(
        style: style,
        animation: animation,
        title: const Text('退出播放'),
        body: const Text('确定退出当前播放吗？'),
        actions: [
          FButton(
            onPress: () => Navigator.pop(dialogContext, true),
            child: const Text('退出'),
          ),
          FButton(
            variant: .outline,
            onPress: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (mounted) context.pop();
  }
}

class _TvControlMenu extends StatelessWidget {
  const _TvControlMenu({
    required this.actionsBuilder,
    required this.onSelected,
  });

  final List<_TvPlayerAction> Function() actionsBuilder;
  final ValueChanged<_TvPlayerAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PlayerSidePanel(
      child: Scaffold(
        body: SignalBuilder(
          builder: (context) {
            final actions = actionsBuilder();
            return SingleChildScrollView(
              child: FItemGroup(
                style: settingsItemGroupStyle,
                children: actions.indexed.map((entry) {
                  final (index, action) = entry;
                  return FItem(
                    autofocus: index == 0,
                    prefix: Icon(action.icon, size: 20),
                    title: Text(action.title),
                    details: action.details == null
                        ? null
                        : Text(action.details!),
                    onPress: () => onSelected(action),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TvPlayerAction {
  const _TvPlayerAction({
    required this.icon,
    required this.title,
    required this.onSelect,
    this.details,
  });

  final IconData icon;
  final String title;
  final String? details;
  final FutureOr<void> Function() onSelect;
}
