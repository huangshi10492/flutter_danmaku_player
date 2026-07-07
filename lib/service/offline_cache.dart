import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fldanplay/model/offline_cache.dart';
import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/service/file_explorer.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
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
  final Map<String, CancelToken> _downloadTokens = {};
  late String _downloadPath;
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
    _downloadPath =
        '${(await getApplicationSupportDirectory()).path}/offline_cache';
    final dir = await Directory(_downloadPath).create(recursive: true);
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
    if (_downloadTokens.containsKey(uniqueKey)) {
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
    _downloadTokens[videoInfo.uniqueKey] = cancelToken;
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
      final localPath = '$_downloadPath/${videoInfo.uniqueKey}.temp';
      if (videoInfo.historiesType == HistoriesType.streamMediaStorage) {
        final provider = await createStreamMediaExplorerProvider(storage!);
        if (provider == null) {
          throw AppException('不支持的媒体库类型', null);
        }
        success = await provider.downloadVideo(
          videoInfo.virtualVideoPath,
          localPath,
          onProgress: throttledUpdateProgress,
          cancelToken: cancelToken,
        );
      } else if (videoInfo.historiesType == HistoriesType.fileStorage) {
        final parts = videoInfo.virtualVideoPath.split('/');
        final path = parts.sublist(1, parts.length);
        FileExplorerProvider provider;
        switch (storage!.storageType) {
          case StorageType.webdav:
            provider = WebDAVFileExplorerProvider(storage);
            break;
          case StorageType.local:
            provider = LocalFileExplorerProvider(storage.url);
            break;
          default:
            throw AppException('不支持的媒体库类型', null);
        }
        success = await provider.downloadVideo(
          '/${path.join('/')}',
          localPath,
          onProgress: throttledUpdateProgress,
          cancelToken: cancelToken,
        );
      } else {
        throw AppException('不支持的媒体库类型', null);
      }
      if (!success) return;
      final file = File(localPath);
      offlineCache.fileSize = await file.length();
      await file.rename('$_downloadPath/${videoInfo.uniqueKey}');
      offlineCache.status = DownloadStatus.finished;
      offlineCache.updateProgress(lastReportedReceived, lastReportedTotal);
      _logger.info('_executeDownload', '下载完成: ${videoInfo.uniqueKey}');
    } catch (e, t) {
      offlineCache.status = DownloadStatus.failed;
      offlineCache.save();
      _logger.error('_executeDownload', '下载失败: $e', stackTrace: t);
    } finally {
      throttleTimer?.cancel();
      _downloadTokens.remove(videoInfo.uniqueKey);
    }
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
    cache.save();
    _executeDownload(uniqueKey);
  }

  Future<void> cancelDownload(String uniqueKey) async {
    final cancelToken = _downloadTokens[uniqueKey];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('用户取消下载');
    }
  }

  Future<void> deleteCache(String uniqueKey) async {
    return lock.synchronized(() async {
      final cache = _cacheBox.get(uniqueKey);
      if (cache != null) {
        final file = File('$_downloadPath/${cache.uniqueKey}');
        if (await file.exists()) {
          await file.delete();
        }
        await _cacheBox.delete(uniqueKey);
        _logger.info('deleteCache', '删除缓存: $uniqueKey');
      }
    });
  }

  void dispose() {
    _downloadTokens.clear();
  }
}
