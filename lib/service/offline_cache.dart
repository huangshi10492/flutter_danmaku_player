import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fldanplay/model/file_item.dart';
import 'package:fldanplay/model/offline_cache.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/service/file_explorer.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/stream_media_explorer.dart' hide Filter;
import 'package:fldanplay/utils/log.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

class OfflineCacheService {
  late final StorageService storageService;
  late Box<OfflineCache> _cacheBox;
  final lock = Lock();
  final _logger = Logger('OfflineCacheService');
  final Map<String, ({CancelToken cancelToken, void Function() dispose})>
  _downloadTasks = {};
  late String cachePath;
  ValueListenable<Box<OfflineCache>> get listener => _cacheBox.listenable();

  static Future<OfflineCacheService> register(StorageService ss) async {
    final service = OfflineCacheService();
    service.storageService = ss;
    await service.init();
    GetIt.I.registerSingleton<OfflineCacheService>(service);
    return service;
  }

  Future<void> init() async {
    _cacheBox = await Hive.openBox<OfflineCache>('offline_cache');
    cachePath =
        '${(await getApplicationSupportDirectory()).path}/offline_cache';
    final dir = await Directory(cachePath).create(recursive: true);
    for (var cache in _cacheBox.values.toList()) {
      if (cache.status == DownloadStatus.downloading) {
        cache.status = DownloadStatus.failed;
        cache.save();
      }
    }
    final tempFiles = await dir
        .list()
        .where((e) => e.path.endsWith('.temp'))
        .toList();
    for (var file in tempFiles) {
      await file.delete();
    }
    _logger.info('init', '离线缓存服务初始化完成');
  }

  bool isCached(String uniqueKey) {
    final cache = _cacheBox.get(uniqueKey);
    return cache != null && cache.status == DownloadStatus.finished;
  }

  OfflineCache? getCache(String uniqueKey) {
    return _cacheBox.get(uniqueKey);
  }

  Future<void> startDownload(VideoInfo videoInfo) async {
    final uniqueKey = videoInfo.uniqueKey;
    if (_cacheBox.containsKey(uniqueKey)) {
      _logger.info('startDownload', '视频已缓存: $uniqueKey');
      return;
    }
    if (_downloadTasks.containsKey(uniqueKey)) {
      _logger.info('startDownload', '视频正在下载: $uniqueKey');
      return;
    }
    try {
      final cacheTime = DateTime.now().millisecondsSinceEpoch;
      final offlineCache = OfflineCache(
        uniqueKey: uniqueKey,
        videoInfo: videoInfo,
        content: videoInfo.videoName,
        fileSize: 0,
        cacheTime: cacheTime,
      );
      await _cacheBox.put(uniqueKey, offlineCache);
      _executeDownload(uniqueKey);
    } catch (e, t) {
      _logger.error('startDownload', '下载失败: $e', stackTrace: t);
    }
  }

  Future<void> _executeDownload(String uniqueKey) async {
    final cancelToken = CancelToken();
    final offlineCache = _cacheBox.get(uniqueKey)!;
    final videoInfo = offlineCache.videoInfo;
    final storage = storageService.get(videoInfo.storageKey!);
    int lastReportedReceived = offlineCache.downloadedBytes;
    int lastReportedTotal = offlineCache.fileSize;
    Timer? throttleTimer;
    void throttledUpdateProgress(int received, int total) {
      lastReportedReceived = received;
      lastReportedTotal = total;
      if (throttleTimer?.isActive == true) return;
      throttleTimer = Timer(const Duration(milliseconds: 250), () {
        throttleTimer = null;
      });
      offlineCache.updateProgress(lastReportedReceived, lastReportedTotal);
    }

    try {
      bool success = false;
      final localPath = '$cachePath/${videoInfo.uniqueKey}.temp';
      if (videoInfo.historiesType == HistoriesType.streamMediaStorage) {
        final provider = await createStreamMediaExplorerProvider(storage!);
        if (provider == null) {
          throw AppException('不支持的媒体库类型', null);
        }
        _downloadTasks[videoInfo.uniqueKey] = (
          cancelToken: cancelToken,
          dispose: provider.dispose,
        );
        if (!cancelToken.isCancelled) {
          success = await provider.downloadVideo(
            videoInfo.virtualVideoPath,
            localPath,
            onProgress: throttledUpdateProgress,
            cancelToken: cancelToken,
          );
        }
        if (success) {
          await _downloadStreamSubtitles(provider, videoInfo, cancelToken);
        }
      } else if (videoInfo.historiesType == HistoriesType.fileStorage) {
        final storageKey = videoInfo.storageKey!;
        final virtualPath = videoInfo.virtualVideoPath;
        final path = filePathFromVirtualPath(virtualPath, storageKey);
        final provider = createFileExplorerProvider(storage!);
        if (provider == null) {
          throw AppException('不支持的媒体库类型', null);
        }
        try {
          await provider.init();
        } catch (_) {
          provider.dispose();
          rethrow;
        }
        _downloadTasks[videoInfo.uniqueKey] = (
          cancelToken: cancelToken,
          dispose: provider.dispose,
        );
        if (!cancelToken.isCancelled) {
          success = await provider.downloadVideo(
            path,
            localPath,
            onProgress: throttledUpdateProgress,
            cancelToken: cancelToken,
          );
        }
        if (success) {
          await _downloadSubtitles(
            provider,
            storageKey,
            videoInfo,
            cancelToken,
          );
        }
      } else {
        throw AppException('不支持的媒体库类型', null);
      }
      if (!success) {
        offlineCache.content = cancelToken.isCancelled ? '下载已取消' : '下载失败';
        offlineCache.status = .failed;
        await offlineCache.save();
        return;
      }
      final file = File(localPath);
      offlineCache.fileSize = await file.length();
      await file.rename('$cachePath/${videoInfo.uniqueKey}');
      offlineCache.status = .finished;
      offlineCache.updateProgress(lastReportedReceived, lastReportedTotal);
      _logger.info('_executeDownload', '下载完成: ${videoInfo.uniqueKey}');
    } catch (e, t) {
      offlineCache.content = cancelToken.isCancelled
          ? '下载已取消'
          : (e is AppException ? e.message : e.toString());
      offlineCache.status = .failed;
      await offlineCache.save();
      _logger.error('_executeDownload', '下载失败: $e', stackTrace: t);
    } finally {
      throttleTimer?.cancel();
      _downloadTasks[videoInfo.uniqueKey]?.dispose();
      _downloadTasks.remove(videoInfo.uniqueKey);
    }
  }

  Future<void> _downloadSubtitles(
    FileExplorerProvider provider,
    String storageKey,
    VideoInfo videoInfo,
    CancelToken cancelToken,
  ) async {
    List<String> subtitlePaths;
    try {
      subtitlePaths = await _resolveSubtitlePaths(
        provider,
        storageKey,
        videoInfo,
      );
    } catch (e) {
      _logger.warn('_downloadSubtitles', '获取字幕列表失败', error: e);
      return;
    }
    if (subtitlePaths.isEmpty) return;
    final subtitleDir = Directory(
      '$cachePath/subtitles/${videoInfo.uniqueKey}',
    );
    try {
      await subtitleDir.create(recursive: true);
    } catch (e) {
      _logger.warn('_downloadSubtitles', '创建字幕缓存目录失败');
      return;
    }
    for (final subtitlePath in subtitlePaths) {
      if (cancelToken.isCancelled) return;
      final fileName = subtitlePath.split('/').last;
      try {
        await provider.downloadVideo(
          subtitlePath,
          '${subtitleDir.path}/$fileName',
          cancelToken: cancelToken,
        );
        _logger.info('_downloadSubtitles', '字幕下载完成: $subtitlePath');
      } catch (e) {
        _logger.warn('_downloadSubtitles', '$subtitlePath下载失败', error: e);
      }
    }
  }

  Future<List<String>> _resolveSubtitlePaths(
    FileExplorerProvider provider,
    String storageKey,
    VideoInfo videoInfo,
  ) async {
    final cachedPaths = videoInfo.externalSubtitles
        .where((subtitle) => subtitle.path != null)
        .map((subtitle) => subtitle.path!)
        .toList();
    if (cachedPaths.isNotEmpty) return cachedPaths;
    final videoPath = filePathFromVirtualPath(
      videoInfo.virtualVideoPath,
      storageKey,
    );
    final parent = videoPath.contains('/')
        ? videoPath.substring(0, videoPath.lastIndexOf('/'))
        : '';
    final rawList = await provider.listFiles(parent, storageKey, Filter());
    final list = FileItem.resolveSubtitles(rawList);
    for (final file in list) {
      if (file.isVideo && file.path == videoPath) {
        return file.subtitles;
      }
    }
    return const [];
  }

  Future<void> _downloadStreamSubtitles(
    StreamMediaExplorerProvider provider,
    VideoInfo videoInfo,
    CancelToken cancelToken,
  ) async {
    try {
      final playbackInfo = await provider.getPlaybackInfo(
        videoInfo.virtualVideoPath,
      );
      final subtitles = playbackInfo.subtitleStreams
          .where((s) => s.isExternal && s.subtitleUrl != null)
          .toList();
      if (subtitles.isEmpty) return;
      final subtitleDir = Directory(
        '$cachePath/subtitles/${videoInfo.uniqueKey}',
      );
      await subtitleDir.create(recursive: true);
      final usedNames = <String>{};
      for (final subtitle in subtitles) {
        if (cancelToken.isCancelled) return;
        final subtitleUrl = subtitle.subtitleUrl!;
        final ext = _subtitleExtension(subtitleUrl);
        var fileName = subtitle.label.isEmpty
            ? 'subtitle_${subtitle.index}.$ext'
            : '${subtitle.label}.$ext';
        var suffix = subtitle.index;
        while (!usedNames.add(fileName)) {
          fileName = subtitle.label.isEmpty
              ? 'subtitle_${++suffix}.$ext'
              : '${subtitle.label}.${++suffix}.$ext';
        }
        try {
          final downloaded = await provider.downloadSubtitle(
            subtitleUrl,
            '${subtitleDir.path}/$fileName',
            cancelToken: cancelToken,
          );
          if (downloaded) {
            _logger.info('_downloadStreamSubtitles', '字幕下载完成: $fileName');
          }
        } catch (e) {
          _logger.warn(
            '_downloadStreamSubtitles',
            '$subtitleUrl下载失败',
            error: e,
          );
        }
      }
    } catch (e, t) {
      _logger.error(
        '_downloadStreamSubtitles',
        '字幕下载失败',
        error: e,
        stackTrace: t,
      );
      return;
    }
  }

  String _subtitleExtension(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final name = path.substring(path.lastIndexOf('/') + 1);
    final index = name.lastIndexOf('.');
    if (index <= 0 || index == name.length - 1) return 'srt';
    final codec = name.substring(index + 1).toLowerCase();
    return switch (codec) {
      'subrip' || 'srt' || 'mov_text' => 'srt',
      'ass' => 'ass',
      'ssa' => 'ssa',
      'webvtt' || 'vtt' => 'vtt',
      'pgssub' || 'pgs' => 'sup',
      'dvdsub' || 'vobsub' => 'sub',
      _ => 'srt',
    };
  }

  Future<void> resumeDownload(String uniqueKey) async {
    if (!_cacheBox.containsKey(uniqueKey)) {
      throw AppException('缓存记录不存在', null);
    }
    final cache = _cacheBox.get(uniqueKey)!;
    if (cache.status != DownloadStatus.failed) {
      throw AppException('无法恢复非暂停/失败状态的下载', null);
    }
    cache.status = DownloadStatus.downloading;
    cache.content = cache.videoInfo.videoName;
    await cache.save();
    _executeDownload(uniqueKey);
  }

  Future<void> cancelDownload(String uniqueKey) async {
    final task = _downloadTasks[uniqueKey];
    if (task != null) {
      if (!task.cancelToken.isCancelled) task.cancelToken.cancel('用户取消下载');
      task.dispose();
    }
  }

  Future<void> deleteCache(String uniqueKey) async {
    return lock.synchronized(() async {
      final cache = _cacheBox.get(uniqueKey);
      if (cache != null) {
        final file = File('$cachePath/${cache.uniqueKey}');
        if (await file.exists()) {
          await file.delete();
        }
        await _cacheBox.delete(uniqueKey);
        final subtitleDir = Directory('$cachePath/subtitles/$uniqueKey');
        if (await subtitleDir.exists()) {
          await subtitleDir.delete(recursive: true);
        }
        _logger.info('deleteCache', '删除缓存: $uniqueKey');
      }
    });
  }

  void dispose() {
    for (final task in _downloadTasks.values.toList()) {
      if (!task.cancelToken.isCancelled) task.cancelToken.cancel('服务销毁');
      task.dispose();
    }
    _downloadTasks.clear();
  }
}
