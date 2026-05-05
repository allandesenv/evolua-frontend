import 'package:evolua_frontend/app/router/app_router.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/user/application/accessibility_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EvoluaApp extends ConsumerWidget {
  const EvoluaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final preferences =
        ref.watch(accessibilityPreferencesControllerProvider).value ??
        AccessibilityPreferences.defaults();
    final animationDuration = preferences.shouldDisableAnimations
        ? Duration.zero
        : preferences.shouldReduceMotion
        ? const Duration(milliseconds: 80)
        : kThemeAnimationDuration;

    return MaterialApp.router(
      title: 'Evolua',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        highContrast: preferences.highContrast,
        accessibleFont: preferences.accessibleFont,
        readingSpacing: preferences.readingSpacing,
      ),
      darkTheme: AppTheme.dark(
        highContrast: preferences.highContrast,
        accessibleFont: preferences.accessibleFont,
        readingSpacing: preferences.readingSpacing,
      ),
      themeMode: preferences.materialThemeMode,
      themeAnimationDuration: animationDuration,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(preferences.textScale),
            disableAnimations: preferences.shouldDisableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      locale: const Locale('pt', 'BR'),
      routerConfig: router,
    );
  }
}
