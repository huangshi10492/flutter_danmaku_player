import 'package:fldanplay/service/global.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';

/// [level] 0: none, 1: info, 2: warning, 3: error
void showToast({
  required String title,
  String? description,
  FToastAlignment alignment = FToastAlignment.topRight,
  int level = 0,
}) {
  final ctx = GetIt.I.get<GlobalService>().appContext;
  Widget? icon;
  switch (level) {
    case 1:
      icon = const Icon(FIcons.info, size: 22);
      break;
    case 2:
      icon = const Icon(
        FIcons.triangleAlert,
        size: 22,
        color: Color.fromARGB(255, 234, 178, 8),
      );
      break;
    case 3:
      icon = Icon(FIcons.circleX, size: 20, color: ctx.theme.colors.error);
      break;
  }
  showFToast(
    context: ctx,
    alignment: alignment,
    icon: icon,
    title: Text(title, style: ctx.theme.typography.md.copyWith(height: 1)),
    description: description != null ? Text(description) : null,
    suffixBuilder: (context, entry) => IntrinsicHeight(
      child: FButton.icon(
        variant: .ghost,
        onPress: entry.dismiss,
        child: const Icon(FIcons.x),
      ),
    ),
  );
}
