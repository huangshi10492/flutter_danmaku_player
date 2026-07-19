import 'package:fldanplay/theme/colors.dart';
import 'package:forui/forui.dart';

FThemeData getTheme(String theme, bool isDark, {bool touchUI = false}) {
  final color = AppColors.values.lastWhere(
    (element) => element.tag == theme,
    orElse: () => .blue,
  );
  FColors colors = isDark ? color.dark : color.light;
  final typeface = FTypeface.inherit(
    colors: colors,
    touch: true,
    fontFamily: 'MiSans',
  );
  return FThemeData(
    colors: colors,
    touch: touchUI,
    typography: FTypography(display: typeface, body: typeface),
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
