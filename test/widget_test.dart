import 'dart:convert';

import 'package:evolua_frontend/app/app.dart';
import 'package:evolua_frontend/features/user/application/accessibility_preferences_controller.dart';
import 'package:evolua_frontend/l10n/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders Evolua auth shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: EvoluaApp()));

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Evolua'), findsWidgets);
    expect(find.text('Continue sua jornada'), findsWidgets);
    expect(find.textContaining('Entre e continue sua jornada'), findsNothing);
  });

  testWidgets('uses pt-BR as default locale', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: EvoluaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Continue sua jornada'), findsWidgets);
    expect(find.text('Continue your journey'), findsNothing);
  });

  testWidgets('uses persisted en-US locale preference', (tester) async {
    SharedPreferences.setMockInitialValues({
      localePreferenceStorageKey: LocalePreference.enUs.storageValue,
    });

    await tester.pumpWidget(const ProviderScope(child: EvoluaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Continue your journey'), findsWidgets);
    expect(find.text('Continue sua jornada'), findsNothing);
  });

  testWidgets('applies cached accessibility preferences globally', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      accessibilityPreferencesStorageKey: jsonEncode(
        AccessibilityPreferences.defaults()
            .copyWith(themeMode: 'light', textSize: 'extraLarge')
            .toJson(),
      ),
    });

    await tester.pumpWidget(const ProviderScope(child: EvoluaApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Evolua').first);
    expect(Theme.of(context).brightness, Brightness.light);
    expect(MediaQuery.of(context).textScaler.scale(10), 12.4);
  });
}
