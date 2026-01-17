import 'package:fldanplay/utils/log.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../model/storage.dart';

class StorageService {
  late Box<Storage> _storageBox;
  late final Signal<List<Storage>> storages = signal([]);
  final _logger = Logger('StorageService');

  StorageService();
  static Future<StorageService> register() async {
    var service = StorageService();
    await service.init();
    GetIt.I.registerSingleton<StorageService>(service);
    return service;
  }

  Future<void> init() async {
    _storageBox = await Hive.openBox<Storage>('storage');
    storages.value = _storageBox.values.toList();
    final listener = _storageBox.listenable();
    listener.addListener(() {
      storages.value = _storageBox.values.toList();
    });
  }

  Storage? get(String key) {
    _logger.info('get', '获取存储配置: $key');
    return _storageBox.get(key);
  }

  Future<void> update(Storage storage) async {
    _logger.info('update', '更新存储配置: ${storage.name}');
    if (storage.key == null) {
      _storageBox.put(storage.uniqueKey, storage);
    } else {
      _storageBox.put(storage.key, storage);
    }
  }

  bool exists(String key) {
    return _storageBox.containsKey(key);
  }

  Future<void> beforeBackup() async {
    await _storageBox.flush();
    await _storageBox.compact();
  }
}
