import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData dark({
    bool highContrast = false,
    bool accessibleFont = false,
    String readingSpacing = 'comfortable',
  }) {
    return _build(
      brightness: Brightness.dark,
      background: highContrast ? const Color(0xFF050914) : AppColors.background,
      backgroundSecondary: highContrast
          ? const Color(0xFF0B1020)
          : AppColors.backgroundSecondary,
      surface: highContrast ? const Color(0xFF0F172A) : AppColors.surface,
      surfaceStrong: highContrast
          ? const Color(0xFF1E293B)
          : AppColors.surfaceStrong,
      outline: highContrast ? const Color(0xFF6B7D95) : AppColors.outline,
      textPrimary: highContrast ? Colors.white : AppColors.textPrimary,
      textSecondary: highContrast
          ? const Color(0xFFD5E3F2)
          : AppColors.textSecondary,
      accent: highContrast ? const Color(0xFF8DFFD5) : AppColors.accent,
      accentWarm: highContrast ? const Color(0xFFAED6FF) : AppColors.accentWarm,
      themeColors: highContrast
          ? EvoluaThemeColors.dark.copyWith(
              background: const Color(0xFF050914),
              backgroundSecondary: const Color(0xFF0B1020),
              surface: const Color(0xFF0F172A),
              surfaceStrong: const Color(0xFF1E293B),
              outline: const Color(0xFF6B7D95),
              textPrimary: Colors.white,
              textSecondary: const Color(0xFFD5E3F2),
              accent: const Color(0xFF8DFFD5),
              accentWarm: const Color(0xFFAED6FF),
            )
          : EvoluaThemeColors.dark,
      accessibleFont: accessibleFont,
      readingSpacing: readingSpacing,
    );
  }

  static ThemeData light({
    bool highContrast = false,
    bool accessibleFont = false,
    String readingSpacing = 'comfortable',
  }) {
    return _build(
      brightness: Brightness.light,
      background: highContrast
          ? const Color(0xFFFFFFFF)
          : const Color(0xFFF4F8FB),
      backgroundSecondary: highContrast
          ? const Color(0xFFF6FAFE)
          : const Color(0xFFEAF2F8),
      surface: highContrast ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF),
      surfaceStrong: highContrast
          ? const Color(0xFFE5EDF5)
          : const Color(0xFFE9F1F7),
      outline: highContrast ? const Color(0xFF526171) : const Color(0xFFC9D6E1),
      textPrimary: highContrast
          ? const Color(0xFF06111F)
          : const Color(0xFF102033),
      textSecondary: highContrast
          ? const Color(0xFF20344A)
          : const Color(0xFF52667A),
      accent: const Color(0xFF0F8F68),
      accentWarm: const Color(0xFF2F78B7),
      themeColors: highContrast
          ? EvoluaThemeColors.light.copyWith(
              background: Colors.white,
              backgroundSecondary: const Color(0xFFF6FAFE),
              surface: Colors.white,
              surfaceStrong: const Color(0xFFE5EDF5),
              outline: const Color(0xFF526171),
              textPrimary: const Color(0xFF06111F),
              textSecondary: const Color(0xFF20344A),
            )
          : EvoluaThemeColors.light,
      accessibleFont: accessibleFont,
      readingSpacing: readingSpacing,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color backgroundSecondary,
    required Color surface,
    required Color surfaceStrong,
    required Color outline,
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    required Color accentWarm,
    required EvoluaThemeColors themeColors,
    required bool accessibleFont,
    required String readingSpacing,
  }) {
    final sourceTextTheme = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final baseTextTheme =
        (accessibleFont
                ? sourceTextTheme
                : GoogleFonts.plusJakartaSansTextTheme(sourceTextTheme))
            .apply(bodyColor: textPrimary, displayColor: textPrimary);
    final displayFamily = accessibleFont
        ? baseTextTheme.displayLarge?.fontFamily
        : GoogleFonts.spaceGrotesk().fontFamily;
    final bodyHeight = switch (readingSpacing) {
      'compact' => 1.32,
      'wide' => 1.62,
      _ => 1.45,
    };

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: accent,
      secondary: accentWarm,
      surface: surface,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      extensions: [themeColors],
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      hoverColor: accent.withValues(alpha: 0.08),
      focusColor: accent.withValues(alpha: 0.12),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontFamily: displayFamily,
          fontSize: 52,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          fontFamily: displayFamily,
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          height: bodyHeight,
          color: textPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          height: bodyHeight,
          color: textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceStrong.withValues(alpha: 0.52),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline.withValues(alpha: 0.64)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline.withValues(alpha: 0.64)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(color: textSecondary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: outline.withValues(alpha: 0.58)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: accent.withValues(alpha: 0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: accent.withValues(alpha: 0.26)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          hoverColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.18),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.95),
        indicatorColor: accent.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => baseTextTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? textPrimary
                : textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.18),
        selectedIconTheme: IconThemeData(color: textPrimary),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle: baseTextTheme.labelMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: baseTextTheme.labelMedium?.copyWith(
          color: textSecondary,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceStrong.withValues(alpha: 0.42),
        selectedColor: accent.withValues(alpha: 0.14),
        disabledColor: surfaceStrong.withValues(alpha: 0.25),
        side: BorderSide(color: outline.withValues(alpha: 0.42)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: baseTextTheme.bodyMedium?.copyWith(color: textPrimary),
        secondaryLabelStyle: baseTextTheme.bodyMedium?.copyWith(
          color: textPrimary,
        ),
        secondarySelectedColor: accent.withValues(alpha: 0.14),
        checkmarkColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        labelStyle: baseTextTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceStrong,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: outline.withValues(alpha: 0.5)),
        ),
        textStyle: baseTextTheme.bodySmall?.copyWith(color: textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outline.withValues(alpha: 0.35)),
        ),
      ),
      dividerColor: outline.withValues(alpha: 0.3),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceStrong,
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
          color: textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
