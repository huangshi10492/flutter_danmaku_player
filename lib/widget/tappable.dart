import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class Tappable extends StatelessWidget {
  final Widget child;
  final VoidCallback onPress;
  final double? width;
  final double? height;
  final bool isSelected;

  const Tappable({
    super.key,
    required this.child,
    required this.onPress,
    this.width,
    this.height,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return FTappable(
      focusedOutlineStyle: FFocusedOutlineStyle(
        color: context.theme.colors.primary,
        borderRadius: .all(.circular(8)),
        spacing: -1,
      ),
      builder: (context, states, child) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color:
              (states.contains(FTappableVariant.hovered) ||
                  states.contains(FTappableVariant.pressed) ||
                  isSelected)
              ? context.theme.colors.secondary
              : context.theme.colors.background,
          borderRadius: .circular(8),
        ),
        padding: .all(4),
        child: child!,
      ),
      onPress: onPress,
      child: child,
    );
  }
}
