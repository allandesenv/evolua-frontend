import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const localePreferenceStorageKey = 'evolua.locale_preference.v1';

enum LocalePreference {
  system('system'),
  ptBr('pt-BR'),
  enUs('en-US');

  const LocalePreference(this.storageValue);

  final String storageValue;

  Locale? get locale {
    return switch (this) {
      LocalePreference.system => null,
      LocalePreference.ptBr => const Locale('pt', 'BR'),
      LocalePreference.enUs => const Locale('en', 'US'),
    };
  }

  static LocalePreference fromStorage(String? value) {
    return LocalePreference.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => LocalePreference.ptBr,
    );
  }
}

String effectiveAppLanguageTag({
  required String? preference,
  required Locale systemLocale,
}) {
  final localePreference = LocalePreference.fromStorage(preference);
  return switch (localePreference) {
    LocalePreference.ptBr => 'pt-BR',
    LocalePreference.enUs => 'en-US',
    LocalePreference.system =>
      systemLocale.languageCode.toLowerCase() == 'en' ? 'en-US' : 'pt-BR',
  };
}

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, LocalePreference>(
      LocaleController.new,
    );

class LocaleController extends AsyncNotifier<LocalePreference> {
  @override
  Future<LocalePreference> build() async {
    final preferences = await ref.watch(sharedPreferencesProvider.future);
    return LocalePreference.fromStorage(
      preferences.getString(localePreferenceStorageKey),
    );
  }

  Future<void> setPreference(LocalePreference preference) async {
    state = AsyncData(preference);
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setString(
      localePreferenceStorageKey,
      preference.storageValue,
    );
  }
}
