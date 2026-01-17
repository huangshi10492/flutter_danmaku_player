import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

/// 维护服务 - 处理应用数据的备份、还原和清理
class MaintenanceUtils {
  final _logger = Logger('MaintenanceUtils');

  Future<Directory> get _appSupportDir async =>
      await getApplicationSupportDirectory();

  Future<int> getHistoryCount() async {
    final historyService = GetIt.I<HistoryService>();
    return historyService.listener.value.length;
  }

  Future<int> getDanmakuCacheCount() async {
    final dir = await _appSupportDir;
    final danmakuDir = Directory('${dir.path}/danmaku');
    if (!await danmakuDir.exists()) return 0;
    final files = await danmakuDir.list().toList();
    return files.whereType<File>().length;
  }

  Future<int> getScreenshotCacheCount() async {
    final dir = await _appSupportDir;
    final screenshotDir = Directory('${dir.path}/screenshots');
    if (!await screenshotDir.exists()) return 0;
    final files = await screenshotDir.list().toList();
    return files.whereType<File>().length;
  }

  Future<File> backupConfigAndStorage() async {
    final configureService = GetIt.I<ConfigureService>();
    await configureService.beforeBackup();
    final storageService = GetIt.I<StorageService>();
    await storageService.beforeBackup();
    final dir = await _appSupportDir;
    final hiveDir = Directory('${dir.path}/hive');
    final archive = Archive();
    final configureFile = File('${hiveDir.path}/configure.hive');
    if (await configureFile.exists()) {
      final bytes = await configureFile.readAsBytes();
      archive.addFile(ArchiveFile('configure.hive', bytes.length, bytes));
    }
    final storageFile = File('${hiveDir.path}/storage.hive');
    if (await storageFile.exists()) {
      final bytes = await storageFile.readAsBytes();
      archive.addFile(ArchiveFile('storage.hive', bytes.length, bytes));
    }
    final zipData = ZipEncoder().encode(archive);
    final exportFile = File(
      '${dir.path}/fldanplay_config_${DateTime.now().millisecondsSinceEpoch}.zip',
    );
    await exportFile.writeAsBytes(zipData);
    _logger.info('backupConfigAndStorage', '备份完成: ${exportFile.path}');
    return exportFile;
  }

  Future<void> restoreConfigAndStorage(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dir = await _appSupportDir;
    final hiveDir = Directory('${dir.path}/hive');

    for (final file in archive) {
      if (file.isFile) {
        final outputFile = File('${hiveDir.path}/${file.name}');
        await outputFile.writeAsBytes(file.content as List<int>);
      }
    }
    _logger.info('restoreConfigAndStorage', '还原完成');
  }

  Future<List<History>> getOldHistories(int daysAgo) async {
    final historyService = GetIt.I<HistoryService>();
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: daysAgo))
        .millisecondsSinceEpoch;
    final histories = historyService.listener.value.values.toList();
    return histories.where((h) => h.updateTime < cutoffTime).toList();
  }

  Future<int> cleanOldHistories(int daysAgo) async {
    _logger.info('cleanOldHistories', '开始清理 $daysAgo 天前的历史记录');
    final historyService = GetIt.I<HistoryService>();
    final oldHistories = await getOldHistories(daysAgo);
    int cleanedCount = 0;
    for (final history in oldHistories) {
      await historyService.delete(history: history);
      cleanedCount++;
    }
    _logger.info('cleanOldHistories', '清理完成，共清理 $cleanedCount 条记录');
    return cleanedCount;
  }

  Future<int> cleanOrphanedDanmakuFiles() async {
    final historyService = GetIt.I<HistoryService>();
    final dir = await _appSupportDir;
    final danmakuDir = Directory('${dir.path}/danmaku');
    if (!await danmakuDir.exists()) return 0;
    int cleanedCount = 0;
    final historyKeys = historyService.listener.value.keys.toSet();
    await for (final file in danmakuDir.list()) {
      if (file is File) {
        final fileName = file.path.split('/').last;
        final uniqueKey = fileName.replaceAll('.json', '');
        if (!historyKeys.contains(uniqueKey)) {
          await file.delete();
          cleanedCount++;
        }
      }
    }
    _logger.info('cleanOrphanedDanmakuFiles', '清理完成，共清理 $cleanedCount 个文件');
    return cleanedCount;
  }

  Future<int> cleanOrphanedScreenshots() async {
    final historyService = GetIt.I<HistoryService>();
    final dir = await _appSupportDir;
    final screenshotDir = Directory('${dir.path}/screenshots');
    if (!await screenshotDir.exists()) return 0;
    int cleanedCount = 0;
    final historyKeys = historyService.listener.value.keys.toSet();
    await for (final file in screenshotDir.list()) {
      if (file is File) {
        final uniqueKey = file.path.split('/').last;
        if (!historyKeys.contains(uniqueKey)) {
          await file.delete();
          cleanedCount++;
        }
      }
    }
    _logger.info('cleanOrphanedScreenshots', '清理完成，共清理 $cleanedCount 个文件');
    return cleanedCount;
  }
}
