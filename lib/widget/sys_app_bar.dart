import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const SysAppBar({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    List<Widget> acs = [];
    if (actions != null) {
      acs.addAll(actions!);
    }
    acs.add(const SizedBox(width: 8));
    final brightnessReverse = colorScheme.brightness == .light
        ? Brightness.dark
        : Brightness.light;
    return AppBar(
      scrolledUnderElevation: 0,
      title: Text(
        title,
        style: context.theme.typography.body.xl.copyWith(height: 1),
      ),
      actions: acs,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: colorScheme.brightness,
        statusBarIconBrightness: brightnessReverse,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: brightnessReverse,
      ),
    );
  }

  @override
  Size get preferredSize {
    return Size.fromHeight(kToolbarHeight);
  }
}
