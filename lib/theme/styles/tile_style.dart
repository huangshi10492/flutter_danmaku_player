import 'package:flutter/material.dart';

import 'package:forui/forui.dart';

FTileStyle tileStyle({
  required FColors colors,
  required FTypography typography,
  required FStyle style,
}) => FTileStyle(
  backgroundColor: .all(Colors.transparent),
  contentDecoration: FVariants.from(
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
  rawContentStyle: _rawTileContentStyle(
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
  focusedOutlineStyle: style.focusedOutlineStyle.copyWith(
    spacing: -style.borderWidth * 2,
  ),
  shape: RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
  padding: .zero,
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
      IconThemeData(color: prefix, size: typography.body.md.fontSize),
      variants: {
        [.disabled]: .delta(color: colors.disable(prefix)),
      },
    ),
    titleTextStyle: FVariants.from(
      typography.body.sm.copyWith(color: foreground),
      variants: {
        [.disabled]: .delta(color: colors.disable(foreground)),
      },
    ),
    subtitleTextStyle: FVariants.from(
      typography.body.xs2.copyWith(color: mutedForeground),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    detailsTextStyle: FVariants.from(
      typography.body.sm.copyWith(color: mutedForeground),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    suffixIconStyle: FVariants.from(
      IconThemeData(color: mutedForeground, size: typography.body.md.fontSize),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    suffixedPadding: const .symmetric(horizontal: 15, vertical: 8),
    unsuffixedPadding: const .symmetric(horizontal: 15, vertical: 8),
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
    IconThemeData(color: prefix, size: typography.body.md.fontSize),
    variants: {
      [.disabled]: .delta(color: colors.disable(prefix)),
    },
  ),
  childTextStyle: FVariants.from(
    typography.body.sm.copyWith(color: color),
    variants: {
      [.disabled]: .delta(color: colors.disable(color)),
    },
  ),
  padding: const .symmetric(horizontal: 15, vertical: 8),
  prefixIconSpacing: 10,
);
