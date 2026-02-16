import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/file_explorer.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/service/webdav_sync.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:fldanplay/widget/video_item.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:signals_flutter/signals_flutter.dart';
import '../model/history.dart';
import '../model/storage.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _historyService = GetIt.I.get<HistoryService>();
  final _storageService = GetIt.I.get<StorageService>();
  final _fileExplorerService = GetIt.I.get<FileExplorerService>();
  final _webDAVSyncService = GetIt.I.get<WebDAVSyncService>();
  final _streamMediaExplorerService = GetIt.I.get<StreamMediaExplorerService>();

  final Map<String, int> _refreshMap = {};

  @override
  void initState() {
    GetIt.I.get<GlobalService>().updateListener = refreshItem;
    super.initState();
  }

  @override
  void dispose() {
    GetIt.I.get<GlobalService>().updateListener = null;
    super.dispose();
  }

  void refreshItem(String uniqueKey) {
    setState(() {
      _refreshMap[uniqueKey] = (_refreshMap[uniqueKey] ?? 0) + 1;
    });
  }

  Future<void> _clearAllHistories() async {
    try {
      await _historyService.clearAllHistories();
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          level: 3,
          title: '清空历史记录失败',
          description: e.toString(),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(History history) {
    showAdaptiveDialog(
      context: context,
      builder: (context) => FDialog(
        direction: Axis.vertical,
        title: const Text('删除历史记录'),
        body: Text('确定要删除 "${_extractFileName(history.url)}" 的观看历史吗？'),
        actions: [
          FButton(
            onPress: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FButton(
            variant: .destructive,
            onPress: () {
              Navigator.pop(context);
              _historyService.delete(history: history);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showClearAllConfirmDialog() {
    showAdaptiveDialog(
      context: context,
      builder: (context) => FDialog(
        direction: Axis.vertical,
        title: const Text('清空所有历史记录'),
        body: const Text('确定要清空所有观看历史吗？此操作不可撤销。'),
        actions: [
          FButton(
            onPress: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FButton(
            variant: .destructive,
            onPress: () {
              Navigator.pop(context);
              _clearAllHistories();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  String _extractFileName(String? url) {
    if (url == null) return '未知文件';
    try {
      final fileName = path.basename(url);
      return fileName;
    } catch (e) {
      return url.split('/').last;
    }
  }

  Future<void> _playVideo(History history) async {
    try {
      final url = history.url;
      if (url == null) {
        showToast(context, level: 3, title: '播放失败', description: '视频URL为空');
        return;
      }
      late VideoInfo videoInfo;
      if (GetIt.I.get<ConfigureService>().offlineCacheFirst.value) {
        final cache = GetIt.I.get<OfflineCacheService>().getCache(
          history.uniqueKey,
        );
        if (cache != null) {
          videoInfo = cache.videoInfo;
          videoInfo.cached = true;
          if (mounted) {
            final location = Uri(path: videoPlayerPath);
            context.push(location.toString(), extra: videoInfo);
          }
          return;
        }
      }
      switch (history.type) {
        case HistoriesType.fileStorage:
          final storageKey = history.storageKey;
          if (storageKey == null) {
            showToast(
              context,
              level: 3,
              title: '播放失败',
              description: '无法从URL中提取媒体库ID',
            );
            return;
          }
          final storage = _storageService.get(storageKey);
          if (storage == null) {
            showToast(
              context,
              level: 3,
              title: '播放失败',
              description: '找不到对应的媒体库',
            );
            return;
          }
          switch (storage.storageType) {
            case StorageType.webdav:
              final provider = WebDAVFileExplorerProvider(storage);
              _fileExplorerService.setProvider(provider, storage);
              break;
            case StorageType.local:
              final provider = LocalFileExplorerProvider(storage.url);
              _fileExplorerService.setProvider(provider, storage);
              break;
            default:
              showToast(
                context,
                level: 3,
                title: '播放失败',
                description: '不支持的媒体库类型',
              );
              return;
          }
          videoInfo = await _fileExplorerService.getVideoInfoFromHistory(
            history,
          );
          break;
        case HistoriesType.streamMediaStorage:
          final storageKey = history.storageKey;
          if (storageKey == null) {
            showToast(
              context,
              level: 3,
              title: '播放失败',
              description: '无法从URL中提取媒体库ID',
            );
            return;
          }
          final storage = _storageService.get(storageKey);
          if (storage == null) {
            showToast(
              context,
              level: 3,
              title: '播放失败',
              description: '找不到对应的媒体库',
            );
            return;
          }
          switch (storage.storageType) {
            case StorageType.jellyfin:
              final provider = JellyfinStreamMediaExplorerProvider(
                storage.url,
                UserInfo(userId: storage.userId!, token: storage.token!),
              );
              _streamMediaExplorerService.setProvider(provider, storage);
              break;
            case StorageType.emby:
              final provider = EmbyStreamMediaExplorerProvider(
                storage.url,
                UserInfo(userId: storage.userId!, token: storage.token!),
              );
              _streamMediaExplorerService.setProvider(provider, storage);
              break;
            default:
              showToast(
                context,
                level: 3,
                title: '播放失败',
                description: '不支持的媒体库类型',
              );
              return;
          }
          videoInfo = _streamMediaExplorerService.getVideoInfoFromHistory(
            history,
          );
          break;
        case HistoriesType.local:
          videoInfo = VideoInfo.fromFile(
            currentVideoPath: url,
            virtualVideoPath: url,
            historiesType: HistoriesType.local,
          );
          break;
        case HistoriesType.network:
          videoInfo = VideoInfo(
            currentVideoPath: url,
            virtualVideoPath: url,
            historiesType: HistoriesType.network,
            videoName: _extractFileName(url).split('.').first,
            name: _extractFileName(url),
          );
          break;
      }
      if (mounted) {
        final location = Uri(path: videoPlayerPath);
        context.push(location.toString(), extra: videoInfo);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, level: 3, title: '播放失败', description: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        title: '观看历史',
        actions: [
          Watch((context) {
            final syncStatus = _webDAVSyncService.syncStatus.value;
            late IconData icon;
            switch (syncStatus) {
              case SyncStatus.idle:
                icon = Icons.cloud_outlined;
                break;
              case SyncStatus.syncing:
                return const FCircularProgress();
              case SyncStatus.success:
                icon = Icons.cloud_done_outlined;
                break;
              case SyncStatus.failed:
                icon = Icons.cloud_off_outlined;
                break;
            }
            return FButton.icon(
              variant: .ghost,
              onPress: _webDAVSyncService.syncHistories,
              child: Icon(icon, size: 24),
            );
          }),
          FButton.icon(
            variant: .ghost,
            onPress: _showClearAllConfirmDialog,
            child: const Icon(Icons.clear_all, size: 24),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _historyService.listener,
        builder: (BuildContext context, Box<History> value, Widget? _) {
          var list = value.values.toList();
          list.sort((a, b) => b.updateTime.compareTo(a.updateTime));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final history = list[index];
              _refreshMap[history.uniqueKey] ??= 0;
              final refreshKey = _refreshMap[history.uniqueKey]!;
              return VideoItem(
                key: ValueKey(history.uniqueKey),
                history: history,
                uniqueKey: history.uniqueKey,
                refreshKey: refreshKey,
                name: history.name,
                onPress: () => _playVideo(history),
                onLongPress: () => _showDeleteConfirmDialog(history),
              );
            },
          );
        },
      ),
    );
  }
}
