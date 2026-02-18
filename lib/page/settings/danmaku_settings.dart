import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/theme/tile_style.dart';
import 'package:fldanplay/utils/dialog.dart';
import 'package:fldanplay/widget/settings/settings_scaffold.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DanmakuSettingsPage extends StatefulWidget {
  const DanmakuSettingsPage({super.key});

  @override
  State<DanmakuSettingsPage> createState() => _DanmakuSettingsPageState();
}

class _DanmakuSettingsPageState extends State<DanmakuSettingsPage> {
  final configure = GetIt.I<ConfigureService>();

  void _showServerDialog({int? index}) {
    final list = configure.danmakuServerList.value;
    final controller = TextEditingController(
      text: index != null ? list[index] : null,
    );
    showFDialog(
      context: context,
      builder: (context, style, animation) {
        return FDialog(
          style: style,
          direction: Axis.horizontal,
          animation: animation,
          title: Text('编辑服务器'),
          body: FTextField(
            control: .managed(controller: controller),
            hint: '输入服务器地址',
            autofocus: true,
          ),
          actions: [
            FButton(
              onPress: () {
                final url = controller.text.trim();
                if (url.isNotEmpty) {
                  final newList = List<String>.from(list);
                  if (index != null) {
                    newList[index] = url;
                  } else {
                    if (!newList.contains(url)) {
                      newList.add(url);
                    }
                  }
                  configure.danmakuServerList.value = newList;
                }
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
            FButton(
              variant: .outline,
              onPress: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  void _deleteServer(int index) {
    final list = List<String>.from(configure.danmakuServerList.value);
    list.removeAt(index);
    configure.danmakuServerList.value = list;
  }

  void _moveServerUp(int index) {
    if (index == 0) return;
    final list = List<String>.from(configure.danmakuServerList.value);
    final item = list.removeAt(index);
    list.insert(index - 1, item);
    configure.danmakuServerList.value = list;
  }

  void _moveServerDown(int index) {
    final list = configure.danmakuServerList.value;
    if (index >= list.length - 1) return;
    final newList = List<String>.from(list);
    final item = newList.removeAt(index);
    newList.insert(index + 1, item);
    configure.danmakuServerList.value = newList;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '弹幕设置',
      child: Watch((context) {
        final serverList = configure.danmakuServerList.value;
        return Column(
          children: [
            SettingsSection(
              children: [
                SettingsTile.switchTile(
                  title: '启用弹幕服务',
                  switchValue: configure.danmakuServiceEnable.value,
                  onBoolChange: (value) {
                    configure.danmakuServiceEnable.value = value;
                  },
                ),
                SettingsTile.switchTile(
                  title: '默认启用弹幕',
                  switchValue: configure.defaultDanmakuEnable.value,
                  onBoolChange: (value) {
                    configure.defaultDanmakuEnable.value = value;
                  },
                ),
              ],
            ),
            SettingsSection(
              title: '弹幕服务器列表',
              children: serverList.asMap().entries.map((entry) {
                final index = entry.key;
                final server = entry.value;
                return _buildServerItem(server, index, serverList.length);
              }).toList(),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              constraints: BoxConstraints(maxWidth: 1000),
              child: FButton(
                onPress: () => _showServerDialog(),
                child: const Text('添加服务器'),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildServerItem(String server, int index, int totalCount) {
    return FTile(
      style: tileStyle(
        colors: context.theme.colors,
        typography: context.theme.typography,
        style: context.theme.style,
      ),
      title: FTooltip(
        tipBuilder: (context, controller) => Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 50,
          ),
          child: Text(server),
        ),
        child: Text(server),
      ),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FButton.icon(
            onPress: () => _showServerDialog(index: index),
            variant: .ghost,
            child: const Icon(FIcons.pencil, size: 20),
          ),
          index == 0
              ? SizedBox.shrink()
              : FButton.icon(
                  onPress: () => _moveServerUp(index),
                  variant: .ghost,
                  child: const Icon(FIcons.chevronUp, size: 20),
                ),
          index >= totalCount - 1
              ? SizedBox.shrink()
              : FButton.icon(
                  onPress: () => _moveServerDown(index),
                  variant: .ghost,
                  child: const Icon(FIcons.chevronDown, size: 20),
                ),
          FButton.icon(
            onPress: () => showConfirmDialog(
              context,
              title: '删除服务器',
              content: '是否删除服务器"$server"？',
              onConfirm: () => _deleteServer(index),
              confirmText: '删除',
              destructive: true,
            ),
            variant: .ghost,
            child: Icon(
              FIcons.x,
              size: 20,
              color: context.theme.colors.destructive,
            ),
          ),
        ],
      ),
    );
  }
}
