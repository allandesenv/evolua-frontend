import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessionStorageKey = 'evolua.auth.session';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.authBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  return AuthRepositoryImpl(dio);
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final preferences = await ref.watch(sharedPreferencesProvider.future);
    final rawSession = preferences.getString(_sessionStorageKey);

    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawSession) as Map<String, dynamic>;
      final session = AuthSession.fromJson(decoded);

      if (session.isExpired) {
        await preferences.remove(_sessionStorageKey);
        return null;
      }

      return session;
    } catch (_) {
      await preferences.remove(_sessionStorageKey);
      return null;
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    final preferences = await ref.read(sharedPreferencesProvider.future);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await repository.login(email: email, password: password);
      await preferences.setString(_sessionStorageKey, jsonEncode(session.toJson()));
      return session;
    });
  }

  Future<String?> register({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String email,
    required String password,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await repository.register(
      email: email,
      password: password,
      displayName: displayName,
    );

    state = const AsyncLoading();
    final session = await repository.login(email: email, password: password);
    await preferences.setString(_sessionStorageKey, jsonEncode(session.toJson()));
    state = AsyncData(session);

    try {
      await ref
          .read(profileRepositoryProvider)
          .upsertMe(
            displayName: displayName,
            birthDate: birthDate,
            gender: gender,
            customGender: customGender,
            bio: '',
            journeyLevel: 1,
          );
      ref.invalidate(profileControllerProvider);
      return null;
    } on DioException catch (_) {
      ref.invalidate(profileControllerProvider);
      return 'Sua conta foi criada, mas nao foi possivel concluir o perfil inicial agora. Voce pode completar isso no Perfil.';
    }
  }

  Future<void> completeGoogleLogin({
    required String code,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    final preferences = await ref.read(sharedPreferencesProvider.future);

    state = const AsyncLoading();
    final nextState = await AsyncValue.guard(() async {
      final session = await repository.exchangeGoogleCode(code: code);
      await preferences.setString(_sessionStorageKey, jsonEncode(session.toJson()));
      return session;
    });

    state = nextState;
    if (nextState.hasValue && nextState.value != null) {
      final session = nextState.value!;
      try {
        await ref
            .read(profileRepositoryProvider)
            .upsertMe(
              displayName: session.displayName ?? session.email.split('@').first,
              birthDate: DateTime(2000, 1, 1),
              gender: 'CUSTOM',
              customGender: 'Nao informado',
              bio: '',
              journeyLevel: 1,
            );
        ref.invalidate(profileControllerProvider);
      } catch (_) {
        ref.invalidate(profileControllerProvider);
      }
    }
  }

  Future<void> logout() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.remove(_sessionStorageKey);
    state = const AsyncData(null);
  }
}
