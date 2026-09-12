import 'dart:convert';
import 'dart:io';

import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

enum SyncStatus { idle, syncing, success, failed }

class WebDAVSyncService {
  static const String _syncFolderPath = '/fldanplay';
  static const String _timeFileName = 'time.txt';

  late ConfigureService _configureService;
  late HistoryService _historyService;

  final _log = Logger('webdav_sync');

  final Signal<SyncStatus> syncStatus = Signal(SyncStatus.idle);
  final Signal<String?> syncMessage = Signal(null);

  bool _isSyncing = false;

  WebdavClient? _client;

  WebDAVSyncService({
    required ConfigureService configureService,
    required HistoryService historyService,
  }) {
    _configureService = configureService;
    _historyService = historyService;
  }

  static Future<void> register(
    ConfigureService configureService,
    HistoryService historyService,
  ) async {
    final service = WebDAVSyncService(
      configureService: configureService,
      historyService: historyService,
    );
    await service._initialize();
    GetIt.I.registerSingleton<WebDAVSyncService>(service);
  }

  Future<void> _initialize() async {
    _updateWebDAVClient(
      _configureService.webDavURL.value,
      _configureService.webDavUsername.value,
      _configureService.webDavPassword.value,
    );
    effect(() {
      _updateWebDAVClient(
        _configureService.webDavURL.value,
        _configureService.webDavUsername.value,
        _configureService.webDavPassword.value,
      );
      _configureService.lastSyncTime.value = 0;
    });
    syncHistories();
  }

  void _updateWebDAVClient(String url, String username, String password) {
    if (url.isEmpty) {
      _client = null;
      return;
    }

    try {
      if (username.isEmpty || password.isEmpty) {
        _client = WebdavClient.noAuth(url: url);
      } else {
        _client = WebdavClient.basicAuth(
          url: url,
          user: username,
          pwd: password,
        );
      }
    } catch (e) {
      _log.error('_updateWebDAVClient', '创建WebDAV客户端失败', error: e);
      _client = null;
    }
  }

  Future<bool> testConnection() async {
    if (_client == null) {
      _log.warn('testConnection', 'WebDAV客户端未配置');
      syncMessage.value = 'WebDAV客户端未配置';
      return false;
    }

    try {
      syncMessage.value = '测试连接中...';
      await _client!.ping();
      await _client!.readDir('/');
      syncMessage.value = '连接测试成功';
      return true;
    } catch (e, stackTrace) {
      syncMessage.value = '连接测试失败: $e';
      _log.error(
        'testConnection',
        'WebDAV连接测试失败',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  bool get canSync {
    return _configureService.syncEnable.value && _client != null;
  }

  Future<void> syncHistories() async {
    if (!canSync) {
      _log.info('syncHistories', '同步功能未启用或配置不完整');
      syncMessage.value = '同步功能未启用或配置不完整';
      return;
    }
    _log.info('syncHistories', '开始执行数据库文件同步');

    if (_isSyncing) {
      _log.info('syncHistories', '同步正在进行中，跳过此次请求');
      return;
    }

    try {
      _isSyncing = true;
      syncMessage.value = '';
      syncStatus.value = SyncStatus.syncing;
      syncMessage.value = '开始同步数据库文件...';
      if (!await testConnection()) {
        syncStatus.value = SyncStatus.failed;
        syncMessage.value = '${syncMessage.value}\nWebDAV连接失败';
        return;
      }
      syncMessage.value = '${syncMessage.value}\n检查远程目录...';
      await _ensureRemoteDirectoryExists();
      syncMessage.value = '${syncMessage.value}\n下载远程时间戳...';
      final remoteTime = await _downloadRemoteTime();
      if (remoteTime == 0) {
        _configureService.lastSyncTime.value = 0;
      }
      syncMessage.value = '${syncMessage.value}\n同步历史记录...';
      var result = await _syncHistory(remoteTime);
      if (!result) {
        syncStatus.value = SyncStatus.failed;
        syncMessage.value = '${syncMessage.value}\n历史记录同步失败';
        return;
      }
      _uploadRemoteTime();
      syncStatus.value = SyncStatus.success;
      syncMessage.value = '数据库文件同步完成';
    } catch (e, stackTrace) {
      _log.error(
        'syncHistories',
        '数据库文件同步失败',
        error: e,
        stackTrace: stackTrace,
      );
      syncStatus.value = SyncStatus.failed;
      syncMessage.value = '${syncMessage.value}\n同步失败: $e';
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _ensureRemoteDirectoryExists() async {
    try {
      await _client!.readDir(_syncFolderPath);
    } catch (e) {
      try {
        await _client!.mkdir(_syncFolderPath);
      } catch (createError) {
        _log.warn(
          '_ensureRemoteDirectoryExists',
          '创建远程目录失败',
          error: createError,
        );
      }
    }
  }

  Future<int> _downloadRemoteTime() async {
    try {
      final manifestPath = '$_syncFolderPath/$_timeFileName';
      final fileContent = await _client!.read(manifestPath);
      return int.parse(utf8.decode(fileContent));
    } catch (e) {
      _log.warn('_downloadRemoteTime', '远程时间戳不存在');
      return 0;
    }
  }

  Future<void> _uploadRemoteTime() async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$_timeFileName');
    try {
      final updateTime = _configureService.lastSyncTime.value;
      await tempFile.writeAsString('$updateTime', encoding: utf8);
      final remotePath = '$_syncFolderPath/$_timeFileName';
      await _client!.writeFile(tempFile.path, remotePath);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<bool> _syncHistory(int remoteTime) async {
    try {
      final historyLock = _historyService.lock;
      return await historyLock.synchronized(() async {
        final dir = await getApplicationSupportDirectory();
        final localTime = _configureService.lastSyncTime.value;
        if (remoteTime > localTime) {
          // 远程更新，需要进行冲突合并
          _log.info('_syncSingleDatabaseFile', '检测到远程更新，开始合并');
          final mergeSuccess = await _mergeConflictedFile(localTime);
          if (!mergeSuccess) {
            _log.error('_syncSingleDatabaseFile', '冲突合并失败');
            return false;
          }
        }
        final localFile = File('${dir.path}/hive/history.hive');
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        await _historyService.beforeSync();
        await _uploadFile(localFile);
        _configureService.lastSyncTime.value = currentTime;
        return true;
      });
    } catch (e, stackTrace) {
      _log.error(
        '_syncSingleDatabaseFile',
        '同步文件失败',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _uploadFile(File localFile) async {
    try {
      final remoteFileName = 'history.hive';
      final remotePath = '$_syncFolderPath/$remoteFileName';
      await _client!.writeFile(localFile.path, remotePath);
      _log.info('_uploadDatabaseFile', '成功上传文件');
    } catch (e, stackTrace) {
      _log.error(
        '_uploadDatabaseFile',
        '上传文件失败',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 合并冲突
  Future<bool> _mergeConflictedFile(int lastSyncTime) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final remoteFile = File('${tempDir.path}/history_remote');
      try {
        final remotePath = '$_syncFolderPath/history.hive';
        final remoteContent = await _client!.read(remotePath);
        await remoteFile.writeAsBytes(remoteContent);
        await _historyService.merge(remoteFile, lastSyncTime);
        return true;
      } finally {
        if (await remoteFile.exists()) {
          await remoteFile.delete();
        }
      }
    } catch (e, stackTrace) {
      _log.error(
        '_mergeConflictedFile',
        '合并文件失败',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
