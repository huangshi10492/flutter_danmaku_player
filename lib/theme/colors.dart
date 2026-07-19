import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

enum AppColors {
  neutral('neutral', 0xFF171717, 0xFFFAFAFA, 0xFFE5E5E5, 0xFF171717),
  zinc('zinc', 0xFF18181B, 0xFFFAFAFA, 0xFFE4E4E7, 0xFF18181B),
  amber('amber', 0xFFBB4D00, 0xFFFFFBEB, 0xFF973C00, 0xFFFFFBEB),
  blue('blue', 0xFF1447E6, 0xFFEFF6FF, 0xFF193CB8, 0xFFEFF6FF),
  cyan('cyan', 0xFF007595, 0xFFECFEFF, 0xFF005F78, 0xFFECFEFF),
  emerald('emerald', 0xFF007A55, 0xFFECFDF5, 0xFF006045, 0xFFECFDF5),
  fuchsia('fuchsia', 0xFFA800B7, 0xFFFDF4FF, 0xFF8A0194, 0xFFFDF4FF),
  green('green', 0xFF008236, 0xFFF0FDF4, 0xFF016630, 0xFFF0FDF4),
  indigo('indigo', 0xFF432DD7, 0xFFEEF2FF, 0xFF372AAC, 0xFFEEF2FF),
  lime('lime', 0xFF9AE600, 0xFF35530E, 0xFF7CCF00, 0xFF35530E),
  orange('orange', 0xFFCA3500, 0xFFFFF7ED, 0xFF9F2D00, 0xFFFFF7ED),
  pink('pink', 0xFFC6005C, 0xFFFDF2F8, 0xFFA3004C, 0xFFFDF2F8),
  purple('purple', 0xFF8200DB, 0xFFFAF5FF, 0xFF6E11B0, 0xFFFAF5FF),
  red('red', 0xFFC10007, 0xFFFEF2F2, 0xFF9F0712, 0xFFFEF2F2),
  rose('rose', 0xFFC70036, 0xFFFFF1F2, 0xFFA50036, 0xFFFFF1F2),
  sky('sky', 0xFF0069A8, 0xFFF0F9FF, 0xFF00598A, 0xFFF0F9FF),
  teal('teal', 0xFF00786F, 0xFFF0FDFA, 0xFF005F5A, 0xFFF0FDFA),
  violet('violet', 0xFF7008E7, 0xFFF5F3FF, 0xFF5D0EC0, 0xFFF5F3FF),
  yellow('yellow', 0xFFFDC700, 0xFF733E0A, 0xFFF0B100, 0xFF733E0A);

  final String tag;
  final int primary;
  final int primaryForeground;
  final int primaryDark;
  final int primaryForegroundDark;

  const AppColors(
    this.tag,
    this.primary,
    this.primaryForeground,
    this.primaryDark,
    this.primaryForegroundDark,
  );

  FColors get light => _lightColors(this);
  FColors get dark => _darkColors(this);
}

FColors _lightColors(AppColors color) {
  return FColors(
    brightness: .light,
    systemOverlayStyle: .dark,
    barrier: Color(0x33000000),
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF0A0A0A),
    primary: Color(color.primary),
    primaryForeground: Color(color.primaryForeground),
    secondary: Color(0xFFF5F5F5),
    secondaryForeground: Color(0xFF171717),
    muted: Color(0xFFF5F5F5),
    mutedForeground: Color(0xFF737373),
    destructive: Color(0xFFE7000B),
    destructiveForeground: Color(0xFFFAFAFA),
    error: Color(0xFFE7000B),
    errorForeground: Color(0xFFFAFAFA),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE5E5E5),
  );
}

FColors _darkColors(AppColors color) {
  return FColors(
    brightness: .dark,
    systemOverlayStyle: .light,
    barrier: Color(0x7A000000),
    background: Color(0xFF0A0A0A),
    foreground: Color(0xFFFAFAFA),
    primary: Color(color.primaryDark),
    primaryForeground: Color(color.primaryForegroundDark),
    secondary: Color(0xFF262626),
    secondaryForeground: Color(0xFFFAFAFA),
    muted: Color(0xFF262626),
    mutedForeground: Color(0xFFA1A1A1),
    destructive: Color(0xFFFF6467),
    destructiveForeground: Color(0xFFFAFAFA),
    error: Color(0xFFFF6467),
    errorForeground: Color(0xFFFAFAFA),
    card: Color(0xFF171717),
    border: Color(0x1AFFFFFF),
  );
}
