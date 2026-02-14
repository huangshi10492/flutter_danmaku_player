import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/webdav_sync.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/widget/settings/settings_scaffold.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  void _showInputDialog({
    required BuildContext context,
    required String title,
    required String currentValue,
    required Function(String) onSave,
    bool password = false,
  }) {
    showFDialog(
      context: context,
      builder: (context, style, animation) {
        final controller = TextEditingController(text: currentValue);
        return FDialog(
          style: style,
          direction: Axis.horizontal,
          animation: animation,
          title: Text(title),
          body: password
              ? FTextField.password(
                  control: .managed(controller: controller),
                  label: null,
                )
              : FTextField(control: .managed(controller: controller)),
          actions: [
            FButton(
              variant: .outline,
              onPress: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FButton(
              onPress: () {
                onSave(controller.text);
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// 测试WebDAV连接
  Future<void> _testConnection() async {
    try {
      final syncService = GetIt.I<WebDAVSyncService>();
      final success = await syncService.testConnection();

      if (mounted) {
        showToast(
          context,
          level: success ? 1 : 3,
          title: success ? '连接测试成功' : '连接测试失败',
        );
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          level: 3,
          title: '连接测试失败',
          description: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configure = GetIt.I<ConfigureService>();
    final sync = GetIt.I<WebDAVSyncService>();

    return SettingsScaffold(
      title: '同步设置',
      child: Column(
        children: [
          SettingsSection(
            children: [
              Watch((context) {
                return SettingsTile.switchTile(
                  title: '启用 WebDAV 同步',
                  switchValue: configure.syncEnable.value,
                  onBoolChange: (value) {
                    configure.syncEnable.value = value;
                  },
                );
              }),
            ],
          ),
          SettingsSection(
            title: '服务器信息',
            children: [
              Watch((context) {
                return SettingsTile.simpleTile(
                  title: 'Webdav地址',
                  subtitle: configure.webDavURL.value,
                  onPress: () {
                    _showInputDialog(
                      context: context,
                      title: 'Webdav地址',
                      currentValue: configure.webDavURL.value,
                      onSave: (value) => configure.webDavURL.value = value,
                    );
                  },
                );
              }),
              Watch((context) {
                return SettingsTile.simpleTile(
                  title: 'Webdav用户名',
                  subtitle: configure.webDavUsername.value,
                  onPress: () {
                    _showInputDialog(
                      context: context,
                      title: 'Webdav用户名',
                      currentValue: configure.webDavUsername.value,
                      onSave: (value) => configure.webDavUsername.value = value,
                    );
                  },
                );
              }),
              Watch((context) {
                return SettingsTile.simpleTile(
                  title: 'Webdav密码',
                  onPress: () {
                    _showInputDialog(
                      context: context,
                      title: 'Webdav密码',
                      password: true,
                      currentValue: configure.webDavPassword.value,
                      onSave: (value) => configure.webDavPassword.value = value,
                    );
                  },
                );
              }),
            ],
          ),
          SettingsSection(
            title: '同步操作',
            children: [
              SettingsTile.navigationTile(
                title: '测试连接',
                subtitle: '测试WebDAV服务器连接',
                onPress: _testConnection,
              ),
              SettingsTile.navigationTile(
                title: '立即同步',
                subtitle: '同步播放历史记录',
                onPress: sync.syncHistories,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            constraints: BoxConstraints(maxWidth: 1000),
            child: Watch((context) {
              return FAlert(
                title: Text(_getSyncStatusText(sync.syncStatus.value)),
                subtitle: Text(
                  sync.syncMessage.value ?? '准备同步...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 获取同步状态文本
  String _getSyncStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return '空闲';
      case SyncStatus.syncing:
        return '同步中...';
      case SyncStatus.success:
        return '同步成功';
      case SyncStatus.failed:
        return '同步失败';
    }
  }
}
