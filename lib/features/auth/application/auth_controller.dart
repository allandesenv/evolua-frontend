import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
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

  Future<void> register({
    required String email,
    required String password,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    await repository.register(email: email, password: password);
    await login(email: email, password: password);
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
  }

  Future<void> logout() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.remove(_sessionStorageKey);
    state = const AsyncData(null);
  }
}
