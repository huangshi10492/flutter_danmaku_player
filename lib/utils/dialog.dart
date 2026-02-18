import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

void showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  required VoidCallback onConfirm,
  String confirmText = '确认',
  bool destructive = false,
}) {
  showFDialog(
    context: context,
    builder: (context, style, animation) => FDialog(
      style: style,
      animation: animation,
      title: Text(title),
      body: Text(content),
      actions: [
        FButton(
          variant: destructive ? .destructive : null,
          onPress: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(confirmText),
        ),
        FButton(
          variant: .outline,
          onPress: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}
