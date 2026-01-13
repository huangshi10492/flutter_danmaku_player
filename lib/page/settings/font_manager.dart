import 'dart:io';

import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/theme/tile_style.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/widget/settings/settings_scaffold.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  void _showDeleteConfirmDialog(String fileName) {
    showFDialog(
      context: context,
      builder: (BuildContext context, style, animation) {
        return FDialog(
          direction: .horizontal,
          title: Text('确认删除'),
          animation: animation,
          body: Text('确定要删除字体文件 $fileName 吗？'),
          actions: [
            FButton(
              style: FButtonStyle.outline(),
              onPress: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            FButton(
              style: FButtonStyle.destructive(),
              onPress: () {
                Navigator.pop(context);
                _deleteFont(fileName);
              },
              child: Text('删除'),
            ),
          ],
        );
      },
    );
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
          body: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              SizedBox(height: 12),
              FTextField(
                control: .managed(controller: dialogController),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            FButton(
              style: FButtonStyle.outline(),
              onPress: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            FButton(
              onPress: () {
                _configureService.subtitleFontName.value = dialogController.text
                    .trim();
                Navigator.pop(context);
              },
              child: Text('保存'),
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
              title: '字幕字体',
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
                  ).call,
                  title: Text(fileName),
                  suffix: Row(
                    mainAxisSize: .min,
                    children: [
                      FButton.icon(
                        onPress: () => _showDeleteConfirmDialog(fileName),
                        style: FButtonStyle.ghost(),
                        child: const Icon(FIcons.x, color: Colors.red),
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
            child: FButton(onPress: _importFont, child: const Text('导入字体文件')),
          ),
          if (_fontFiles.isEmpty)
            RichText(
              text: TextSpan(
                style: context.theme.typography.base,
                children: <TextSpan>[
                  TextSpan(text: '推荐使用'),
                  TextSpan(
                    text: 'Noto Sans CJK SC',
                    style: TextStyle(
                      color: context.theme.colors.primary,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(
                          Uri.parse(
                            'https://fastly.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf',
                          ),
                        );
                        _configureService.subtitleFontName.value =
                            'NotoSansCJKsc-Regular';
                      },
                  ),
                  TextSpan(text: '字体，点击下载字体文件后手动导入。'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
