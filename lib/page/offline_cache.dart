import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/offline_cache.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/utils/dialog.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

class OfflineCachePage extends StatefulWidget {
  const OfflineCachePage({super.key});

  @override
  State<OfflineCachePage> createState() => _OfflineCachePageState();
}

class _OfflineCachePageState extends State<OfflineCachePage> {
  late final OfflineCacheService _cacheService;
  late final HistoryService _historyService;

  @override
  void initState() {
    super.initState();
    _cacheService = GetIt.I.get<OfflineCacheService>();
    _historyService = GetIt.I.get<HistoryService>();
  }

  void _playCache(OfflineCache cache) {
    try {
      final videoInfo = cache.videoInfo;
      videoInfo.cached = true;
      final location = Uri(path: videoPlayerPath);
      context.push(location.toString(), extra: videoInfo);
    } catch (e) {
      showToast(level: 3, title: '播放失败', description: e.toString());
    }
  }

  void _showDeleteConfirmDialog(OfflineCache cache) {
    showConfirmDialog(
      context,
      title: '删除缓存',
      content: '是否删除"${cache.videoInfo.name}"的离线缓存？',
      onConfirm: () => _deleteCache(cache),
      confirmText: '删除',
      destructive: true,
    );
  }

  Future<void> _deleteCache(OfflineCache cache) async {
    try {
      await _cacheService.cancelDownload(cache.uniqueKey);
      await _cacheService.deleteCache(cache.uniqueKey);
      showToast(title: '缓存已删除');
    } catch (e) {
      showToast(level: 3, title: '删除失败', description: e.toString());
    }
  }

  String _formatWatchHistory(History? history) {
    if (history == null || history.position <= 0) return '未观看';
    final percent = history.duration > 0
        ? ((history.position / history.duration) * 100).round().clamp(0, 100)
        : 0;
    return '${Utils.formatTime(history.position, history.duration)} 已播放 $percent%';
  }

  @override
  Widget build(BuildContext context) {
    final subtitleStyle =
        context.theme.tileStyles.base.contentStyle.subtitleTextStyle.base;
    return Scaffold(
      appBar: SysAppBar(title: '离线缓存'),
      body: ValueListenableBuilder<Box<History>>(
        valueListenable: _historyService.listener,
        builder: (context, _, _) => ValueListenableBuilder<Box<OfflineCache>>(
          valueListenable: _cacheService.listener,
          builder: (BuildContext context, Box<OfflineCache> value, Widget? _) {
            var caches = value.values.toList();
            caches.sort((a, b) => b.cacheTime.compareTo(a.cacheTime));
            if (caches.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      '暂无离线缓存',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '在视频列表中长按视频可以进行离线保存',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              itemCount: caches.length,
              itemBuilder: (context, index) {
                final cache = caches[index];
                final historyText = _formatWatchHistory(
                  _historyService.getHistory(cache.uniqueKey),
                );
                if (cache.status == DownloadStatus.finished) {
                  return FItem(
                    style: .delta(
                      contentStyle: .delta(
                        subtitleTextStyle: .delta([
                          .base(.value(subtitleStyle)),
                        ]),
                      ),
                    ),
                    title: Text(cache.videoInfo.name),
                    onPress: () => _playCache(cache),
                    suffix: FButton.icon(
                      onPress: () => _showDeleteConfirmDialog(cache),
                      variant: .ghost,
                      child: Icon(
                        FLucideIcons.trash,
                        color: context.theme.colors.destructive,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cache.videoInfo.subtitle != null)
                          Text(cache.videoInfo.subtitle!),
                        Text(Utils.formatFileSize(cache.fileSize)),
                        Text(historyText),
                      ],
                    ),
                  );
                }
                return FItem(
                  style: .delta(
                    contentStyle: .delta(
                      subtitleTextStyle: .delta([.base(.value(subtitleStyle))]),
                    ),
                  ),
                  title: Text(cache.videoInfo.name),
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (cache.status == DownloadStatus.failed)
                        FButton.icon(
                          onPress: () =>
                              _cacheService.resumeDownload(cache.uniqueKey),
                          variant: .ghost,
                          child: const Icon(FLucideIcons.rotateCw, size: 20),
                        ),
                      FButton.icon(
                        onPress: () => _showDeleteConfirmDialog(cache),
                        variant: .ghost,
                        child: Icon(
                          FLucideIcons.x,
                          color: context.theme.colors.destructive,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cache.videoInfo.subtitle != null) ...[
                        Text(cache.videoInfo.subtitle!),
                        const SizedBox(height: 4),
                      ],
                      if (cache.status == DownloadStatus.failed)
                        Text(
                          cache.content == cache.videoInfo.videoName
                              ? '未完成下载，请重试'
                              : cache.content,
                        ),
                      if (cache.status == DownloadStatus.downloading)
                        Text(
                          '下载中... ${Utils.formatFileSize(cache.downloadedBytes)} / ${Utils.formatFileSize(cache.totalBytes)}',
                        ),
                      const SizedBox(height: 4),
                      FDeterminateProgress(
                        style: .delta(
                          motion: .delta(duration: .zero),
                          constraints: .tightFor(height: 6),
                        ),
                        value: cache.downloadedBytes / cache.totalBytes,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
