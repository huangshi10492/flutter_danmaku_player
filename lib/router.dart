import 'package:auto_orientation/auto_orientation.dart';
import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/page/file_explorer.dart';
import 'package:fldanplay/page/history.dart';
import 'package:fldanplay/page/offline_cache.dart';
import 'package:fldanplay/page/player/player.dart';
import 'package:fldanplay/page/root.dart';
import 'package:fldanplay/page/settings/general_settings.dart';
import 'package:fldanplay/page/settings/danmaku_settings.dart';
import 'package:fldanplay/page/settings/log_page.dart';
import 'package:fldanplay/page/settings/log_view.dart';
import 'package:fldanplay/page/settings/player_settings.dart';
import 'package:fldanplay/page/settings/settings.dart';
import 'package:fldanplay/page/settings/font_manager.dart';
import 'package:fldanplay/page/settings/maintenance_page.dart';
import 'package:fldanplay/page/settings/sync_settings.dart';
import 'package:fldanplay/page/stream_media/detail.dart';
import 'package:fldanplay/page/stream_media/explorer.dart';
import 'package:fldanplay/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

const String rootPath = '/';
const String fileExplorerPath = '/file-explorer';
const String streamMediaExplorerPath = '/stream-media-explorer';
const String streamMediaDetailPath = '/stream-media-detail';
const String historyPath = '/history';
const String offlineCachePath = '/offline-cache';
const String videoPlayerPath = '/video-player';
const String settingsPath = '/settings';

final router = GoRouter(
  initialLocation: rootPath,
  routes: [
    GoRoute(
      path: rootPath,
      pageBuilder: (context, state) => SlideAndExitTransitionPage(
        key: state.pageKey,
        child: const RootPage(),
      ),
    ),
    GoRoute(
      path: settingsPath,
      pageBuilder: (context, state) => SlideAndExitTransitionPage(
        key: state.pageKey,
        child: const SettingsPage(),
      ),
      routes: [
        GoRoute(
          path: 'general',
          pageBuilder: (context, state) => SlideAndExitTransitionPage(
            key: state.pageKey,
            child: const GeneralSettingsPage(),
          ),
        ),
        GoRoute(
          path: 'player',
          pageBuilder: (context, state) => SlideAndExitTransitionPage(
            key: state.pageKey,
            child: const PlayerSettingsPage(),
          ),
          routes: [
            GoRoute(
              path: 'hardware-decoder',
              pageBuilder: (context, state) => SlideAndExitTransitionPage(
                key: state.pageKey,
                child: const HardwareDecoderPage(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'danmaku',
          pageBuilder: (context, state) => SlideAndExitTransitionPage(
            key: state.pageKey,
            child: const DanmakuSettingsPage(),
          ),
        ),
        GoRoute(
          path: 'font',
          pageBuilder: (context, state) => SlideAndExitTransitionPage(
            key: state.pageKey,
            child: const FontManagerPage(),
          ),
        ),
        GoRoute(
          path: 'webdav',
          pageBuilder: (context, state) => SlideAndExitTransitionPage(
            key: state.pageKey,
            child: const SyncSettingsPage(),
          ),
        ),
        GoRoute(
          path: 'log',
          pageBuilder: (context, state) => SlideAndExitTransitionPage(
            key: state.pageKey,
            child: const LogPage(),
          ),
          routes: [
            GoRoute(
              path: 'view',
              pageBuilder: (context, state) => SlideAndExitTransitionPage(
                key: state.pageKey,
                child: LogViewPage(
                  fileName: state.uri.queryParameters['file'] ?? '',
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'maintenance',
          pageBuilder: (context, state) => SlideAndExitTransitionPage(
            key: state.pageKey,
            child: const MaintenancePage(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: fileExplorerPath,
      pageBuilder: (context, state) => SlideAndExitTransitionPage(
        key: state.pageKey,
        child: FileExplorerPage(
          storageKey: state.uri.queryParameters['key'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: streamMediaExplorerPath,
      pageBuilder: (context, state) => SlideAndExitTransitionPage(
        key: state.pageKey,
        child: StreamMediaExplorerPage(
          storageKey: state.uri.queryParameters['key'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: streamMediaDetailPath,
      pageBuilder: (context, state) => SlideAndExitTransitionPage(
        key: state.pageKey,
        child: StreamMediaDetailPage(mediaItem: state.extra as MediaItem),
      ),
    ),
    GoRoute(
      path: historyPath,
      pageBuilder: (context, state) => SlideAndExitTransitionPage(
        key: state.pageKey,
        child: const HistoryPage(),
      ),
    ),
    GoRoute(
      path: offlineCachePath,
      pageBuilder: (context, state) => SlideAndExitTransitionPage(
        key: state.pageKey,
        child: const OfflineCachePage(),
      ),
    ),
    GoRoute(
      path: videoPlayerPath,
      pageBuilder: (context, state) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        AutoOrientation.landscapeAutoMode(forceSensor: true);
        final videoInfo = state.extra as VideoInfo;
        return CustomTransitionPage(
          child: Theme(
            data: zincDark.toApproximateMaterialTheme(),
            child: FTheme(data: zincDark, child: VideoPlayerPage(videoInfo)),
          ),
          transitionsBuilder: (_, animation, _, child) {
            return child;
          },
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      },
    ),
  ],
);

class SlideAndExitTransitionPage extends CustomTransitionPage<void> {
  SlideAndExitTransitionPage({
    required LocalKey super.key,
    required super.child,
  }) : super(
         transitionDuration: const Duration(milliseconds: 400),
         reverseTransitionDuration: const Duration(milliseconds: 400),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final slideFromRight =
               Tween<Offset>(
                 begin: const Offset(1.0, 0.0),
                 end: Offset.zero,
               ).animate(
                 CurvedAnimation(
                   parent: animation,
                   curve: Curves.easeOutCubic,
                   reverseCurve: Curves.easeInCubic,
                 ),
               );
           final slideToLeft =
               Tween<Offset>(
                 begin: Offset.zero,
                 end: const Offset(-0.5, 0.0),
               ).animate(
                 CurvedAnimation(
                   parent: secondaryAnimation,
                   curve: Curves.easeOutCubic,
                   reverseCurve: Curves.easeInCubic,
                 ),
               );
           return SlideTransition(
             position: slideFromRight,
             child: SlideTransition(position: slideToLeft, child: child),
           );
         },
       );
}
