import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dart_smb2/dart_smb2.dart';
import 'package:fldanplay/model/file_item.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/utils/android_saf.dart';
import 'package:fldanplay/utils/crypto_utils.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:ftpconnect/ftpconnect.dart' hide Logger;
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:string_util_xx/StringUtilxx.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

String joinFilePath(String parent, String name) =>
    parent.isEmpty ? name : '$parent/$name';

String joinUrlPath(String base, String path) {
  if (path.isEmpty) return base;
  final normalizedBase = base.endsWith('/')
      ? base.substring(0, base.length - 1)
      : base;
  return '$normalizedBase/$path';
}

String filePathFromVirtualPath(String virtualPath, String storageKey) {
  if (storageKey.isEmpty) return virtualPath;
  if (virtualPath == storageKey) return '';
  final prefix = '$storageKey/';
  return virtualPath.startsWith(prefix)
      ? virtualPath.substring(prefix.length)
      : virtualPath;
}

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

FileExplorerProvider? createFileExplorerProvider(Storage storage) {
  return switch (storage.storageType) {
    .webdav => WebDAVFileExplorerProvider(storage),
    .ftp => FTPFileExplorerProvider(storage),
    .smb => SMBFileExplorerProvider(storage),
    .local => LocalFileExplorerProvider(storage.url),
    _ => null,
  };
}

class SMBFileExplorerProvider implements FileExplorerProvider {
  final Storage storage;
  final _logger = Logger('SMBFileExplorerProvider');
  Smb2Pool? _pool;

  SMBFileExplorerProvider(this.storage);

  Smb2Pool get _client {
    if (_pool == null) throw AppException('SMB客户端未连接', null);
    return _pool!;
  }

  @override
  Map<String, String> get headers => {};

  @override
  Future<void> init() async {
    final share = storage.share;
    if (storage.url.isEmpty || share == null || share.isEmpty) {
      throw AppException('SMB配置不完整', null);
    }
    try {
      _pool = await Smb2Pool.connect(
        host: storage.url,
        share: share,
        user: storage.account?.isEmpty == true ? null : storage.account,
        password: storage.password?.isEmpty == true ? null : storage.password,
        workers: 1,
        version: .any,
      );
      _logger.info('init', 'SMB媒体库连接成功: ${storage.url}/$share');
    } catch (e, t) {
      _pool = null;
      _logger.error('init', 'SMB媒体库连接失败', error: e, stackTrace: t);
      if (e is AppException) rethrow;
      throw AppException('SMB连接失败', e);
    }
  }

  @override
  String getVideoUrl(String path) {
    final user = storage.account?.isNotEmpty == true ? storage.account : null;
    final password = storage.password?.isNotEmpty == true
        ? storage.password
        : null;
    final userInfo = user == null ? null : '$user:${password ?? ''}';
    final remotePath = [
      storage.share!,
      path,
    ].where((value) => value.isNotEmpty).join('/');
    return Uri(
      scheme: 'smb2',
      userInfo: userInfo,
      host: storage.url,
      path: '/$remotePath',
    ).toString();
  }

  @override
  Future<List<FileItem>> listFiles(
    String path,
    String rootPath,
    Filter filter,
  ) async {
    try {
      final entries = await _client.listDirectory(path);
      var list = <FileItem>[];
      for (final entry in entries) {
        if (filter.searchTerm.isNotEmpty &&
            !entry.name.contains(filter.searchTerm)) {
          continue;
        }
        final filePath = joinFilePath(path, entry.name);
        if (entry.isDirectory) {
          if (filter.displayMode == 2) continue;
          list.add(
            FileItem(
              name: entry.name,
              path: filePath,
              type: .folder,
              uniqueKey: CryptoUtils.generateVideoUniqueKey(filePath),
            ),
          );
          continue;
        }
        if (filter.displayMode == 1 ||
            FileItem.getFileType(entry.name) != .video) {
          continue;
        }
        list.add(
          FileItem(
            name: entry.name,
            path: filePath,
            type: .video,
            size: entry.size,
            uniqueKey: CryptoUtils.generateVideoUniqueKey(
              '$rootPath/$filePath',
            ),
          ),
        );
      }
      list.sort(_compare);
      if (!filter.sortOrder) list = list.reversed.toList();
      return setVideoIndex(list);
    } catch (e, t) {
      _logger.error('listFiles', '获取SMB文件列表失败', error: e, stackTrace: t);
      if (e is AppException) rethrow;
      throw AppException('获取SMB文件列表失败', e);
    }
  }

  @override
  Future<bool> downloadVideo(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) return false;
    try {
      final targetFile = File(localPath);
      await targetFile.parent.create(recursive: true);
      await _client.downloadToFile(
        path,
        targetFile,
        onProgress: onProgress,
        isCanceled: () => cancelToken?.isCancelled == true,
      );
      return cancelToken?.isCancelled != true;
    } catch (e, t) {
      if (cancelToken?.isCancelled == true) return false;
      _logger.error('downloadVideo', 'SMB下载失败', error: e, stackTrace: t);
      if (e is AppException) rethrow;
      throw AppException('SMB下载失败', e);
    }
  }

  @override
  void dispose() {
    final pool = _pool;
    _pool = null;
    pool?.disconnect().catchError((e, t) {
      _logger.warn('dispose', '关闭SMB连接失败', error: e, stackTrace: t);
    });
  }
}

class Filter {
  String searchTerm = '';
  // 0: 全部，1: 文件夹，2: 视频
  int displayMode = 0;
  // true: 升序，false: 降序
  bool sortOrder = true;
  Filter();

  bool isFiltered() {
    return searchTerm.isNotEmpty || displayMode != 0 || sortOrder != true;
  }
}

class FileExplorerService {
  final Signal<FileExplorerProvider?> provider = signal(null);
  final Signal<List<String>> navigation = signal(<String>[]);
  int listLength = 0;
  Storage? _storage;
  final _logger = Logger('FileExplorerService');
  final Signal<Filter> filter = signal(Filter());
  final AsyncSignal<List<FileItem>> files = asyncSignal(AsyncLoading());

  static void register() {
    final service = FileExplorerService();
    effect(service.getData);
    GetIt.I.registerSingleton<FileExplorerService>(service);
  }

  void getData({bool load = true}) async {
    if (load) files.value = AsyncLoading();
    if (provider.value == null || _storage == null) {
      files.value = AsyncData([]);
      return;
    }
    try {
      final list = await provider.value!.listFiles(
        navigation.value.join('/'),
        _storage!.key,
        filter.value,
      );
      listLength = list.length;
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
      navigation.value = [];
      filter.value = Filter();
    });
    _logger.info('setProvider', '设置新的文件库提供者');
  }

  void enterDirectory(String name) {
    batch(() {
      navigation.value = [...navigation.value, name];
      filter.value = Filter();
    });
  }

  String? back() {
    final stack = navigation.value;
    if (stack.isEmpty) return null;
    final popped = stack.last;
    batch(() {
      navigation.value = stack.sublist(0, stack.length - 1);
      filter.value = Filter();
    });
    return popped;
  }

  void jumpToIndex(int depth) {
    final stack = navigation.value;
    if (depth < 0 || depth >= stack.length) return;
    batch(() {
      navigation.value = stack.sublist(0, depth);
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
      virtualVideoPath: '${_storage!.key}/$path',
      headers: headers.map((key, value) => MapEntry(key, value.toString())),
      historiesType: HistoriesType.fileStorage,
      videoIndex: index,
      listLength: listLength,
      canSwitch: true,
      storageKey: _storage!.uniqueKey,
    );
  }

  Future<VideoInfo> getVideoInfoFromHistory(History history) async {
    final historyPath = history.url ?? '';
    final storageKey = _storage!.key;
    final path = filePathFromVirtualPath(historyPath, storageKey);
    final videoPath = provider.value!.getVideoUrl(path);
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
    return joinUrlPath(url, path);
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
        final filePath = joinFilePath(path, file.name);
        if (FileItem.getFileType(file.name) != FileType.video && !file.isDir) {
          continue;
        }
        if (file.isDir) {
          if (filter.displayMode == 2) continue;
          final uniqueKey = CryptoUtils.generateVideoUniqueKey(filePath);
          list.add(
            FileItem(
              name: file.name,
              path: filePath,
              type: .folder,
              uniqueKey: uniqueKey,
            ),
          );
          continue;
        }
        if (filter.displayMode == 1) continue;
        var uniqueKey = CryptoUtils.generateVideoUniqueKey(
          '$rootPath/$filePath',
        );
        list.add(
          FileItem(
            name: file.name,
            path: filePath,
            type: FileItem.getFileType(file.name),
            size: file.size,
            uniqueKey: uniqueKey,
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
      if (e.type == DioExceptionType.cancel) return false;
      _logger.error('downloadVideo', 'WebDAV下载失败', error: e, stackTrace: t);
      rethrow;
    } catch (e, t) {
      _logger.error('downloadVideo', 'WebDAV下载失败', error: e, stackTrace: t);
      rethrow;
    }
  }

  @override
  Future<void> init() async {}

  @override
  void dispose() {}
}

class FTPFileExplorerProvider implements FileExplorerProvider {
  final Storage storage;
  final _logger = Logger('FTPFileExplorerProvider');
  FTPConnect? _client;

  FTPFileExplorerProvider(this.storage);

  @override
  Map<String, String> get headers => {};

  FTPConnect get _getClient {
    if (_client == null) throw AppException('FTP客户端未连接', null);
    return _client!;
  }

  @override
  Future<void> init() async {
    final client = FTPConnect(
      storage.url,
      port: storage.port ?? 21,
      user: storage.account ?? '',
      pass: storage.password ?? '',
      supportIPV6: storage.url.contains(':'),
      transferMode: storage.ftpMode == 'active' ? .active : .passive,
    );
    _client = client;
    try {
      final connected = await client.connect();
      if (!connected) {
        throw AppException('FTP连接失败', null);
      }
      _logger.info('init', 'FTP媒体库连接成功: ${storage.url}');
    } catch (e, t) {
      _client = null;
      _logger.error('init', 'FTP媒体库连接失败', error: e, stackTrace: t);
      if (e is AppException) rethrow;
      throw AppException('FTP连接失败', e);
    }
  }

  @override
  String getVideoUrl(String path) {
    return joinUrlPath(
      'ftp://${storage.account ?? ''}:${storage.password ?? ''}@'
      '${storage.url}:${storage.port ?? 21}',
      path,
    );
  }

  @override
  Future<List<FileItem>> listFiles(
    String path,
    String rootPath,
    Filter filter,
  ) async {
    try {
      final entries = await _getClient.listDirectoryContent(
        path.isEmpty ? '/' : '/$path',
      );
      var list = <FileItem>[];
      for (final entry in entries) {
        if (entry.type != .dir && entry.type != .file) continue;
        if (filter.searchTerm.isNotEmpty &&
            !entry.name.contains(filter.searchTerm)) {
          continue;
        }
        final filePath = joinFilePath(path, entry.name);
        if (entry.type == .dir) {
          if (filter.displayMode == 2) continue;
          list.add(
            FileItem(
              name: entry.name,
              path: filePath,
              type: .folder,
              uniqueKey: CryptoUtils.generateVideoUniqueKey(filePath),
            ),
          );
          continue;
        }
        if (filter.displayMode == 1 ||
            FileItem.getFileType(entry.name) != .video) {
          continue;
        }
        list.add(
          FileItem(
            name: entry.name,
            path: filePath,
            type: .video,
            size: entry.size,
            uniqueKey: CryptoUtils.generateVideoUniqueKey(
              '$rootPath/$filePath',
            ),
          ),
        );
      }
      list.sort(_compare);
      if (!filter.sortOrder) list = list.reversed.toList();
      return setVideoIndex(list);
    } catch (e, t) {
      _logger.error('listFiles', '获取FTP文件列表失败', error: e, stackTrace: t);
      if (e is AppException) rethrow;
      throw AppException('获取FTP文件列表失败', e);
    }
  }

  @override
  Future<bool> downloadVideo(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) return false;
    try {
      final client = _getClient;
      final targetFile = File(localPath);
      await targetFile.parent.create(recursive: true);
      var cancelled = false;
      if (cancelToken != null) {
        cancelToken.whenCancel.then((_) async {
          cancelled = true;
          if (_client == client) await _disconnect(client);
        });
      }
      final result = await client.downloadFile(
        '/$path',
        targetFile,
        onProgress: (_, received, total) {
          if (!cancelled) onProgress?.call(received, total);
        },
      );
      if (cancelled) return false;
      _logger.info('downloadVideo', 'FTP下载完成: $path -> $localPath');
      return result;
    } catch (e, t) {
      if (cancelToken?.isCancelled == true) return false;
      _logger.error('downloadVideo', 'FTP下载失败', error: e, stackTrace: t);
      rethrow;
    }
  }

  @override
  void dispose() {
    final client = _client;
    _client = null;
    if (client != null) _disconnect(client);
  }

  Future<void> _disconnect(FTPConnect client) async {
    try {
      await client.disconnect();
    } catch (e, t) {
      _logger.warn('dispose', '关闭FTP连接失败', error: e, stackTrace: t);
    }
  }
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
    if (_useSaf) {
      return '$url${Uri.encodeComponent(path.isEmpty ? '/' : '/$path')}';
    }
    return joinUrlPath(url, path);
  }

  @override
  Future<List<FileItem>> listFiles(
    String path,
    String rootPath,
    Filter filter,
  ) async {
    try {
      if (_useSaf) return await _listSafFiles(path, rootPath, filter);
      var list = <FileItem>[];
      final fileList = Directory(joinUrlPath(url, path)).list();
      await for (var file in fileList) {
        final name = file.uri.pathSegments.lastWhere(
          (segment) => segment.isNotEmpty,
        );
        if (filter.searchTerm.isNotEmpty && !name.contains(filter.searchTerm)) {
          continue;
        }
        if (file is! File) {
          if (filter.displayMode == 2) continue;
          final filePath = joinFilePath(path, name);
          final uniqueKey = CryptoUtils.generateVideoUniqueKey(filePath);
          list.add(
            FileItem(
              name: name,
              path: filePath,
              type: FileType.folder,
              uniqueKey: uniqueKey,
            ),
          );
          continue;
        }
        if (filter.displayMode == 1) continue;
        final filePath = joinFilePath(path, name);
        if (FileItem.getFileType(name) != FileType.video) {
          continue;
        }
        var uniqueKey = CryptoUtils.generateVideoUniqueKey(
          '$rootPath/$filePath',
        );
        list.add(
          FileItem(
            name: name,
            path: filePath,
            type: FileItem.getFileType(name),
            size: file.lengthSync(),
            uniqueKey: uniqueKey,
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
    final fileList = await AndroidSaf.listDirectory(url, path);
    var list = <FileItem>[];
    for (final file in fileList) {
      if (filter.searchTerm.isNotEmpty &&
          !file.name.contains(filter.searchTerm)) {
        continue;
      }
      final filePath = joinFilePath(path, file.name);
      if (file.isDir) {
        if (filter.displayMode == 2) continue;
        final uniqueKey = CryptoUtils.generateVideoUniqueKey(filePath);
        list.add(
          FileItem(
            name: file.name,
            path: filePath,
            type: .folder,
            uniqueKey: uniqueKey,
          ),
        );
        continue;
      }
      if (filter.displayMode == 1) continue;
      if (FileItem.getFileType(file.name) != FileType.video) continue;
      final uniqueKey = CryptoUtils.generateVideoUniqueKey(
        '$rootPath/$filePath',
      );
      list.add(
        FileItem(
          name: file.name,
          path: filePath,
          type: FileType.video,
          size: file.length < 0 ? null : file.length,
          uniqueKey: uniqueKey,
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
