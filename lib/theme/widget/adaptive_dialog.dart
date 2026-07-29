import 'package:flutter/widgets.dart';

import 'package:forui/forui.dart';

class AdaptiveDialog extends StatelessWidget {
  final FDialogStyleDelta style;
  final Animation<double>? animation;
  final Widget title;
  final Widget body;
  final List<Widget> actions;

  const AdaptiveDialog({
    required this.title,
    required this.body,
    required this.actions,
    this.style = const .context(),
    this.animation,
    super.key,
  });

  @override
  Widget build(BuildContext context) => FDialog.adaptive(
    style: style,
    animation: animation,
    constraints: const BoxConstraints(minWidth: 10, maxWidth: 560),
    horizontalBuilder: (context, style) {
      return Padding(
        padding: const .symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            Padding(
              padding: const .only(bottom: 5),
              child: DefaultTextStyle.merge(
                style: style.titleTextStyle,
                child: title,
              ),
            ),
            Flexible(
              child: Padding(
                padding: .only(bottom: actions.isEmpty ? 0 : 16),
                child: DefaultTextStyle.merge(
                  style: style.bodyTextStyle,
                  child: body,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: .end,
              spacing: 8,
              children: [for (final action in actions) Expanded(child: action)],
            ),
          ],
        ),
      );
    },
    verticalBuilder: (context, style) {
      return Padding(
        padding: const .symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            Padding(
              padding: const .only(left: 8, right: 8, bottom: 5),
              child: DefaultTextStyle.merge(
                style: style.titleTextStyle,
                child: title,
              ),
            ),
            Flexible(
              child: Padding(
                padding: .only(
                  left: 8,
                  right: 8,
                  bottom: actions.isEmpty ? 0 : 16,
                ),
                child: DefaultTextStyle.merge(
                  style: style.bodyTextStyle,
                  child: body,
                ),
              ),
            ),
            Column(mainAxisSize: .min, spacing: 8, children: actions),
          ],
        ),
      );
    },
  );
}
