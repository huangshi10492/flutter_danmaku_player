import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 1000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
              child: Text(
                title!,
                style: context.theme.typography.sm.copyWith(
                  color: colors.mutedForeground,
                ),
                textAlign: TextAlign.start,
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: colors.secondary.withAlpha(100),
              border: Border.all(
                color: colors.border,
                width: context.theme.style.borderWidth,
              ),
              borderRadius: context.theme.style.borderRadius,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: children.length * 2 - 1,
              itemBuilder: (context, index) {
                if (index % 2 == 0) {
                  return children[index ~/ 2];
                } else {
                  return FDivider(
                    style: .delta(
                      color: colors.border,
                      padding: .symmetric(vertical: 0, horizontal: 16),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
