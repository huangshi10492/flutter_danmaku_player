import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/widget/settings/settings_scaffold.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

const Map<String, String> _themeColorNames = {
  'blue': 'Blue',
  'neutral': 'Neutral',
  'zinc': 'Zinc',
  'slate': 'Slate',
  'red': 'Red',
  'rose': 'Rose',
  'orange': 'Orange',
  'green': 'Green',
  'yellow': 'Yellow',
  'violet': 'Violet',
};

Color _getThemeColor(String themeKey, bool isDark) {
  final theme = switch (themeKey) {
    'blue' => FThemes.blue,
    'neutral' => FThemes.neutral,
    'zinc' => FThemes.zinc,
    'slate' => FThemes.slate,
    'red' => FThemes.red,
    'rose' => FThemes.rose,
    'orange' => FThemes.orange,
    'green' => FThemes.green,
    'yellow' => FThemes.yellow,
    'violet' => FThemes.violet,
    _ => FThemes.blue,
  };
  return isDark ? theme.dark.colors.primary : theme.light.colors.primary;
}

class GeneralSettingsPage extends StatelessWidget {
  const GeneralSettingsPage({super.key});

  void _showThemeColorDialog(BuildContext context, ConfigureService configure) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showFDialog(
      context: context,
      builder: (context, style, animation) {
        return FDialog(
          style: style,
          direction: .vertical,
          animation: animation,
          title: const Text('选择主题颜色'),
          body: SingleChildScrollView(
            child: Wrap(
              alignment: .center,
              spacing: 8,
              runSpacing: 4,
              children: _themeColorNames.entries.map((entry) {
                final isSelected = configure.themeColor.value == entry.key;
                final themeColor = _getThemeColor(entry.key, isDark);
                return GestureDetector(
                  onTap: () {
                    configure.themeColor.value = entry.key;
                  },
                  child: Container(
                    width: 70,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? themeColor.withValues(alpha: 0.1)
                          : null,
                      borderRadius: .circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: .center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: themeColor,
                            shape: .circle,
                          ),
                          child: null,
                        ),
                        const SizedBox(height: 6),
                        Text(entry.value),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            FButton(
              variant: .outline,
              onPress: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  String _getThemeColorName(String colorKey) {
    return _themeColorNames[colorKey] ?? 'Blue';
  }

  @override
  Widget build(BuildContext context) {
    final configure = GetIt.I<ConfigureService>();
    return SettingsScaffold(
      title: '通用设置',
      child: Watch((context) {
        return Column(
          children: [
            SettingsSection(
              title: '主题',
              children: [
                SettingsTile.radioTile(
                  title: '主题模式',
                  radioValue: configure.themeMode.value,
                  onRadioChange: (value) {
                    configure.themeMode.value = value;
                  },
                  radioOptions: {'跟随系统': '0', '浅色模式': '1', '深色模式': '2'},
                ),
                SettingsTile.navigationTile(
                  title: '主题颜色',
                  details: _getThemeColorName(configure.themeColor.value),
                  onPress: () => _showThemeColorDialog(context, configure),
                ),
              ],
            ),
            SettingsSection(
              title: '缓存',
              children: [
                SettingsTile.switchTile(
                  title: '优先使用离线缓存',
                  subtitle: '开启后，优先使用离线缓存播放视频',
                  switchValue: configure.offlineCacheFirst.value,
                  onBoolChange: (value) {
                    configure.offlineCacheFirst.value = value;
                  },
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
