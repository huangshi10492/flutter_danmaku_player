import 'package:flutter/material.dart';

import 'package:forui/forui.dart';

FTileStyle tileStyle({
  required FColors colors,
  required FTypography typography,
  required FStyle style,
}) => FTileStyle(
  backgroundColor: .all(Colors.transparent),
  decoration: FVariants.from(
    BoxDecoration(color: Colors.transparent, borderRadius: style.borderRadius),
    variants: {
      [.hovered, .pressed]: .delta(color: colors.secondary),
      [.disabled]: .delta(color: colors.disable(colors.secondary)),
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
      IconThemeData(color: prefix, size: 18),
      variants: {
        [.disabled]: .delta(color: colors.disable(prefix)),
      },
    ),
    titleTextStyle: FVariants.from(
      typography.base.copyWith(color: foreground),
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
      typography.base.copyWith(color: mutedForeground),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    suffixIconStyle: FVariants.from(
      IconThemeData(color: mutedForeground, size: 18),
      variants: {
        [.disabled]: .delta(color: disabledMutedForeground),
      },
    ),
    padding: const EdgeInsets.fromLTRB(15, 13, 10, 13),
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
    IconThemeData(color: prefix, size: 18),
    variants: {
      [.disabled]: .delta(color: colors.disable(prefix)),
    },
  ),
  childTextStyle: FVariants(
    typography.base.copyWith(color: color),
    variants: {
      [.disabled]: typography.base.copyWith(color: colors.disable(color)),
    },
  ),
  padding: const EdgeInsets.fromLTRB(15, 13, 10, 13),
  prefixIconSpacing: 10,
);
