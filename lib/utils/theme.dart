import 'package:forui/forui.dart';

FThemeData getTheme(String theme, bool isDark) {
  final color = switch (theme) {
    'blue' => FThemes.blue,
    'neutral' => FThemes.neutral,
    'zinc' => FThemes.zinc,
    'slate' => FThemes.slate,
    'red' => FThemes.red,
    'rose' => FThemes.rose,
    'orange' => FThemes.orange,
    'green' => FThemes.green,
    'yellow' => FThemes.yellow,
    'violet' => FThemes.violet,
    _ => FThemes.blue,
  };
  FColors colors = isDark ? color.dark.touch.colors : color.light.touch.colors;
  final font = FTypeface.inherit(
    colors: colors,
    touch: true,
    fontFamily: 'MiSans',
  );
  return FThemeData(
    colors: colors,
    touch: false,
    typography: FTypography.inherit(
      colors: colors,
      touch: true,
    ).copyWith(body: font, display: font),
  );
}

FItemGroupStyleDelta get settingsItemGroupStyle => .delta(
  itemStyles: .delta([
    .all(
      .delta(
        contentStyle: .delta(
          titleTextStyle: .delta([.base(.delta(fontSize: 16, height: 1.5))]),
          prefixIconStyle: .delta([.base(.delta(size: 28))]),
          subtitleTextStyle: .delta([.base(.delta(fontSize: 12, height: 1))]),
        ),
      ),
    ),
  ]),
);
