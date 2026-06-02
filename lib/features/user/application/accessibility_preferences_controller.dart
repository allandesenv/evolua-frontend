import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const accessibilityPreferencesStorageKey =
    'evolua.accessibility_preferences.v1';

class AccessibilityPreferences {
  const AccessibilityPreferences({
    required this.themeMode,
    required this.highContrast,
    required this.reduceTransparency,
    required this.animationLevel,
    required this.textSize,
    required this.readingSpacing,
    required this.accessibleFont,
    required this.focusMode,
    required this.reduceMotion,
    required this.hapticFeedback,
    required this.extendedResponseTime,
    required this.simplifiedNavigation,
    required this.reduceVisualStimuli,
    required this.softerLanguage,
    required this.hideSensitiveContent,
    required this.comfortMode,
  });

  factory AccessibilityPreferences.defaults() {
    return const AccessibilityPreferences(
      themeMode: 'dark',
      highContrast: false,
      reduceTransparency: false,
      animationLevel: 'normal',
      textSize: 'normal',
      readingSpacing: 'comfortable',
      accessibleFont: false,
      focusMode: false,
      reduceMotion: false,
      hapticFeedback: true,
      extendedResponseTime: false,
      simplifiedNavigation: false,
      reduceVisualStimuli: false,
      softerLanguage: false,
      hideSensitiveContent: false,
      comfortMode: false,
    );
  }

  factory AccessibilityPreferences.fromJson(Map<String, dynamic> json) {
    final defaults = AccessibilityPreferences.defaults();
    return AccessibilityPreferences(
      themeMode: _readString(json, 'themeMode', defaults.themeMode),
      highContrast: _readBool(json, 'highContrast', defaults.highContrast),
      reduceTransparency: _readBool(
        json,
        'reduceTransparency',
        defaults.reduceTransparency,
      ),
      animationLevel: _readString(
        json,
        'animationLevel',
        defaults.animationLevel,
      ),
      textSize: _readString(json, 'textSize', defaults.textSize),
      readingSpacing: _readString(
        json,
        'readingSpacing',
        defaults.readingSpacing,
      ),
      accessibleFont: _readBool(
        json,
        'accessibleFont',
        defaults.accessibleFont,
      ),
      focusMode: _readBool(json, 'focusMode', defaults.focusMode),
      reduceMotion: _readBool(json, 'reduceMotion', defaults.reduceMotion),
      hapticFeedback: _readBool(
        json,
        'hapticFeedback',
        defaults.hapticFeedback,
      ),
      extendedResponseTime: _readBool(
        json,
        'extendedResponseTime',
        defaults.extendedResponseTime,
      ),
      simplifiedNavigation: _readBool(
        json,
        'simplifiedNavigation',
        defaults.simplifiedNavigation,
      ),
      reduceVisualStimuli: _readBool(
        json,
        'reduceVisualStimuli',
        defaults.reduceVisualStimuli,
      ),
      softerLanguage: _readBool(
        json,
        'softerLanguage',
        defaults.softerLanguage,
      ),
      hideSensitiveContent: _readBool(
        json,
        'hideSensitiveContent',
        defaults.hideSensitiveContent,
      ),
      comfortMode: _readBool(json, 'comfortMode', defaults.comfortMode),
    );
  }

  final String themeMode;
  final bool highContrast;
  final bool reduceTransparency;
  final String animationLevel;
  final String textSize;
  final String readingSpacing;
  final bool accessibleFont;
  final bool focusMode;
  final bool reduceMotion;
  final bool hapticFeedback;
  final bool extendedResponseTime;
  final bool simplifiedNavigation;
  final bool reduceVisualStimuli;
  final bool softerLanguage;
  final bool hideSensitiveContent;
  final bool comfortMode;

  AccessibilityPreferences copyWith({
    String? themeMode,
    bool? highContrast,
    bool? reduceTransparency,
    String? animationLevel,
    String? textSize,
    String? readingSpacing,
    bool? accessibleFont,
    bool? focusMode,
    bool? reduceMotion,
    bool? hapticFeedback,
    bool? extendedResponseTime,
    bool? simplifiedNavigation,
    bool? reduceVisualStimuli,
    bool? softerLanguage,
    bool? hideSensitiveContent,
    bool? comfortMode,
  }) {
    return AccessibilityPreferences(
      themeMode: themeMode ?? this.themeMode,
      highContrast: highContrast ?? this.highContrast,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      animationLevel: animationLevel ?? this.animationLevel,
      textSize: textSize ?? this.textSize,
      readingSpacing: readingSpacing ?? this.readingSpacing,
      accessibleFont: accessibleFont ?? this.accessibleFont,
      focusMode: focusMode ?? this.focusMode,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      extendedResponseTime: extendedResponseTime ?? this.extendedResponseTime,
      simplifiedNavigation: simplifiedNavigation ?? this.simplifiedNavigation,
      reduceVisualStimuli: reduceVisualStimuli ?? this.reduceVisualStimuli,
      softerLanguage: softerLanguage ?? this.softerLanguage,
      hideSensitiveContent: hideSensitiveContent ?? this.hideSensitiveContent,
      comfortMode: comfortMode ?? this.comfortMode,
    );
  }

  ThemeMode get materialThemeMode {
    return switch (themeMode) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  double get textScale {
    return switch (textSize) {
      'small' => 0.94,
      'large' => 1.12,
      'extraLarge' => 1.24,
      _ => 1,
    };
  }

  bool get shouldReduceMotion {
    return reduceMotion ||
        animationLevel == 'reduced' ||
        animationLevel == 'none';
  }

  bool get shouldDisableAnimations {
    return reduceMotion || animationLevel == 'none';
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode,
      'highContrast': highContrast,
      'reduceTransparency': reduceTransparency,
      'animationLevel': animationLevel,
      'textSize': textSize,
      'readingSpacing': readingSpacing,
      'accessibleFont': accessibleFont,
      'focusMode': focusMode,
      'reduceMotion': reduceMotion,
      'hapticFeedback': hapticFeedback,
      'extendedResponseTime': extendedResponseTime,
      'simplifiedNavigation': simplifiedNavigation,
      'reduceVisualStimuli': reduceVisualStimuli,
      'softerLanguage': softerLanguage,
      'hideSensitiveContent': hideSensitiveContent,
      'comfortMode': comfortMode,
    };
  }

  static bool _readBool(Map<String, dynamic> json, String key, bool fallback) {
    final value = json[key];
    return value is bool ? value : fallback;
  }

  static String _readString(
    Map<String, dynamic> json,
    String key,
    String fallback,
  ) {
    final value = json[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }
}

class AccessibilityPreferencesRepository {
  const AccessibilityPreferencesRepository(this._preferences, this._dio);

  final SharedPreferences _preferences;
  final Dio _dio;

  Future<AccessibilityPreferences> load() async {
    try {
      final response = await _dio.get<dynamic>(
        '/v1/profiles/me/accessibility-settings',
      );
      final remote = AccessibilityPreferences.fromJson(
        ApiPayloadParser.dataMap(response.data),
      );
      await saveLocal(remote);
      return remote;
    } catch (_) {
      return loadLocal();
    }
  }

  Future<AccessibilityPreferences> loadLocal() async {
    final raw = _preferences.getString(accessibilityPreferencesStorageKey);
    if (raw == null || raw.isEmpty) {
      return AccessibilityPreferences.defaults();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AccessibilityPreferences.fromJson(decoded);
      }
      return AccessibilityPreferences.defaults();
    } catch (_) {
      return AccessibilityPreferences.defaults();
    }
  }

  Future<void> save(AccessibilityPreferences preferences) async {
    final response = await _dio.put<dynamic>(
      '/v1/profiles/me/accessibility-settings',
      data: preferences.toJson(),
    );
    final saved = AccessibilityPreferences.fromJson(
      ApiPayloadParser.dataMap(response.data),
    );
    await saveLocal(saved);
  }

  Future<void> saveLocal(AccessibilityPreferences preferences) async {
    await _preferences.setString(
      accessibilityPreferencesStorageKey,
      jsonEncode(preferences.toJson()),
    );
  }
}

final accessibilityPreferencesRepositoryProvider =
    Provider<AccessibilityPreferencesRepository>((ref) {
      final preferences = ref.watch(sharedPreferencesProvider).asData?.value;
      if (preferences == null) {
        throw StateError('SharedPreferences ainda nao esta disponivel.');
      }
      return AccessibilityPreferencesRepository(
        preferences,
        ref.watch(authenticatedDioProvider(AppConfig.userBaseUrl)),
      );
    });

final accessibilityPreferencesControllerProvider =
    AsyncNotifierProvider<
      AccessibilityPreferencesController,
      AccessibilityPreferences
    >(AccessibilityPreferencesController.new);

class AccessibilityPreferencesController
    extends AsyncNotifier<AccessibilityPreferences> {
  @override
  Future<AccessibilityPreferences> build() async {
    final preferences = await ref.watch(sharedPreferencesProvider.future);
    final repository = AccessibilityPreferencesRepository(
      preferences,
      ref.watch(authenticatedDioProvider(AppConfig.userBaseUrl)),
    );
    if (ref.watch(authControllerProvider).asData?.value == null) {
      return repository.loadLocal();
    }
    return repository.loadLocal();
  }

  void updatePreferences(
    AccessibilityPreferences Function(AccessibilityPreferences preferences)
    updater,
  ) {
    final current = state.value ?? AccessibilityPreferences.defaults();
    state = AsyncData(updater(current));
  }

  Future<void> save() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final repository = AccessibilityPreferencesRepository(
      preferences,
      ref.read(authenticatedDioProvider(AppConfig.userBaseUrl)),
    );
    await repository.save(state.value ?? AccessibilityPreferences.defaults());
  }
}
