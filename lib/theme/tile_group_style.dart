import 'package:flutter/material.dart';

import 'package:forui/forui.dart';

FTileGroupStyle tileGroupStyle({
  required FColors colors,
  required FTypography typography,
  required FStyle style,
}) => .new(
  decoration: BoxDecoration(
    border: .all(color: colors.border, width: style.borderWidth),
    borderRadius: style.borderRadius,
    color: colors.secondary.withAlpha(100),
  ),
  dividerColor: .all(colors.border),
  dividerWidth: style.borderWidth,
  labelTextStyle: FVariants.from(
    typography.base.copyWith(
      color:
          style.formFieldStyle.labelTextStyle.base.color ?? colors.foreground,
      fontWeight: .w600,
    ),
    variants: {
      [.disabled]: .delta(color: colors.disable(colors.foreground)),
    },
  ),
  tileStyles: FVariants.from(
    .inherit(colors: colors, typography: typography, style: style).copyWith(
      backgroundColor: .delta([.all(Colors.transparent)]),
      decoration: .delta([
        .all(const .delta(border: null, borderRadius: null)),
        .base(.delta(color: Colors.transparent)),
      ]),
    ),
    variants: {
      [.destructive]: .delta(
        contentStyle: _itemContentStyle(
          colors: colors,
          typography: typography,
          prefix: colors.destructive,
          foreground: colors.destructive,
          mutedForeground: colors.destructive,
        ),
        rawItemContentStyle: _rawItemContentStyle(
          colors: colors,
          typography: typography,
          prefix: colors.destructive,
          color: colors.destructive,
        ),
      ),
    },
  ),
  descriptionTextStyle: style.formFieldStyle.descriptionTextStyle.apply([
    .all(
      .delta(fontSize: typography.xs.fontSize, height: typography.xs.height),
    ),
  ]),
  errorTextStyle: style.formFieldStyle.errorTextStyle.apply([
    .all(
      .delta(
        fontSize: typography.xs.fontSize,
        height: typography.xs.height,
        fontWeight: .w400,
      ),
    ),
  ]),
);

FItemContentStyle _itemContentStyle({
  required FColors colors,
  required FTypography typography,
  required Color prefix,
  required Color foreground,
  required Color mutedForeground,
}) {
  final disabledMutedForeground = colors.disable(mutedForeground);
  return FItemContentStyle(
    prefixIconStyle: FVariants.from(
      IconThemeData(color: prefix, size: 15),
      variants: {
        [.disabled]: .delta(color: colors.disable(prefix)),
      },
    ),
    titleTextStyle: FVariants.from(
      typography.sm.copyWith(color: foreground),
      variants: {
        [.disabled]: .delta(color: colors.disable(foreground)),
      },
    ),
    subtitleTextStyle: FVariants.from(
      typography.xs.copyWith(color: mutedForeground),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    detailsTextStyle: FVariants.from(
      typography.xs.copyWith(color: mutedForeground),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    suffixIconStyle: FVariants.from(
      IconThemeData(color: mutedForeground, size: 15),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    padding: const .directional(start: 11, top: 7.5, bottom: 7.5, end: 6),
    prefixIconSpacing: 10,
    titleSpacing: 3,
    middleSpacing: 4,
    suffixIconSpacing: 5,
  );
}

FRawItemContentStyle _rawItemContentStyle({
  required FColors colors,
  required FTypography typography,
  required Color prefix,
  required Color color,
}) => FRawItemContentStyle(
  prefixIconStyle: FVariants.from(
    IconThemeData(color: prefix, size: 15),
    variants: {
      [.disabled]: .delta(color: colors.disable(prefix)),
    },
  ),
  childTextStyle: FVariants(
    typography.sm.copyWith(color: color),
    variants: {
      [.disabled]: typography.sm.copyWith(color: colors.disable(color)),
    },
  ),
  padding: const .directional(start: 15, top: 7.5, bottom: 7.5, end: 10),
  prefixIconSpacing: 10,
);
