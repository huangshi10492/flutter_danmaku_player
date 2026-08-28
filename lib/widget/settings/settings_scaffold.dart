import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class SettingsScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool scrollView;
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.child,
    this.scrollView = true,
  });

  Widget _buildScrollableView() {
    var sChild = SafeArea(
      minimum: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: child,
        ),
      ),
    );
    if (scrollView) return SingleChildScrollView(child: sChild);
    return sChild;
  }

  @override
  Widget build(BuildContext context) {
    final contentFocusScope = FocusScopeNode();
    if (scrollView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (contentFocusScope.focusedChild != null) return;
        contentFocusScope.nextFocus();
      });
    }
    return Scaffold(
      appBar: SysAppBar(title: title),
      body: FocusScope(
        node: contentFocusScope,
        child: Padding(
          padding: context.theme.scaffoldStyle.childPadding,
          child: _buildScrollableView(),
        ),
      ),
    );
  }
}
