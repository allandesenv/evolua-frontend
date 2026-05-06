import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

@immutable
class EvoluaThemeColors extends ThemeExtension<EvoluaThemeColors> {
  const EvoluaThemeColors({
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceStrong,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentWarm,
    required this.accentGold,
    required this.danger,
    required this.shadow,
  });

  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceStrong;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentWarm;
  final Color accentGold;
  final Color danger;
  final Color shadow;

  static const dark = EvoluaThemeColors(
    background: AppColors.background,
    backgroundSecondary: AppColors.backgroundSecondary,
    surface: AppColors.surface,
    surfaceStrong: AppColors.surfaceStrong,
    outline: AppColors.outline,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    accent: AppColors.accent,
    accentWarm: AppColors.accentWarm,
    accentGold: AppColors.accentGold,
    danger: AppColors.danger,
    shadow: Color(0x33000000),
  );

  static const light = EvoluaThemeColors(
    background: Color(0xFFF4F8FB),
    backgroundSecondary: Color(0xFFEAF2F8),
    surface: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFE9F1F7),
    outline: Color(0xFFC9D6E1),
    textPrimary: Color(0xFF102033),
    textSecondary: Color(0xFF52667A),
    accent: Color(0xFF0F8F68),
    accentWarm: Color(0xFF2F78B7),
    accentGold: Color(0xFF8C6A15),
    danger: Color(0xFFC24141),
    shadow: Color(0x1A516174),
  );

  @override
  EvoluaThemeColors copyWith({
    Color? background,
    Color? backgroundSecondary,
    Color? surface,
    Color? surfaceStrong,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? accentWarm,
    Color? accentGold,
    Color? danger,
    Color? shadow,
  }) {
    return EvoluaThemeColors(
      background: background ?? this.background,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      surface: surface ?? this.surface,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      accentWarm: accentWarm ?? this.accentWarm,
      accentGold: accentGold ?? this.accentGold,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  EvoluaThemeColors lerp(ThemeExtension<EvoluaThemeColors>? other, double t) {
    if (other is! EvoluaThemeColors) {
      return this;
    }
    return EvoluaThemeColors(
      background: Color.lerp(background, other.background, t)!,
      backgroundSecondary: Color.lerp(
        backgroundSecondary,
        other.backgroundSecondary,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentWarm: Color.lerp(accentWarm, other.accentWarm, t)!,
      accentGold: Color.lerp(accentGold, other.accentGold, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension EvoluaThemeColorsContext on BuildContext {
  EvoluaThemeColors get evoluaColors {
    return Theme.of(this).extension<EvoluaThemeColors>() ??
        EvoluaThemeColors.dark;
  }
}
