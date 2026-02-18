import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// [level] 0: none, 1: info, 2: warning, 3: error
void showToast(
  BuildContext context, {
  required String title,
  String? description,
  FToastAlignment alignment = FToastAlignment.topRight,
  int level = 0,
}) {
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
      icon = Icon(FIcons.circleX, size: 20, color: context.theme.colors.error);
      break;
  }
  showFToast(
    context: context,
    alignment: alignment,
    icon: icon,
    title: Text(
      title,
      style: context.theme.typography.base.copyWith(height: 1),
    ),
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
