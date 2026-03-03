import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/theme/tile_style.dart';
import 'package:fldanplay/utils/dialog.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DanmakuKeywordFilter extends StatefulWidget {
  const DanmakuKeywordFilter({super.key});

  @override
  State<DanmakuKeywordFilter> createState() => _DanmakuKeywordFilterState();
}

class _DanmakuKeywordFilterState extends State<DanmakuKeywordFilter> {
  final configure = GetIt.I<ConfigureService>();

  void _showKeywordDialog() {
    final controller = TextEditingController();
    showFDialog(
      context: context,
      builder: (context, style, animation) {
        final formKey = GlobalKey<FormState>();
        return FDialog(
          style: style,
          direction: .horizontal,
          animation: animation,
          title: Text('编辑关键词'),
          body: Form(
            key: formKey,
            child: FTextFormField(
              control: .managed(controller: controller),
              hint: '以"/"开头和结尾将视作正则表达式',
              validator: _validateKeyword,
              autofocus: true,
            ),
          ),
          actions: [
            FButton(
              onPress: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                final keyword = controller.text.trim();
                _addKeyword(keyword);
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

  // validate keyword
  String? _validateKeyword(String? keyword) {
    if (keyword == null || keyword.trim().isEmpty) {
      return '关键词不能为空';
    }
    if (keyword.length > 32) {
      return '关键词过长';
    }
    if (configure.danmakuFilterKeywords.value.contains(keyword)) {
      return '关键词已存在';
    }
    return null;
  }

  void _addKeyword(String keyword) {
    final list = configure.danmakuFilterKeywords.value;
    configure.danmakuFilterKeywords.value = [...list, keyword];
  }

  void _deleteKeyword(String keyword) {
    final list = List<String>.from(configure.danmakuFilterKeywords.value);
    list.remove(keyword);
    configure.danmakuFilterKeywords.value = list;
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final keywordList = configure.danmakuFilterKeywords.value;
      return Column(
        children: [
          _buildKeywordSection(keywordList),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            constraints: BoxConstraints(maxWidth: 1000),
            child: FButton(
              onPress: () => _showKeywordDialog(),
              child: const Text('添加关键词'),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildKeywordSection(List<String> keywordList) {
    if (keywordList.isEmpty) {
      return SettingsSection(
        children: [SettingsTile.simpleTile(title: '暂无关键词')],
      );
    }
    return SettingsSection(
      children: keywordList.asMap().entries.map((entry) {
        final index = entry.key;
        final keyword = entry.value;
        return _buildKeywordItem(keyword, index);
      }).toList(),
    );
  }

  Widget _buildKeywordItem(String keyword, int index) {
    return FTile(
      style: tileStyle(
        colors: context.theme.colors,
        typography: context.theme.typography,
        style: context.theme.style,
      ),
      title: Text(keyword),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FButton.icon(
            onPress: () => showConfirmDialog(
              context,
              title: '删除关键词',
              content: '是否删除关键词"$keyword"？',
              onConfirm: () => _deleteKeyword(keyword),
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
