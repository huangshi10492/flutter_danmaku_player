import 'dart:io';

import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class LogViewPage extends StatelessWidget {
  final String fileName;
  const LogViewPage({super.key, required this.fileName});
  Future<void> _exportLogFile(File file) async {
    final fileName = file.path.split('/').last;
    await FilePicker.platform.saveFile(
      fileName: fileName,
      allowedExtensions: ['log'],
      bytes: file.readAsBytesSync(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(fileName);
    return Scaffold(
      appBar: SysAppBar(
        title: '日志查看',
        actions: [
          IconButton(
            onPressed: () => _exportLogFile(file),
            icon: Icon(FIcons.upload),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: context.theme.scaffoldStyle.childPadding,
            child: SelectableText(file.readAsStringSync()),
          ),
        ),
      ),
    );
  }
}
