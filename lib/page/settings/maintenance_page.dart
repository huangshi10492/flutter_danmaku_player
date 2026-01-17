import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fldanplay/utils/maintenance.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/widget/settings/settings_scaffold.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final _maintenanceUtils = MaintenanceUtils();
  bool _isLoading = false;
  int _historyCount = 0;
  int _danmakuCount = 0;
  int _screenshotCount = 0;
  int _cleanDaysAgo = 90;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final historyCount = await _maintenanceUtils.getHistoryCount();
    final danmakuCount = await _maintenanceUtils.getDanmakuCacheCount();
    final screenshotCount = await _maintenanceUtils.getScreenshotCacheCount();
    if (mounted) {
      setState(() {
        _historyCount = historyCount;
        _danmakuCount = danmakuCount;
        _screenshotCount = screenshotCount;
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
      if (mounted) {
        showToast(context, level: 1, title: '备份成功', description: '配置和媒体库已导出');
      }
    } catch (e) {
      if (mounted) {
        showToast(context, level: 3, title: '备份失败', description: e.toString());
      }
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
    _showRestoreConfirmDialog('还原配置和媒体库', () async {
      setState(() => _isLoading = true);
      try {
        final file = File(result.files.single.path!);
        await _maintenanceUtils.restoreConfigAndStorage(file);
        if (mounted) {
          showToast(
            context,
            level: 2,
            title: '还原成功',
            description: '请重启应用以使配置生效',
          );
        }
      } catch (e) {
        if (mounted) {
          showToast(
            context,
            level: 3,
            title: '还原失败',
            description: e.toString(),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    });
  }

  void _showRestoreConfirmDialog(String title, VoidCallback onConfirm) {
    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        style: style.call,
        animation: animation,
        title: Text(title),
        body: const Text('还原操作将覆盖现有数据，请确保已备份当前数据。还原后需要重启应用。'),
        actions: [
          FButton(
            onPress: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FButton(
            style: FButtonStyle.destructive(),
            onPress: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('确认还原'),
          ),
        ],
      ),
    );
  }

  void _showCleanConfirmDialog() {
    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        style: style.call,
        animation: animation,
        title: const Text('清理老旧数据'),
        body: Text('将清理$_cleanDaysAgo天前的历史记录及其关联的弹幕缓存和视频缩略图。此操作不可撤销。'),
        actions: [
          FButton(
            onPress: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FButton(
            style: FButtonStyle.destructive(),
            onPress: () {
              Navigator.pop(context);
              _cleanOldData();
            },
            child: const Text('确认清理'),
          ),
        ],
      ),
    );
  }

  Future<void> _cleanOldData() async {
    setState(() => _isLoading = true);
    try {
      final cleaned = await _maintenanceUtils.cleanOldHistories(_cleanDaysAgo);
      await _loadStats();
      if (mounted) {
        showToast(
          context,
          level: 1,
          title: '清理完成',
          description: '已清理$cleaned条老旧历史记录',
        );
      }
    } catch (e) {
      if (mounted) {
        showToast(context, level: 3, title: '清理失败', description: e.toString());
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cleanOrphanedFiles() async {
    setState(() => _isLoading = true);
    try {
      final danmakuCleaned = await _maintenanceUtils
          .cleanOrphanedDanmakuFiles();
      final screenshotCleaned = await _maintenanceUtils
          .cleanOrphanedScreenshots();
      await _loadStats();
      if (mounted) {
        showToast(
          context,
          level: 1,
          title: '清理完成',
          description: '已清理$danmakuCleaned个弹幕文件和$screenshotCleaned个缩略图',
        );
      }
    } catch (e) {
      if (mounted) {
        showToast(context, level: 3, title: '清理失败', description: e.toString());
      }
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
                  SettingsTile.simpleTile(
                    title: '弹幕缓存',
                    details: '$_danmakuCount个',
                  ),
                  SettingsTile.simpleTile(
                    title: '视频缩略图',
                    details: '$_screenshotCount个',
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
                    onPress: _showCleanConfirmDialog,
                  ),
                  SettingsTile.simpleTile(
                    title: '清理孤立缓存文件',
                    subtitle: '删除无关联历史记录的弹幕和缩略图',
                    onPress: _cleanOrphanedFiles,
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
