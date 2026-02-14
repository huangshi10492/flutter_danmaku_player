import 'package:fldanplay/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

FTextFieldStyleDelta textFieldStyle(FColors colors) {
  return .delta(
    labelTextStyle: .delta([.base(.delta(fontWeight: FontWeight.normal))]),
  );
}

FThemeData getTheme(String theme, bool isDark) {
  late FColors colors;
  if (isDark) {
    switch (theme) {
      case 'blue':
        colors = FThemes.blue.dark.colors;
      case 'neutral':
        colors = FThemes.neutral.dark.colors;
      case 'zinc':
        colors = FThemes.zinc.dark.colors;
      case 'slate':
        colors = FThemes.slate.dark.colors;
      case 'red':
        colors = FThemes.red.dark.colors;
      case 'rose':
        colors = FThemes.rose.dark.colors;
      case 'orange':
        colors = FThemes.orange.dark.colors;
      case 'green':
        colors = FThemes.green.dark.colors;
      case 'yellow':
        colors = FThemes.yellow.dark.colors;
      case 'violet':
        colors = FThemes.violet.dark.colors;
      default:
        colors = FThemes.blue.dark.colors;
    }
  } else {
    switch (theme) {
      case 'blue':
        colors = FThemes.blue.light.colors;
      case 'neutral':
        colors = FThemes.neutral.light.colors;
      case 'zinc':
        colors = FThemes.zinc.light.colors;
      case 'slate':
        colors = FThemes.slate.light.colors;
      case 'red':
        colors = FThemes.red.light.colors;
      case 'rose':
        colors = FThemes.rose.light.colors;
      case 'orange':
        colors = FThemes.orange.light.colors;
      case 'green':
        colors = FThemes.green.light.colors;
      case 'yellow':
        colors = FThemes.yellow.light.colors;
      case 'violet':
        colors = FThemes.violet.light.colors;
      default:
        colors = FThemes.blue.light.colors;
    }
  }
  return FThemeData(
    colors: colors,
    typography: FTypography.inherit(
      colors: colors,
      defaultFontFamily: Utils.font('packages/forui/Inter')!,
    ),
  ).copyWith(textFieldStyle: textFieldStyle(colors));
}

FItemGroupStyleDelta get rootItemGroupStyle => .delta(
  itemStyles: .delta([
    .base(
      .delta(
        contentStyle: .delta(
          titleTextStyle: .delta([.base(.delta(fontSize: 18, height: 1.75))]),
          prefixIconStyle: .delta([.base(.delta(size: 32))]),
        ),
      ),
    ),
  ]),
);

FItemGroupStyleDelta get settingsItemGroupStyle => .delta(
  itemStyles: .delta([
    .base(
      .delta(
        contentStyle: .delta(
          titleTextStyle: .delta([.base(.delta(fontSize: 16, height: 1.5))]),
          prefixIconStyle: .delta([.base(.delta(size: 28))]),
        ),
      ),
    ),
  ]),
);
