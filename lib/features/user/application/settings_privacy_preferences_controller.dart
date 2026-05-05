import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const settingsPrivacyPreferencesStorageKey =
    'evolua.settings_privacy_preferences.v1';

class SettingsPrivacyPreferences {
  const SettingsPrivacyPreferences({
    required this.privateJournal,
    required this.hideSocialCheckIns,
    required this.allowHistoryInsights,
    required this.useEmotionalDataForAi,
    required this.dailyReminders,
    required this.contentPreferences,
    required this.aiTone,
    required this.suggestionFrequency,
    required this.trailStyle,
  });

  factory SettingsPrivacyPreferences.defaults() {
    return const SettingsPrivacyPreferences(
      privateJournal: true,
      hideSocialCheckIns: true,
      allowHistoryInsights: true,
      useEmotionalDataForAi: true,
      dailyReminders: true,
      contentPreferences: true,
      aiTone: 'acolhedor',
      suggestionFrequency: 'equilibrada',
      trailStyle: 'guiada',
    );
  }

  factory SettingsPrivacyPreferences.fromJson(Map<String, dynamic> json) {
    final defaults = SettingsPrivacyPreferences.defaults();
    return SettingsPrivacyPreferences(
      privateJournal: _readBool(
        json,
        'privateJournal',
        defaults.privateJournal,
      ),
      hideSocialCheckIns: _readBool(
        json,
        'hideSocialCheckIns',
        defaults.hideSocialCheckIns,
      ),
      allowHistoryInsights: _readBool(
        json,
        'allowHistoryInsights',
        defaults.allowHistoryInsights,
      ),
      useEmotionalDataForAi: _readBool(
        json,
        'useEmotionalDataForAi',
        defaults.useEmotionalDataForAi,
      ),
      dailyReminders: _readBool(
        json,
        'dailyReminders',
        defaults.dailyReminders,
      ),
      contentPreferences: _readBool(
        json,
        'contentPreferences',
        defaults.contentPreferences,
      ),
      aiTone: _readString(json, 'aiTone', defaults.aiTone),
      suggestionFrequency: _readString(
        json,
        'suggestionFrequency',
        defaults.suggestionFrequency,
      ),
      trailStyle: _readString(json, 'trailStyle', defaults.trailStyle),
    );
  }

  final bool privateJournal;
  final bool hideSocialCheckIns;
  final bool allowHistoryInsights;
  final bool useEmotionalDataForAi;
  final bool dailyReminders;
  final bool contentPreferences;
  final String aiTone;
  final String suggestionFrequency;
  final String trailStyle;

  SettingsPrivacyPreferences copyWith({
    bool? privateJournal,
    bool? hideSocialCheckIns,
    bool? allowHistoryInsights,
    bool? useEmotionalDataForAi,
    bool? dailyReminders,
    bool? contentPreferences,
    String? aiTone,
    String? suggestionFrequency,
    String? trailStyle,
  }) {
    return SettingsPrivacyPreferences(
      privateJournal: privateJournal ?? this.privateJournal,
      hideSocialCheckIns: hideSocialCheckIns ?? this.hideSocialCheckIns,
      allowHistoryInsights: allowHistoryInsights ?? this.allowHistoryInsights,
      useEmotionalDataForAi:
          useEmotionalDataForAi ?? this.useEmotionalDataForAi,
      dailyReminders: dailyReminders ?? this.dailyReminders,
      contentPreferences: contentPreferences ?? this.contentPreferences,
      aiTone: aiTone ?? this.aiTone,
      suggestionFrequency: suggestionFrequency ?? this.suggestionFrequency,
      trailStyle: trailStyle ?? this.trailStyle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'privateJournal': privateJournal,
      'hideSocialCheckIns': hideSocialCheckIns,
      'allowHistoryInsights': allowHistoryInsights,
      'useEmotionalDataForAi': useEmotionalDataForAi,
      'dailyReminders': dailyReminders,
      'contentPreferences': contentPreferences,
      'aiTone': aiTone,
      'suggestionFrequency': suggestionFrequency,
      'trailStyle': trailStyle,
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

class SettingsPrivacyPreferencesRepository {
  const SettingsPrivacyPreferencesRepository(this._preferences, this._dio);

  final SharedPreferences _preferences;
  final Dio _dio;

  Future<SettingsPrivacyPreferences> load() async {
    try {
      final response = await _dio.get<dynamic>(
        '/v1/profiles/me/privacy-settings',
      );
      final remote = SettingsPrivacyPreferences.fromJson(
        ApiPayloadParser.dataMap(response.data),
      );
      await saveLocal(remote);
      return remote;
    } catch (_) {
      return loadLocal();
    }
  }

  Future<SettingsPrivacyPreferences> loadLocal() async {
    final raw = _preferences.getString(settingsPrivacyPreferencesStorageKey);
    if (raw == null || raw.isEmpty) {
      return SettingsPrivacyPreferences.defaults();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return SettingsPrivacyPreferences.fromJson(decoded);
      }
      return SettingsPrivacyPreferences.defaults();
    } catch (_) {
      return SettingsPrivacyPreferences.defaults();
    }
  }

  Future<void> save(SettingsPrivacyPreferences preferences) async {
    final response = await _dio.put<dynamic>(
      '/v1/profiles/me/privacy-settings',
      data: preferences.toJson(),
    );
    final saved = SettingsPrivacyPreferences.fromJson(
      ApiPayloadParser.dataMap(response.data),
    );
    await saveLocal(saved);
  }

  Future<void> saveLocal(SettingsPrivacyPreferences preferences) async {
    await _preferences.setString(
      settingsPrivacyPreferencesStorageKey,
      jsonEncode(preferences.toJson()),
    );
  }

  Future<String> exportData() async {
    final response = await _dio.get<dynamic>('/v1/profiles/me/data-export');
    final payload = ApiPayloadParser.dataMap(response.data);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}

final settingsPrivacyPreferencesRepositoryProvider =
    Provider<SettingsPrivacyPreferencesRepository>((ref) {
      final preferences = ref.watch(sharedPreferencesProvider).asData?.value;
      if (preferences == null) {
        throw StateError('SharedPreferences ainda nao esta disponivel.');
      }
      return SettingsPrivacyPreferencesRepository(
        preferences,
        ref.watch(authenticatedDioProvider(AppConfig.userBaseUrl)),
      );
    });

class AccountSettingsRepository {
  const AccountSettingsRepository(this._dio);

  final Dio _dio;

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.patch<dynamic>(
      '/v1/auth/me/password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> revokeSessions() async {
    await _dio.post<dynamic>('/v1/auth/me/sessions/revoke');
  }

  Future<void> deactivate({required String confirmation}) async {
    await _dio.post<dynamic>(
      '/v1/auth/me/deactivate',
      data: {'confirmation': confirmation},
    );
  }

  Future<void> deleteAccount({
    required String confirmation,
    String? currentPassword,
  }) async {
    await _dio.delete<dynamic>(
      '/v1/auth/me',
      data: {
        'confirmation': confirmation,
        if (currentPassword != null && currentPassword.isNotEmpty)
          'currentPassword': currentPassword,
      },
    );
  }
}

final accountSettingsRepositoryProvider = Provider<AccountSettingsRepository>((
  ref,
) {
  return AccountSettingsRepository(
    ref.watch(authenticatedDioProvider(AppConfig.authBaseUrl)),
  );
});

final settingsPrivacyPreferencesControllerProvider =
    AsyncNotifierProvider<
      SettingsPrivacyPreferencesController,
      SettingsPrivacyPreferences
    >(SettingsPrivacyPreferencesController.new);

class SettingsPrivacyPreferencesController
    extends AsyncNotifier<SettingsPrivacyPreferences> {
  @override
  Future<SettingsPrivacyPreferences> build() async {
    final preferences = await ref.watch(sharedPreferencesProvider.future);
    final repository = SettingsPrivacyPreferencesRepository(
      preferences,
      ref.watch(authenticatedDioProvider(AppConfig.userBaseUrl)),
    );
    return repository.load();
  }

  void updatePreferences(
    SettingsPrivacyPreferences Function(SettingsPrivacyPreferences preferences)
    updater,
  ) {
    final current = state.value ?? SettingsPrivacyPreferences.defaults();
    state = AsyncData(updater(current));
  }

  Future<void> save() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final repository = SettingsPrivacyPreferencesRepository(
      preferences,
      ref.read(authenticatedDioProvider(AppConfig.userBaseUrl)),
    );
    await repository.save(state.value ?? SettingsPrivacyPreferences.defaults());
  }

  Future<String> exportData() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final repository = SettingsPrivacyPreferencesRepository(
      preferences,
      ref.read(authenticatedDioProvider(AppConfig.userBaseUrl)),
    );
    return repository.exportData();
  }
}
