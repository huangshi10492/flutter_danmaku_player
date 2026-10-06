import 'package:fldanplay/model/storage2.dart';
import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class StorageService {
  late Box<StorageRecord> _storageBox;
  late final Signal<List<Storage2>> storages = signal([]);
  final _logger = Logger('StorageService');

  StorageService();
  static Future<StorageService> register() async {
    var service = StorageService();
    await service.init();
    GetIt.I.registerSingleton<StorageService>(service);
    return service;
  }

  Future<void> init() async {
    _storageBox = await Hive.openBox<StorageRecord>('storage2');
    getData();
    _storageBox.listenable().addListener(getData);
  }

  void getData() {
    final result = <Storage2>[];
    for (final record in _storageBox.values) {
      try {
        result.add(Storage2.fromRecord(record));
      } catch (error, stackTrace) {
        _logger.error(
          'decode',
          '读取媒体库失败: ${record.key}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    storages.value = result;
  }

  Storage2? get(String key) {
    _logger.info('get', '获取存储配置: $key');
    final record = _storageBox.get(key);
    if (record == null) return null;
    try {
      return Storage2.fromRecord(record);
    } catch (e, t) {
      _logger.error('get', '读取媒体库失败: $key', error: e, stackTrace: t);
      return null;
    }
  }

  Future<void> update(Storage2 storage) async {
    _logger.info('update', '更新存储配置: ${storage.name}');
    await _storageBox.put(storage.key, storage.toRecord());
  }

  bool exists(String key) {
    return _storageBox.containsKey(key);
  }

  Future<void> delete(String key) => _storageBox.delete(key);

  Future<void> beforeBackup() async {
    await _storageBox.flush();
    await _storageBox.compact();
    final legacyBox = await Hive.openBox<Storage>('storage');
    await legacyBox.flush();
    await legacyBox.compact();
  }

  Future<void> migrateLibraries() async {
    final storageBox = await Hive.openBox<StorageRecord>('storage2');
    final legacyBox = await Hive.openBox<Storage>('storage');
    final createdAt = DateTime.now();
    for (final legacy in legacyBox.values) {
      final key = legacy.uniqueKey;
      if (key.isEmpty || storageBox.containsKey(key)) continue;
      late final Storage2 storage;
      try {
        storage = Storage2.fromLegacy(legacy, createdAt: createdAt);
      } catch (error, stackTrace) {
        _logger.error(
          'migrateLibraries',
          '迁移媒体库失败: $key',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
      await storageBox.put(key, storage.toRecord());
    }
  }
}
