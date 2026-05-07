import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const SysAppBar({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    List<Widget> acs = [];
    if (actions != null) {
      acs.addAll(actions!);
    }
    acs.add(const SizedBox(width: 8));
    return AppBar(
      scrolledUnderElevation: 0,
      title: Text(
        title,
        style: context.theme.typography.xl.copyWith(height: 1),
      ),
      actions: acs,
      leading: Navigator.canPop(context)
          ? IconButton(
              onPressed: () {
                Navigator.maybePop(context);
              },
              icon: Icon(FIcons.arrowLeft),
            )
          : null,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Theme.of(context).brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  @override
  Size get preferredSize {
    return Size.fromHeight(kToolbarHeight);
  }
}
