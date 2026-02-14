import 'package:fldanplay/model/offline_cache.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    _cacheService = GetIt.I.get<OfflineCacheService>();
  }

  void _playCache(OfflineCache cache) {
    try {
      final videoInfo = cache.videoInfo;
      videoInfo.cached = true;
      final location = Uri(path: videoPlayerPath);
      context.push(location.toString(), extra: videoInfo);
    } catch (e) {
      showToast(context, level: 3, title: '播放失败', description: e.toString());
    }
  }

  void _showDeleteConfirmDialog(OfflineCache cache) {
    showAdaptiveDialog(
      context: context,
      builder: (context) => FDialog(
        direction: Axis.vertical,
        title: const Text('删除缓存'),
        body: Text('确定要删除 "${cache.videoInfo.name}" 的离线缓存吗？'),
        actions: [
          FButton(
            onPress: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FButton(
            variant: .destructive,
            onPress: () {
              Navigator.pop(context);
              _deleteCache(cache);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCache(OfflineCache cache) async {
    try {
      await _cacheService.cancelDownload(cache.uniqueKey);
      await _cacheService.deleteCache(cache.uniqueKey);
      if (mounted) showToast(context, title: '缓存已删除');
    } catch (e) {
      if (mounted) {
        showToast(context, level: 3, title: '删除失败', description: e.toString());
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(title: '离线缓存'),
      body: ValueListenableBuilder(
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
              if (cache.status == DownloadStatus.finished) {
                return FItem(
                  title: Text(
                    cache.videoInfo.name,
                    style: context.theme.typography.base,
                  ),
                  onPress: () => _playCache(cache),
                  suffix: FButton.icon(
                    onPress: () => _showDeleteConfirmDialog(cache),
                    variant: .ghost,
                    child: const Icon(FIcons.trash, color: Colors.red),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cache.videoInfo.subtitle != null)
                        Text(cache.videoInfo.subtitle!),
                      Text('缓存大小: ${_formatFileSize(cache.fileSize)}'),
                      Text(Utils.formatDateTime(cache.cacheTime)),
                    ],
                  ),
                );
              }
              return FItem(
                title: Text(
                  cache.videoInfo.name,
                  style: context.theme.typography.base,
                ),
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cache.status == DownloadStatus.failed)
                      FButton.icon(
                        onPress: () =>
                            _cacheService.resumeDownload(cache.uniqueKey),
                        variant: .ghost,
                        child: const Icon(FIcons.rotateCw, size: 20),
                      ),
                    FButton.icon(
                      onPress: () => _showDeleteConfirmDialog(cache),
                      variant: .ghost,
                      child: const Icon(FIcons.x, color: Colors.red),
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
                      Text('未完成下载，请重试'),
                    if (cache.status == DownloadStatus.downloading)
                      Text(
                        '下载中... ${_formatFileSize(cache.downloadedBytes)} / ${_formatFileSize(cache.totalBytes)}',
                      ),
                    const SizedBox(height: 4),
                    cache.downloadedBytes == 0
                        ? FProgress(
                            style: .delta(constraints: .tightFor(height: 6)),
                          )
                        : FDeterminateProgress(
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
    );
  }
}
