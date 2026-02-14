import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class IconSwitch extends StatelessWidget {
  final bool value;
  final VoidCallback onPress;
  final IconData icon;
  final String title;
  final String? subtitle;
  const IconSwitch({
    super.key,
    required this.value,
    required this.onPress,
    required this.icon,
    required this.title,
    this.subtitle,
  });
  @override
  Widget build(BuildContext context) {
    return FButton(
      onPress: onPress,
      variant: value ? null : .secondary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 4),
          SizedBox(
            child: Text(title, style: TextStyle(fontSize: 13), maxLines: 1),
          ),
          if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
