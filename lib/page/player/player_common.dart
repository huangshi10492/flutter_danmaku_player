import 'dart:async';

import 'package:auto_orientation_v2/auto_orientation_v2.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/page/player/right_drawer/right_drawer.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/file_explorer.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/service/player/player.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

class PlayerSessionController {
  PlayerSessionController(VideoInfo initialVideo)
    : videoInfo = signal(initialVideo) {
    playerService = VideoPlayerService(
      initialVideo,
      () => loadComplete.add(null),
    );
  }

  final Signal<VideoInfo> videoInfo;
  final loadComplete = StreamController<void>.broadcast();
  late final VideoPlayerService playerService;

  Future<bool> saveScreenshot() => playerService.saveScreenshot();

  Future<void> switchVideo(int index) async {
    final current = videoInfo.value;
    if (index < 0 || index >= current.listLength) return;

    VideoInfo? nextVideo;
    if (current.historiesType == .fileStorage) {
      nextVideo = await GetIt.I.get<FileExplorerService>().selectVideo(index);
    } else if (current.historiesType == .streamMediaStorage) {
      final explorer = GetIt.I.get<StreamMediaExplorerService>();
      final historyService = GetIt.I.get<HistoryService>();
      final offlineCacheService = GetIt.I.get<OfflineCacheService>();
      nextVideo = explorer.getVideoInfo(index);
      if (GetIt.I.get<ConfigureService>().offlineCacheFirst.value) {
        nextVideo.cached = offlineCacheService.isCached(nextVideo.uniqueKey);
      }
      final history = explorer.getHistory(explorer.playbackEpisodes[index]);
      if (history != null) await historyService.save(history);
    }

    if (nextVideo == null) return;
    videoInfo.value = nextVideo;
    await playerService.switchVideo(nextVideo);
  }

  Future<void> dispose() async {
    playerService.dispose();
    loadComplete.close();
  }
}

class PlayerPageHost extends StatefulWidget {
  const PlayerPageHost({
    super.key,
    required this.videoInfo,
    required this.builder,
  });

  final VideoInfo videoInfo;
  final Widget Function(BuildContext context, PlayerSessionController session)
  builder;

  @override
  State<PlayerPageHost> createState() => _PlayerPageHostState();
}

class _PlayerPageHostState extends State<PlayerPageHost> {
  late final PlayerSessionController _session = PlayerSessionController(
    widget.videoInfo,
  );

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _session.dispose();
    SystemChrome.setEnabledSystemUIMode(.edgeToEdge);
    AutoOrientation.fullAutoMode();
    if (Utils.isDesktop()) {
      windowManager.setFullScreen(false);
    }
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _session);
}

class PlayerStage extends StatelessWidget {
  const PlayerStage({
    super.key,
    required this.playerService,
    required this.overlayBuilder,
    this.onBack,
    this.notificationBottomInset = 60,
  });

  final VideoPlayerService playerService;
  final WidgetBuilder overlayBuilder;
  final VoidCallback? onBack;
  final double notificationBottomInset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        _buildVideoLayer(),
        _buildDanmakuLayer(),
        SignalBuilder(
          builder: (context) {
            final state = playerService.playerState.value;
            if (state == .error) {
              return _buildError(context, playerService.errorMessage.value);
            }
            if (state == .loading) return _buildLoading(context);
            return Stack(
              fit: .expand,
              children: [
                overlayBuilder(context),
                if (state == .buffering) _buildBufferingIndicator(context),
              ],
            );
          },
        ),
        _buildNotificationOverlay(context),
      ],
    );
  }

  Widget _buildVideoLayer() {
    return SignalBuilder(
      builder: (context) {
        final controller = playerService.controller.value;
        if (controller == null) return const SizedBox.shrink();
        return Center(
          child: Video(
            controller: controller,
            controls: NoVideoControls,
            wakelock: false,
          ),
        );
      },
    );
  }

  Widget _buildDanmakuLayer() {
    return SignalBuilder(
      builder: (context) {
        final opacity =
            playerService.danmakuService.danmakuSettings.value.opacity;
        return Opacity(
          opacity: opacity,
          child: DanmakuScreen(
            createdController: (controller) {
              playerService.danmakuService.controller = controller;
            },
            option: DanmakuOption(),
          ),
        );
      },
    );
  }

  Widget _buildError(BuildContext context, String? message) {
    return _buildStatusLayout(
      context,
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(
            FLucideIcons.circleX,
            color: context.theme.colors.error,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text('视频加载失败', style: context.theme.typography.body.lg),
          const SizedBox(height: 8),
          Padding(
            padding: const .symmetric(horizontal: 48),
            child: Text(
              message ?? '未知错误',
              style: context.theme.typography.body.sm,
              textAlign: .center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return _buildStatusLayout(
      context,
      child: Column(
        mainAxisSize: .min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('正在加载视频...', style: context.theme.typography.body.md),
        ],
      ),
    );
  }

  Widget _buildStatusLayout(BuildContext context, {required Widget child}) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          SafeArea(
            child: Align(
              alignment: .topLeft,
              child: Padding(
                padding: const .all(8),
                child: IconButton(
                  tooltip: '返回',
                  icon: const Icon(FLucideIcons.arrowLeft, size: 28),
                  onPressed: onBack ?? () => Navigator.maybePop(context),
                ),
              ),
            ),
          ),
          Center(child: child),
        ],
      ),
    );
  }

  Widget _buildBufferingIndicator(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: .min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            SignalBuilder(
              builder: (context) => Text(
                Utils.formatDuration(playerService.bufferedPosition.value),
                style: context.theme.typography.body.md,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationOverlay(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final overlayHeight = (screenHeight - notificationBottomInset)
        .clamp(0.0, screenHeight)
        .toDouble();
    return Positioned(
      left: 16,
      bottom: notificationBottomInset,
      child: SizedBox(
        width: 300,
        height: overlayHeight,
        child: FToaster(
          style: .delta(expandBehavior: .always),
          child: Builder(
            builder: (context) {
              GetIt.I.get<GlobalService>().playerNotificationContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

class PlayerSidePanel extends StatelessWidget {
  const PlayerSidePanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height,
      decoration: BoxDecoration(color: context.theme.colors.background),
      child: SafeArea(
        left: false,
        minimum: const .symmetric(horizontal: 8, vertical: 4),
        child: SizedBox(width: 320, child: child),
      ),
    );
  }
}

Future<void> showPlayerRightDrawer({
  required BuildContext context,
  required RightDrawerType drawerType,
  required VideoPlayerService playerService,
  required VideoInfo videoInfo,
  required void Function(int index) onEpisodeSelected,
}) async {
  Future<void> open(RightDrawerType type) async {
    RightDrawerType? nextType;
    await showFSheet(
      context: context,
      side: .rtl,
      draggable: false,
      builder: (sheetContext) {
        return RightDrawerContent(
          drawerType: type,
          playerService: playerService,
          onEpisodeSelected: onEpisodeSelected,
          videoInfo: videoInfo,
          onDrawerChanged: (newType) {
            nextType = newType;
            Navigator.pop(sheetContext);
          },
        );
      },
    );
    if (nextType != null && context.mounted) await open(nextType!);
  }

  await open(drawerType);
}
