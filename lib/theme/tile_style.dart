import 'package:flutter/material.dart';

import 'package:forui/forui.dart';

FTileStyle tileStyle({
  required FColors colors,
  required FTypography typography,
  required FStyle style,
}) => FTileStyle(
  backgroundColor: .all(Colors.transparent),
  decoration: FVariants.from(
    ShapeDecoration(
      shape: RoundedSuperellipseBorder(
        side: BorderSide(color: Colors.transparent, width: style.borderWidth),
        borderRadius: style.borderRadius.md,
      ),
      color: Colors.transparent,
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
      IconThemeData(color: prefix, size: typography.lg.fontSize),
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
      typography.md.copyWith(color: mutedForeground),
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
    typography.md.copyWith(color: color),
    variants: {
      [.disabled]: .delta(color: colors.disable(color)),
    },
  ),
  padding: FTileStyle.defaultUnsuffixedPadding,
  prefixIconSpacing: 10,
);
