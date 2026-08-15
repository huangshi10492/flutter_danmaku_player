import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class SettingsScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const SettingsScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(title: title),
      body: Padding(
        padding: context.theme.scaffoldStyle.childPadding,
        child: SingleChildScrollView(
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: .topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1000),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
