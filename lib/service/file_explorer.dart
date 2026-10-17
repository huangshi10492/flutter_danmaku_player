import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dart_smb2/dart_smb2.dart';
import 'package:fldanplay/model/file_item.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/storage2.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/utils/android_saf.dart';
import 'package:fldanplay/utils/crypto_utils.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:ftpconnect/ftpconnect.dart' hide Logger;
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:string_util_xx/StringUtilxx.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

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

typedef FileExplorerEntry = ({String name, bool isDir, int? size});

sealed class FileExplorerProvider {
  FileExplorerProvider(this._displayName);
  final String _displayName;
  late final Logger _logger = Logger(runtimeType.toString());
  Map<String, String> get headers => const {};
  Future<void> init() async {}
  void dispose() {}
  String getVideoUrl(String path);
  Future<List<FileExplorerEntry>> readEntries(String path);
  Future<bool> saveToFile(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });
  Future<List<FileItem>> listFiles(
    String path,
    String rootPath,
    Filter filter,
  ) async {
    try {
      return _buildItems(await readEntries(path), path, rootPath, filter);
    } catch (e, t) {
      _fail('获取$_displayName文件列表', e, t);
    }
  }

  Future<bool> downloadVideo(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      if (cancelToken?.isCancelled == true) return false;
      await File(localPath).parent.create(recursive: true);
      return await saveToFile(
        path,
        localPath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } catch (e, t) {
      if (cancelToken?.isCancelled == true || _isCancelError(e)) return false;
      _fail('$_displayName下载', e, t);
    }
  }

  List<FileItem> _buildItems(
    List<FileExplorerEntry> entries,
    String path,
    String rootPath,
    Filter filter,
  ) {
    final list = <FileItem>[];
    for (final entry in entries) {
      final filePath = path.isEmpty ? entry.name : '$path/${entry.name}';
      if (!entry.isDir && FileItem.isSubtitleFileName(entry.name)) {
        list.add(
          FileItem(
            name: entry.name,
            path: filePath,
            type: .subtitle,
            uniqueKey: '',
          ),
        );
        continue;
      }
      if (filter.searchTerm.isNotEmpty &&
          !entry.name.contains(filter.searchTerm)) {
        continue;
      }
      if (entry.isDir) {
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
      if (filter.displayMode == 1) continue;
      if (FileItem.getFileType(entry.name) != .video) continue;
      list.add(
        FileItem(
          name: entry.name,
          path: filePath,
          type: .video,
          size: entry.size,
          uniqueKey: CryptoUtils.generateVideoUniqueKey('$rootPath/$filePath'),
        ),
      );
    }
    list.sort(_compare);
    final ordered = filter.sortOrder ? list : list.reversed.toList();
    return _setVideoIndex(ordered);
  }

  bool _isCancelError(Object e) =>
      (e is DioException && e.type == DioExceptionType.cancel) ||
      (e is Smb2Exception && e.isCancelled);

  Never _fail(String action, Object e, StackTrace t) {
    if (e is DioException) _logger.dio(action, e, t, action: action);
    if (e is WebdavException) _logger.webdav(action, e, t, action: action);
    _logger.error(action, '$action失败', error: e, stackTrace: t);
    throw e is AppException ? e : AppException('$action失败', e);
  }
}

FileExplorerProvider? createFileExplorerProvider(Storage2 storage) {
  return switch (storage) {
    final WebDavStorage s => WebDAVFileExplorerProvider(s),
    final FtpStorage s => FTPFileExplorerProvider(s),
    final SmbStorage s => SMBFileExplorerProvider(s),
    final LocalStorage s => LocalFileExplorerProvider(s),
    _ => null,
  };
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
  Storage2? _storage;
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
      final rawList = await provider.value!.listFiles(
        navigation.value.join('/'),
        _storage!.key,
        filter.value,
      );
      final list = FileItem.resolveSubtitles(rawList);
      listLength = list.length;
      files.value = AsyncData(list);
    } catch (e, t) {
      _logger.error('files', '加载文件列表失败', error: e, stackTrace: t);
      files.value = AsyncError(e, t);
    }
  }

  void setProvider(FileExplorerProvider newProvider, Storage2 storage) {
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
          return getVideoInfo(
            file.videoIndex,
            file.path,
            subtitlePaths: file.subtitles,
          );
        }
      }
    }
    _logger.warn('selectVideo', '文件列表未加载完成');
    return null;
  }

  VideoInfo getVideoInfo(
    int index,
    String path, {
    List<String> subtitlePaths = const [],
  }) {
    final videoPath = provider.value!.getVideoUrl(path);
    final headers = provider.value!.headers;
    return VideoInfo.fromFile(
      currentVideoPath: videoPath,
      virtualVideoPath: path,
      headers: headers.map((key, value) => MapEntry(key, value.toString())),
      historiesType: HistoriesType.fileStorage,
      videoIndex: index,
      listLength: listLength,
      canSwitch: true,
      storageKey: _storage!.uniqueKey,
      externalSubtitles: _buildExternalSubtitles(
        path.split('/').last,
        subtitlePaths,
      ),
    );
  }

  List<ExternalSubtitle> _buildExternalSubtitles(
    String videoName,
    List<String> subtitlePaths,
  ) {
    if (subtitlePaths.isEmpty) return const [];
    return subtitlePaths.map((path) {
      final subtitleName = path.split('/').last;
      return ExternalSubtitle(
        provider.value!.getVideoUrl(path),
        FileItem.subtitleTitle(videoName, subtitleName),
        'external',
        path: path,
      );
    }).toList();
  }

  Future<List<ExternalSubtitle>> _discoverSubtitles(String path) async {
    final i = path.lastIndexOf('/');
    final list = FileItem.resolveSubtitles(
      await provider.value!.listFiles(
        i > 0 ? path.substring(0, i) : '',
        _storage!.key,
        Filter(),
      ),
    );
    return switch (list.where((f) => f.isVideo && f.path == path).firstOrNull) {
      final v? => _buildExternalSubtitles(v.name, v.subtitles),
      _ => const [],
    };
  }

  Future<VideoInfo> getVideoInfoFromHistory(History history) async {
    final historyPath = history.url ?? '';
    final storageKey = _storage!.key;
    final path = filePathFromVirtualPath(historyPath, storageKey);
    final videoPath = provider.value!.getVideoUrl(path);
    final headers = provider.value!.headers;
    final externalSubtitles = await _discoverSubtitles(path);
    return VideoInfo.fromFile(
      currentVideoPath: videoPath,
      virtualVideoPath: path,
      headers: headers.map((key, value) => MapEntry(key, value.toString())),
      historiesType: HistoriesType.fileStorage,
      subtitle: history.subtitle,
      storageKey: _storage!.uniqueKey,
      externalSubtitles: externalSubtitles,
    );
  }
}

final class SMBFileExplorerProvider extends FileExplorerProvider {
  final SmbStorage storage;
  Smb2Pool? _pool;

  SMBFileExplorerProvider(this.storage) : super('SMB');

  Smb2Pool get _client {
    if (_pool == null) throw AppException('SMB客户端未连接', null);
    return _pool!;
  }

  @override
  Future<void> init() async {
    final share = storage.share;
    if (storage.host.isEmpty || share.isEmpty) {
      throw AppException('SMB配置不完整', null);
    }
    try {
      _pool = await Smb2Pool.connect(
        host: storage.host,
        share: share,
        user: storage.account?.isEmpty == true ? null : storage.account,
        password: storage.password?.isEmpty == true ? null : storage.password,
        workers: 1,
        version: .any,
      );
      _logger.info('init', 'SMB媒体库连接成功: ${storage.host}/$share');
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
      storage.share,
      path,
    ].where((value) => value.isNotEmpty).join('/');
    return Uri(
      scheme: 'smb2',
      userInfo: userInfo,
      host: storage.host,
      path: '/$remotePath',
    ).toString();
  }

  @override
  Future<List<FileExplorerEntry>> readEntries(String path) async {
    final entries = await _client.listDirectory(path);
    return [
      for (final entry in entries)
        (name: entry.name, isDir: entry.isDirectory, size: entry.size),
    ];
  }

  @override
  Future<bool> saveToFile(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final smb2Token = Smb2CancelToken();
    var finished = false;
    cancelToken?.whenCancel.then((_) {
      if (!finished) smb2Token.cancel();
    });
    try {
      await _client.downloadToFile(
        path,
        localPath,
        onProgress: onProgress,
        cancelToken: smb2Token,
      );
      return true;
    } finally {
      finished = true;
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

final class WebDAVFileExplorerProvider extends FileExplorerProvider {
  WebdavClient? client;
  Map<String, String> _headers = {};
  late final String url;

  WebDAVFileExplorerProvider(WebDavStorage storage) : super('WebDAV') {
    final account = storage.account ?? '';
    final password = storage.password ?? '';
    if (!storage.isAnonymous) {
      _headers = {
        "Authorization":
            "Basic ${base64Encode(utf8.encode('$account:$password'))}",
      };
    }
    client = storage.isAnonymous
        ? .noAuth(url: storage.url)
        : .basicAuth(url: storage.url, user: account, pwd: password);
    url = storage.url;
    _logger.info('WebDAVFileExplorerProvider', '初始化WebDAV文件库提供者');
  }

  @override
  Map<String, String> get headers => _headers;

  @override
  String getVideoUrl(String path) {
    return joinUrlPath(url, path);
  }

  @override
  Future<List<FileExplorerEntry>> readEntries(String path) async {
    final client = this.client;
    if (client == null) return const [];
    final fileList = await client.readDir(path);
    return [
      for (final file in fileList)
        (name: file.name, isDir: file.isDir, size: file.size),
    ];
  }

  @override
  Future<bool> saveToFile(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final client = this.client;
    if (client == null) throw AppException('WebDAV客户端未初始化', null);
    await client.readFile(
      path,
      localPath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    _logger.info('downloadVideo', 'WebDAV下载完成: $path -> $localPath');
    return true;
  }
}

final class FTPFileExplorerProvider extends FileExplorerProvider {
  final FtpStorage storage;
  FTPConnect? _client;

  FTPFileExplorerProvider(this.storage) : super('FTP');

  FTPConnect get _getClient {
    if (_client == null) throw AppException('FTP客户端未连接', null);
    return _client!;
  }

  @override
  Future<void> init() async {
    final client = FTPConnect(
      storage.host,
      port: storage.port,
      user: storage.account,
      pass: storage.password ?? '',
      supportIPV6: storage.host.contains(':'),
      transferMode: storage.ftpMode == 'active' ? .active : .passive,
    );
    _client = client;
    try {
      final connected = await client.connect();
      if (!connected) {
        throw AppException('FTP连接失败', null);
      }
      _logger.info('init', 'FTP媒体库连接成功: ${storage.host}');
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
      'ftp://${storage.account}:${storage.password ?? ''}@'
      '${storage.host}:${storage.port}',
      path,
    );
  }

  @override
  Future<List<FileExplorerEntry>> readEntries(String path) async {
    final entries = await _getClient.listDirectoryContent(
      path.isEmpty ? '/' : '/$path',
    );
    return [
      for (final entry in entries)
        if (entry.type == .dir || entry.type == .file)
          (name: entry.name, isDir: entry.type == .dir, size: entry.size),
    ];
  }

  @override
  Future<bool> saveToFile(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final client = _getClient;
    var cancelled = false;
    if (cancelToken != null) {
      cancelToken.whenCancel.then((_) async {
        cancelled = true;
        if (_client == client) await _disconnect(client);
      });
    }
    final result = await client.downloadFile(
      '/$path',
      File(localPath),
      onProgress: (_, received, total) {
        if (!cancelled) onProgress?.call(received, total);
      },
    );
    if (cancelled) return false;
    _logger.info('downloadVideo', 'FTP下载完成: $path -> $localPath');
    return result;
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

final class LocalFileExplorerProvider extends FileExplorerProvider {
  final LocalStorage storage;
  final bool _useSaf;

  LocalFileExplorerProvider(this.storage)
    : _useSaf = AndroidSaf.isTreeUri(storage.url),
      super('本地');

  @override
  String getVideoUrl(String path) {
    if (_useSaf) {
      return '${storage.url}${Uri.encodeComponent(path.isEmpty ? '/' : '/$path')}';
    }
    return joinUrlPath(storage.url, path);
  }

  @override
  Future<List<FileExplorerEntry>> readEntries(String path) async {
    if (_useSaf) {
      final files = await AndroidSaf.listDirectory(storage.url, path);
      return [
        for (final file in files)
          (
            name: file.name,
            isDir: file.isDir,
            size: file.length < 0 ? null : file.length,
          ),
      ];
    }
    final entries = <FileExplorerEntry>[];
    final fileList = Directory(joinUrlPath(storage.url, path)).list();
    await for (final file in fileList) {
      final name = file.uri.pathSegments.lastWhere(
        (segment) => segment.isNotEmpty,
      );
      entries.add((
        name: name,
        isDir: file is! File,
        size: file is File ? file.lengthSync() : null,
      ));
    }
    return entries;
  }

  @override
  Future<bool> saveToFile(
    String path,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    throw AppException('本地视频不支持缓存视频', null);
  }
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

List<FileItem> _setVideoIndex(List<FileItem> list) {
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
