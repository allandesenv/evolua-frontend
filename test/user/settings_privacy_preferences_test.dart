import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/features/user/application/settings_privacy_preferences_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('uses safe default preferences', () {
    final preferences = SettingsPrivacyPreferences.defaults();

    expect(preferences.privateJournal, isTrue);
    expect(preferences.hideSocialCheckIns, isTrue);
    expect(preferences.allowHistoryInsights, isTrue);
    expect(preferences.useEmotionalDataForAi, isTrue);
    expect(preferences.dailyReminders, isTrue);
    expect(preferences.contentPreferences, isTrue);
    expect(preferences.aiTone, 'acolhedor');
    expect(preferences.suggestionFrequency, 'equilibrada');
    expect(preferences.trailStyle, 'guiada');
  });

  test('serializes and hydrates saved values', () {
    final preferences = SettingsPrivacyPreferences.defaults().copyWith(
      privateJournal: false,
      hideSocialCheckIns: false,
      aiTone: 'direto',
      suggestionFrequency: 'alta',
      trailStyle: 'livre',
    );

    final hydrated = SettingsPrivacyPreferences.fromJson(preferences.toJson());

    expect(hydrated.privateJournal, isFalse);
    expect(hydrated.hideSocialCheckIns, isFalse);
    expect(hydrated.aiTone, 'direto');
    expect(hydrated.suggestionFrequency, 'alta');
    expect(hydrated.trailStyle, 'livre');
  });

  test('repository loads persisted preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final repository = SettingsPrivacyPreferencesRepository(
      sharedPreferences,
      Dio()..httpClientAdapter = _FailingAdapter(),
    );

    await repository.saveLocal(
      SettingsPrivacyPreferences.defaults().copyWith(
        dailyReminders: false,
        contentPreferences: false,
        aiTone: 'reflexivo',
      ),
    );

    final loaded = await repository.loadLocal();

    expect(loaded.dailyReminders, isFalse);
    expect(loaded.contentPreferences, isFalse);
    expect(loaded.aiTone, 'reflexivo');
  });

  test('repository tolerates invalid json', () async {
    SharedPreferences.setMockInitialValues({
      settingsPrivacyPreferencesStorageKey: '{broken',
    });
    final sharedPreferences = await SharedPreferences.getInstance();
    final repository = SettingsPrivacyPreferencesRepository(
      sharedPreferences,
      Dio()..httpClientAdapter = _FailingAdapter(),
    );

    final loaded = await repository.loadLocal();

    expect(loaded.toJson(), SettingsPrivacyPreferences.defaults().toJson());
  });

  test('repository tolerates partial json', () async {
    SharedPreferences.setMockInitialValues({
      settingsPrivacyPreferencesStorageKey: jsonEncode({
        'privateJournal': false,
      }),
    });
    final sharedPreferences = await SharedPreferences.getInstance();
    final repository = SettingsPrivacyPreferencesRepository(
      sharedPreferences,
      Dio()..httpClientAdapter = _FailingAdapter(),
    );

    final loaded = await repository.loadLocal();

    expect(loaded.privateJournal, isFalse);
    expect(loaded.hideSocialCheckIns, isTrue);
    expect(loaded.aiTone, 'acolhedor');
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
