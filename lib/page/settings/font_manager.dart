import 'dart:io';

import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/theme/tile_style.dart';
import 'package:fldanplay/utils/dialog.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/widget/settings/settings_scaffold.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

class FontManagerPage extends StatefulWidget {
  const FontManagerPage({super.key});

  @override
  State<FontManagerPage> createState() => _FontManagerPageState();
}

class _FontManagerPageState extends State<FontManagerPage> {
  late final ConfigureService _configureService = GetIt.I
      .get<ConfigureService>();
  late final Directory fontsDir;
  List<String> _fontFiles = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    final appDir = await getApplicationSupportDirectory();
    fontsDir = Directory('${appDir.path}/fonts');
    if (!await fontsDir.exists()) {
      await fontsDir.create(recursive: true);
    }
    _loadFontFiles();
  }

  Future<void> _loadFontFiles() async {
    final files = await fontsDir.list().toList();
    final fontFiles = files.map((file) => file.uri.pathSegments.last).toList();
    setState(() {
      _fontFiles = fontFiles;
    });
  }

  Future<void> _importFont() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: .custom,
        allowedExtensions: ['ttf', 'otf', 'ttc'],
      );
      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;
        final sourceFile = File(sourcePath);
        final fileName = sourceFile.uri.pathSegments.last;
        final targetPath = '${fontsDir.path}/$fileName';
        await sourceFile.copy(targetPath);
        await _loadFontFiles();
        if (mounted) {
          showToast(context, title: '导入成功', description: '字体文件 $fileName 已导入');
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(context, level: 3, title: '导入失败', description: e.toString());
      }
    }
  }

  Future<void> _importDefaultFont() async {
    try {
      const fileName = 'MiSans-Regular.otf';
      final byteData = await rootBundle.load('assets/fonts/$fileName');
      final buffer = byteData.buffer;
      final targetFile = File('${fontsDir.path}/$fileName');
      await targetFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
      await _loadFontFiles();
      _configureService.subtitleFontName.value = 'MiSans-Regular';
      if (mounted) {
        showToast(context, title: '导入成功', description: '默认字体 MiSans 已导入并设置');
      }
    } catch (e) {
      if (mounted) {
        showToast(context, level: 3, title: '导入失败', description: e.toString());
      }
    }
  }

  Future<void> _deleteFont(String fileName) async {
    try {
      final fontFile = File('${fontsDir.path}/$fileName');
      if (await fontFile.exists()) {
        await fontFile.delete();
        await _loadFontFiles();
        if (mounted) {
          showToast(context, title: '删除成功', description: '字体文件 $fileName 已删除');
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(context, level: 3, title: '删除失败', description: e.toString());
      }
    }
  }

  void _showInputFontNameDialog() {
    final TextEditingController dialogController = TextEditingController();
    dialogController.text = _configureService.subtitleFontName.value;
    showFDialog(
      context: context,
      builder: (BuildContext context, style, animation) {
        return FDialog(
          direction: .horizontal,
          title: Text('输入字体名称'),
          animation: animation,
          body: FTextField(
            control: .managed(controller: dialogController),
            autofocus: true,
          ),
          actions: [
            FButton(
              onPress: () {
                _configureService.subtitleFontName.value = dialogController.text
                    .trim();
                Navigator.pop(context);
              },
              child: Text('保存'),
            ),
            FButton(
              variant: .outline,
              onPress: () => Navigator.pop(context),
              child: Text('取消'),
            ),
          ],
        );
      },
    ).then((_) {
      dialogController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '字体管理',
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Watch((context) {
            final currentFont = _configureService.subtitleFontName.value;
            return SettingsSection(
              children: [
                SettingsTile.simpleTile(
                  title: '当前字体',
                  subtitle: currentFont.isEmpty ? '系统默认' : currentFont,
                  onPress: _showInputFontNameDialog,
                ),
                SettingsTile.simpleTile(
                  title: '重置为系统默认字体',
                  subtitle: '点击重置为系统默认字体',
                  onPress: () {
                    _configureService.subtitleFontName.value = '';
                  },
                ),
              ],
            );
          }),
          if (_fontFiles.isNotEmpty)
            SettingsSection(
              title: '字体文件管理',
              children: _fontFiles.map((fileName) {
                return FTile(
                  style: tileStyle(
                    colors: context.theme.colors,
                    typography: context.theme.typography,
                    style: context.theme.style,
                  ),
                  title: Text(fileName),
                  suffix: Row(
                    mainAxisSize: .min,
                    children: [
                      FButton.icon(
                        onPress: () => showConfirmDialog(
                          context,
                          title: '删除字体文件',
                          content: '是否删除字体文件"$fileName"？',
                          onConfirm: () => _deleteFont(fileName),
                          confirmText: '删除',
                          destructive: true,
                        ),
                        variant: .ghost,
                        child: Icon(
                          FIcons.x,
                          color: context.theme.colors.destructive,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  onPress: () {
                    final fontNameWithoutExt = fileName.split('.').first;
                    _configureService.subtitleFontName.value =
                        fontNameWithoutExt;
                    showToast(
                      context,
                      title: '字体已选择',
                      description: fontNameWithoutExt,
                    );
                  },
                );
              }).toList(),
            ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            constraints: BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                if (_fontFiles.isEmpty) ...[
                  FButton(
                    onPress: _importDefaultFont,
                    child: const Text('导入MiSans字体'),
                  ),
                  const SizedBox(height: 8),
                ],
                FButton(onPress: _importFont, child: const Text('导入字体文件')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
