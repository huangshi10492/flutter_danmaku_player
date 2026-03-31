import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/utils/dialog.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/widget/settings/settings_scaffold.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final _maintenanceUtils = MaintenanceUtils();
  bool _isLoading = false;
  int _historyCount = 0;
  int _cleanDaysAgo = 90;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final historyCount = await _maintenanceUtils.getHistoryCount();
    if (mounted) {
      setState(() {
        _historyCount = historyCount;
      });
    }
  }

  Future<void> _backupConfigAndStorage() async {
    setState(() => _isLoading = true);
    try {
      final file = await _maintenanceUtils.backupConfigAndStorage();
      final path = await FilePicker.platform.saveFile(
        fileName:
            'fldanplay_config_${DateTime.now().millisecondsSinceEpoch}.zip',
        allowedExtensions: ['zip'],
        bytes: await file.readAsBytes(),
      );
      await file.delete();
      if (path == null) return;
      showToast(level: 1, title: '备份成功', description: '配置和媒体库已导出');
    } catch (e) {
      showToast(level: 3, title: '备份失败', description: e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreConfigAndStorage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;
    showConfirmDialog(
      context,
      title: '还原配置和媒体库',
      content: '还原操作将覆盖现有数据，请确保已备份当前数据。还原后需要重启应用。',
      onConfirm: () async {
        setState(() => _isLoading = true);
        try {
          final file = File(result.files.single.path!);
          await _maintenanceUtils.restoreConfigAndStorage(file);
          showToast(level: 2, title: '还原成功', description: '请重启应用以使配置生效');
        } catch (e) {
          showToast(level: 3, title: '还原失败', description: e.toString());
        } finally {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _cleanOldData() async {
    setState(() => _isLoading = true);
    try {
      final cleaned = await _maintenanceUtils.cleanOldHistories(_cleanDaysAgo);
      await _loadStats();
      showToast(level: 1, title: '清理完成', description: '已清理$cleaned条老旧历史记录');
    } catch (e) {
      showToast(level: 3, title: '清理失败', description: e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SettingsScaffold(
          title: '数据维护',
          child: Column(
            children: [
              SettingsSection(
                title: '数据统计',
                children: [
                  SettingsTile.simpleTile(
                    title: '历史记录',
                    details: '$_historyCount条',
                  ),
                ],
              ),
              SettingsSection(
                title: '配置备份还原',
                children: [
                  SettingsTile.simpleTile(
                    title: '备份配置和媒体库',
                    subtitle: '导出应用设置和媒体库配置',
                    onPress: _backupConfigAndStorage,
                  ),
                  SettingsTile.simpleTile(
                    title: '还原配置和媒体库',
                    subtitle: '从备份文件还原设置',
                    onPress: _restoreConfigAndStorage,
                  ),
                ],
              ),
              SettingsSection(
                title: '数据清理',
                children: [
                  SettingsTile.sliderTile(
                    title: '清理天数阈值',
                    subtitle: '清理多少天前的老旧数据',
                    details: '$_cleanDaysAgo 天',
                    silderValue: _cleanDaysAgo.toDouble(),
                    silderMin: 10,
                    silderMax: 360,
                    silderDivisions: 35,
                    onSilderChange: (value) {
                      setState(() => _cleanDaysAgo = value.round());
                    },
                  ),
                  SettingsTile.simpleTile(
                    title: '清理老旧历史记录',
                    subtitle: '删除老旧历史及关联的弹幕和缩略图',
                    onPress: () => showConfirmDialog(
                      context,
                      title: '清理老旧数据',
                      content:
                          '将清理$_cleanDaysAgo天前的历史记录及其关联的弹幕缓存和视频缩略图。此操作不可撤销。',
                      onConfirm: _cleanOldData,
                      confirmText: '清理',
                      destructive: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class MaintenanceUtils {
  final _logger = Logger('MaintenanceUtils');

  Future<Directory> get _appSupportDir async =>
      await getApplicationSupportDirectory();

  Future<int> getHistoryCount() async {
    final historyService = GetIt.I<HistoryService>();
    return historyService.listener.value.length;
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
}
