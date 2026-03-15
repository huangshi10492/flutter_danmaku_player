import 'package:flutter/material.dart';

import 'package:forui/forui.dart';

FTileGroupStyle tileGroupStyle({
  required FColors colors,
  required FTypography typography,
  required FStyle style,
}) => .new(
  decoration: ShapeDecoration(
    shape: RoundedSuperellipseBorder(
      side: BorderSide(color: colors.border, width: style.borderWidth),
      borderRadius: style.borderRadius.md,
    ),
  ),
  dividerColor: .all(colors.border),
  dividerWidth: style.borderWidth,
  slideableTiles: const .all(true),
  labelTextStyle: FVariants.from(
    typography.sm.copyWith(
      color:
          style.formFieldStyle.labelTextStyle.base.color ?? colors.foreground,
      fontWeight: .w600,
    ),
    variants: {
      [.disabled]: .delta(color: colors.disable(colors.foreground)),
    },
  ),
  tileStyles: FVariants.from(
    _tileStyle(colors: colors, typography: typography, style: style).copyWith(
      backgroundColor: .delta([.all(Colors.transparent)]),
      decoration: .delta([
        .all(const .shapeDelta(shape: RoundedSuperellipseBorder())),
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
          suffixedPadding: FTileStyle.defaultSuffixedPadding,
          unsuffixedPadding: FTileStyle.defaultUnsuffixedPadding,
        ),
        rawItemContentStyle: _rawItemContentStyle(
          colors: colors,
          typography: typography,
          prefix: colors.destructive,
          color: colors.destructive,
          padding: FTileStyle.defaultUnsuffixedPadding,
        ),
      ),
    },
  ),
  descriptionTextStyle: style.formFieldStyle.descriptionTextStyle.apply([
    .all(
      .delta(fontSize: typography.xs2.fontSize, height: typography.xs2.height),
    ),
  ]),
  errorTextStyle: style.formFieldStyle.errorTextStyle.apply([
    .all(
      .delta(fontSize: typography.xs2.fontSize, height: typography.xs2.height),
    ),
  ]),
);

FTileStyle _tileStyle({
  required FColors colors,
  required FTypography typography,
  required FStyle style,
}) => FTileStyle(
  backgroundColor: .all(colors.card),
  decoration: FVariants.from(
    ShapeDecoration(
      shape: RoundedSuperellipseBorder(
        side: BorderSide(color: colors.border, width: style.borderWidth),
        borderRadius: style.borderRadius.md,
      ),
      color: colors.card,
    ),
    variants: {
      [.hovered, .pressed]: .shapeDelta(color: colors.secondary),
      [.disabled]: .shapeDelta(color: colors.disable(colors.secondary)),
    },
  ),
  contentStyle: _tileContentStyle(
    colors: colors,
    typography: typography,
    prefix: colors.primary,
    foreground: colors.foreground,
    mutedForeground: colors.mutedForeground,
  ),
  rawItemContentStyle: _rawTileContentStyle(
    colors: colors,
    typography: typography,
    prefix: colors.primary,
    color: colors.foreground,
  ),
  tappableStyle: style.tappableStyle.copyWith(
    motion: FTappableMotion.none,
    pressedEnterDuration: .zero,
    pressedExitDuration: const Duration(milliseconds: 25),
  ),
  focusedOutlineStyle: style.focusedOutlineStyle,
  shape: RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
  margin: .zero,
);

FTileContentStyle _tileContentStyle({
  required FColors colors,
  required FTypography typography,
  required Color prefix,
  required Color foreground,
  required Color mutedForeground,
}) {
  final disabledMutedForeground = colors.disable(mutedForeground);
  return FTileContentStyle(
    prefixIconStyle: FVariants.from(
      IconThemeData(color: prefix, size: typography.md.fontSize),
      variants: {
        [.disabled]: .delta(color: colors.disable(prefix)),
      },
    ),
    titleTextStyle: FVariants.from(
      typography.md.copyWith(color: foreground),
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
      IconThemeData(color: mutedForeground, size: typography.md.fontSize),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    suffixedPadding: FTileStyle.defaultSuffixedPadding,
    unsuffixedPadding: FTileStyle.defaultUnsuffixedPadding,
    prefixIconSpacing: 10,
    titleSpacing: 3,
    middleSpacing: 4,
    suffixIconSpacing: 5,
  );
}

FRawTileContentStyle _rawTileContentStyle({
  required FColors colors,
  required FTypography typography,
  required Color prefix,
  required Color color,
}) => FRawTileContentStyle(
  prefixIconStyle: FVariants.from(
    IconThemeData(color: prefix, size: typography.md.fontSize),
    variants: {
      [.disabled]: .delta(color: colors.disable(prefix)),
    },
  ),
  childTextStyle: FVariants.from(
    typography.sm.copyWith(color: color),
    variants: {
      [.disabled]: .delta(color: colors.disable(color)),
    },
  ),
  padding: FTileStyle.defaultUnsuffixedPadding,
  prefixIconSpacing: 10,
);

FItemContentStyle _itemContentStyle({
  required FColors colors,
  required FTypography typography,
  required Color prefix,
  required Color foreground,
  required Color mutedForeground,
  required EdgeInsetsGeometry suffixedPadding,
  required EdgeInsetsGeometry unsuffixedPadding,
}) {
  final disabledMutedForeground = colors.disable(mutedForeground);
  return FItemContentStyle(
    prefixIconStyle: .from(
      IconThemeData(color: prefix, size: typography.md.fontSize),
      variants: {
        [.disabled]: .delta(color: colors.disable(prefix)),
      },
    ),
    titleTextStyle: .from(
      typography.sm.copyWith(color: foreground),
      variants: {
        [.disabled]: .delta(color: colors.disable(foreground)),
      },
    ),
    subtitleTextStyle: .from(
      typography.xs2.copyWith(color: mutedForeground),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    detailsTextStyle: .from(
      typography.xs.copyWith(color: mutedForeground),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    suffixIconStyle: .from(
      IconThemeData(color: mutedForeground, size: typography.md.fontSize),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    suffixedPadding: suffixedPadding,
    unsuffixedPadding: unsuffixedPadding,
    prefixIconSpacing: 8,
    titleSpacing: 4,
    middleSpacing: 4,
    suffixIconSpacing: 8,
  );
}

FRawItemContentStyle _rawItemContentStyle({
  required FColors colors,
  required FTypography typography,
  required Color prefix,
  required Color color,
  required EdgeInsetsGeometry padding,
}) => FRawItemContentStyle(
  prefixIconStyle: .from(
    IconThemeData(color: prefix, size: typography.md.fontSize),
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
  padding: padding,
  prefixIconSpacing: 8,
);
