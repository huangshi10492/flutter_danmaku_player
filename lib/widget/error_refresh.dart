import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class ErrorRefresh extends StatelessWidget {
  final String error;
  final VoidCallback onRefresh;
  const ErrorRefresh({super.key, required this.error, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: .center,
        mainAxisSize: .min,
        children: [
          Text(error, style: context.theme.typography.md),
          const SizedBox(height: 16),
          FButton(
            onPress: onRefresh,
            mainAxisSize: .min,
            child: const Text('  重试  '),
          ),
        ],
      ),
    );
  }
}
