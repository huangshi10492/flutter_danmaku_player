import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fldanplay/model/file_item.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/utils/android_saf.dart';
import 'package:fldanplay/utils/crypto_utils.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:string_util_xx/StringUtilxx.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

abstract class FileExplorerProvider {
  Future<void> init();
  String getVideoUrl(String path);
  Future<List<FileItem>> listFiles(String path, String rootPath, Filter filter);
  Map<String, String> get headers;
  Future<bool> downloadVideo(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });
  void dispose();
}

class Filter {
  String searchTerm = '';
  // 0: 全部，1: 文件夹，2: 视频
  int displayMode = 0;
  // true: 升序，false: 降序
  bool sortOrder = true;
  Filter();

  bool isFiltered() {
    return searchTerm.isNotEmpty || sortOrder != true;
  }
}

class FileExplorerService {
  final Signal<FileExplorerProvider?> provider = signal(null);
  final path = signal('/');
  final listLength = signal(0);
  Storage? _storage;
  final _logger = Logger('FileExplorerService');
  final Signal<Filter> filter = signal(Filter());
  final AsyncSignal<List<FileItem>> files = asyncSignal(AsyncLoading());

  static void register() {
    final service = FileExplorerService();
    effect(service.getData);
    GetIt.I.registerSingleton<FileExplorerService>(service);
  }

  void getData() async {
    files.value = AsyncLoading();
    if (provider.value == null || _storage == null) {
      files.value = AsyncData([]);
      return;
    }
    try {
      final list = await provider.value!.listFiles(
        path.value,
        _storage!.key,
        filter.value,
      );
      listLength.value = list.length;
      files.value = AsyncData(list);
    } catch (e, t) {
      _logger.error('files', '加载文件列表失败', error: e, stackTrace: t);
      files.value = AsyncError(e, t);
    }
  }

  void setProvider(FileExplorerProvider newProvider, Storage storage) {
    batch(() {
      provider.value?.dispose();
      provider.value = newProvider;
      _storage = storage;
      path.value = '/';
    });
    _logger.info('setProvider', '设置新的文件库提供者');
  }

  void next(String name) {
    batch(() {
      path.value = '${path.value}$name/';
      filter.value = Filter();
    });
  }

  bool back() {
    if (path.value == '/') {
      return false;
    }
    batch(() {
      path.value =
          '${path.value.split('/').sublist(0, path.value.split('/').length - 2).join('/')}/';
      filter.value = Filter();
    });
    return true;
  }

  void cd(String newPath) {
    batch(() {
      path.value = newPath;
      filter.value = Filter();
    });
  }

  Future<VideoInfo?> selectVideo(int videoIndex) async {
    _logger.info('selectVideo', '选择视频: $videoIndex');
    if (files.value is AsyncData) {
      final list = files.value.requireValue;
      for (var file in list) {
        if (!file.isVideo) continue;
        if (file.videoIndex == videoIndex) {
          return getVideoInfo(file.videoIndex, file.path);
        }
      }
    }
    _logger.warn('selectVideo', '文件列表未加载完成');
    return null;
  }

  VideoInfo getVideoInfo(int index, String path) {
    final videoPath = provider.value!.getVideoUrl(path);
    final headers = provider.value!.headers;
    return VideoInfo.fromFile(
      currentVideoPath: videoPath,
      virtualVideoPath: '${_storage!.key}$path',
      headers: headers.map((key, value) => MapEntry(key, value.toString())),
      historiesType: HistoriesType.fileStorage,
      videoIndex: index,
      listLength: listLength.value,
      canSwitch: true,
      storageKey: _storage!.uniqueKey,
    );
  }

  Future<VideoInfo> getVideoInfoFromHistory(History history) async {
    final parts = history.url!.split('/');
    final path = parts.sublist(1, parts.length);
    final videoPath = provider.value!.getVideoUrl('/${path.join('/')}');
    final headers = provider.value!.headers;
    return VideoInfo.fromFile(
      currentVideoPath: videoPath,
      virtualVideoPath: history.url!,
      headers: headers.map((key, value) => MapEntry(key, value.toString())),
      historiesType: HistoriesType.fileStorage,
      subtitle: history.subtitle,
      storageKey: _storage!.uniqueKey,
    );
  }
}

// WebDAV implementation (placeholder)
class WebDAVFileExplorerProvider implements FileExplorerProvider {
  WebdavClient? client;
  late final Map<String, String> _headers;
  final _logger = Logger('WebDAVFileExplorerProvider');
  late final String url;

  @override
  Map<String, String> get headers => _headers;

  WebDAVFileExplorerProvider(Storage storage) {
    if (storage.isAnonymous!) {
      _headers = {"Authorization": "Basic ${base64Encode(utf8.encode(':'))}"};
    } else {
      _headers = {
        "Authorization":
            "Basic ${base64Encode(utf8.encode('${storage.account!}:${storage.password!}'))}",
      };
    }
    client = null;
    if (storage.isAnonymous!) {
      client = WebdavClient.noAuth(url: storage.url);
    } else {
      client = WebdavClient.basicAuth(
        url: storage.url,
        user: storage.account!,
        pwd: storage.password!,
      );
    }
    url = storage.url;
    _logger.info('WebDAVFileExplorerProvider', '初始化WebDAV文件库提供者');
  }

  @override
  String getVideoUrl(String path) {
    return '$url$path';
  }

  @override
  Future<List<FileItem>> listFiles(
    String path,
    String rootPath,
    Filter filter,
  ) async {
    try {
      if (client == null) {
        return [];
      }
      List<FileItem> list = [];
      var fileList = await client!.readDir(path);
      for (var file in fileList) {
        if (filter.searchTerm.isNotEmpty &&
            !file.name.contains(filter.searchTerm)) {
          continue;
        }
        final filePath = '$path${file.name}';
        if (FileItem.getFileType(file.name) != FileType.video && !file.isDir) {
          continue;
        }
        if (file.isDir) {
          if (filter.displayMode == 2) continue;
          list.add(
            FileItem(name: file.name, path: filePath, type: FileType.folder),
          );
          continue;
        }
        if (filter.displayMode == 1) continue;
        var uniqueKey = CryptoUtils.generateVideoUniqueKey(
          '$rootPath$filePath',
        );
        var history = GetIt.I.get<HistoryService>().getHistory(uniqueKey);
        list.add(
          FileItem(
            name: file.name,
            path: filePath,
            type: FileItem.getFileType(file.name),
            size: file.size,
            uniqueKey: uniqueKey,
            history: history,
          ),
        );
      }
      list.sort(_compare);
      if (!filter.sortOrder) {
        list = list.reversed.toList();
      }
      list = setVideoIndex(list);
      return list;
    } on DioException catch (e, t) {
      _logger.dio('listFiles', e, t, action: '获取文件列表');
    } on WebdavException catch (e, t) {
      _logger.webdav('listFiles', e, t, action: '获取文件列表');
    } catch (e, t) {
      _logger.error('listFiles', '获取文件列表失败', error: e, stackTrace: t);
      throw AppException('获取文件列表失败', e);
    }
  }

  @override
  Future<bool> downloadVideo(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      if (client == null) {
        throw AppException('WebDAV客户端未初始化', null);
      }
      final targetFile = File(localPath);
      await targetFile.parent.create(recursive: true);
      await client!.readFile(
        path,
        localPath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      _logger.info('downloadVideo', 'WebDAV下载完成: $path -> $localPath');
      return true;
    } on DioException catch (e, t) {
      if (e.type == DioExceptionType.cancel) {
        return false;
      }
      _logger.error('downloadVideo', 'WebDAV下载失败', error: e, stackTrace: t);
      return false;
    } catch (e, t) {
      _logger.error('downloadVideo', 'WebDAV下载失败', error: e, stackTrace: t);
      return false;
    }
  }

  @override
  Future<void> init() async {}

  @override
  void dispose() {}
}

class LocalFileExplorerProvider implements FileExplorerProvider {
  final String url;
  final _logger = Logger('LocalFileExplorerProvider');
  final bool _useSaf;

  @override
  Map<String, String> get headers => {};
  LocalFileExplorerProvider(this.url) : _useSaf = AndroidSaf.isTreeUri(url);

  @override
  String getVideoUrl(String path) {
    if (_useSaf) return '$url${Uri.encodeComponent(path)}';
    return '$url$path';
  }

  @override
  Future<List<FileItem>> listFiles(
    String path,
    String rootPath,
    Filter filter,
  ) async {
    try {
      if (_useSaf) return _listSafFiles(path, rootPath, filter);
      final historyService = GetIt.I.get<HistoryService>();
      if (path.isEmpty) {
        return [];
      }
      var list = <FileItem>[];
      final fileList = Directory('$url$path').list();
      await for (var file in fileList) {
        if (filter.searchTerm.isNotEmpty &&
            !file.path.contains(filter.searchTerm)) {
          continue;
        }
        if (file is! File) {
          if (filter.displayMode == 2) continue;
          list.add(
            FileItem(
              name: file.path.split('/').last,
              path: file.path,
              type: FileType.folder,
            ),
          );
          continue;
        }
        if (filter.displayMode == 1) continue;
        final filePath = '$path${file.path.split('/').last}';
        if (FileItem.getFileType(file.path) != FileType.video) {
          continue;
        }
        var uniqueKey = CryptoUtils.generateVideoUniqueKey(
          '$rootPath$filePath',
        );
        var history = historyService.getHistory(uniqueKey);
        list.add(
          FileItem(
            name: file.path.split('/').last,
            path: filePath,
            type: FileItem.getFileType(file.path),
            size: file.lengthSync(),
            uniqueKey: uniqueKey,
            history: history,
          ),
        );
      }
      list.sort(_compare);
      if (!filter.sortOrder) {
        list = list.reversed.toList();
      }
      list = setVideoIndex(list);
      return list;
    } catch (e, t) {
      _logger.error('listFiles', '获取文件列表失败', error: e, stackTrace: t);
      throw AppException('获取文件列表失败', e);
    }
  }

  Future<List<FileItem>> _listSafFiles(
    String path,
    String rootPath,
    Filter filter,
  ) async {
    final historyService = GetIt.I.get<HistoryService>();
    final fileList = await AndroidSaf.listDirectory(url, path);
    var list = <FileItem>[];
    for (final file in fileList) {
      if (filter.searchTerm.isNotEmpty &&
          !file.name.contains(filter.searchTerm)) {
        continue;
      }
      final filePath = '$path${file.name}';
      if (file.isDir) {
        if (filter.displayMode == 2) continue;
        list.add(
          FileItem(name: file.name, path: filePath, type: FileType.folder),
        );
        continue;
      }
      if (filter.displayMode == 1) continue;
      if (FileItem.getFileType(file.name) != FileType.video) continue;
      final uniqueKey = CryptoUtils.generateVideoUniqueKey(
        '$rootPath$filePath',
      );
      final history = historyService.getHistory(uniqueKey);
      list.add(
        FileItem(
          name: file.name,
          path: filePath,
          type: FileType.video,
          size: file.length < 0 ? null : file.length,
          uniqueKey: uniqueKey,
          history: history,
        ),
      );
    }
    list.sort(_compare);
    if (!filter.sortOrder) list = list.reversed.toList();
    return setVideoIndex(list);
  }

  @override
  Future<bool> downloadVideo(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    throw AppException('本地视频不支持缓存视频', null);
  }

  @override
  Future<void> init() async {}

  @override
  void dispose() {}
}

int _compare(FileItem a, FileItem b) {
  if (a.isFolder && !b.isFolder) {
    return -1;
  }
  if (!a.isFolder && b.isFolder) {
    return 1;
  }
  return StringUtilxx_c.compareExtend(a.name, b.name);
}

List<FileItem> setVideoIndex(List<FileItem> list) {
  int videoIndex = 0;
  for (var i = 0; i < list.length; i++) {
    if (!list[i].isVideo) {
      continue;
    }
    list[i].videoIndex = videoIndex;
    videoIndex++;
  }
  return list;
}
