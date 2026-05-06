import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/features/user/application/accessibility_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('uses safe default accessibility preferences', () {
    final preferences = AccessibilityPreferences.defaults();

    expect(preferences.themeMode, 'dark');
    expect(preferences.materialThemeMode, ThemeMode.dark);
    expect(preferences.highContrast, isFalse);
    expect(preferences.textSize, 'normal');
    expect(preferences.textScale, 1);
    expect(preferences.readingSpacing, 'comfortable');
    expect(preferences.hapticFeedback, isTrue);
    expect(preferences.comfortMode, isFalse);
  });

  test('serializes and hydrates saved values', () {
    final preferences = AccessibilityPreferences.defaults().copyWith(
      themeMode: 'light',
      highContrast: true,
      animationLevel: 'none',
      textSize: 'extraLarge',
      readingSpacing: 'wide',
      comfortMode: true,
    );

    final hydrated = AccessibilityPreferences.fromJson(preferences.toJson());

    expect(hydrated.themeMode, 'light');
    expect(hydrated.materialThemeMode, ThemeMode.light);
    expect(hydrated.highContrast, isTrue);
    expect(hydrated.shouldDisableAnimations, isTrue);
    expect(hydrated.textScale, 1.24);
    expect(hydrated.readingSpacing, 'wide');
    expect(hydrated.comfortMode, isTrue);
  });

  test('repository loads persisted accessibility preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final repository = AccessibilityPreferencesRepository(
      sharedPreferences,
      Dio()..httpClientAdapter = _FailingAdapter(),
    );

    await repository.saveLocal(
      AccessibilityPreferences.defaults().copyWith(
        themeMode: 'system',
        textSize: 'large',
        reduceMotion: true,
      ),
    );

    final loaded = await repository.loadLocal();

    expect(loaded.themeMode, 'system');
    expect(loaded.materialThemeMode, ThemeMode.system);
    expect(loaded.textSize, 'large');
    expect(loaded.shouldReduceMotion, isTrue);
  });

  test('repository tolerates invalid json', () async {
    SharedPreferences.setMockInitialValues({
      accessibilityPreferencesStorageKey: '{broken',
    });
    final sharedPreferences = await SharedPreferences.getInstance();
    final repository = AccessibilityPreferencesRepository(
      sharedPreferences,
      Dio()..httpClientAdapter = _FailingAdapter(),
    );

    final loaded = await repository.loadLocal();

    expect(loaded.toJson(), AccessibilityPreferences.defaults().toJson());
  });

  test('repository tolerates partial json', () async {
    SharedPreferences.setMockInitialValues({
      accessibilityPreferencesStorageKey: jsonEncode({'themeMode': 'light'}),
    });
    final sharedPreferences = await SharedPreferences.getInstance();
    final repository = AccessibilityPreferencesRepository(
      sharedPreferences,
      Dio()..httpClientAdapter = _FailingAdapter(),
    );

    final loaded = await repository.loadLocal();

    expect(loaded.themeMode, 'light');
    expect(loaded.highContrast, isFalse);
    expect(loaded.textSize, 'normal');
  });
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException(requestOptions: options);
  }
}
