import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/app/startup/startup_diagnostics.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessionStorageKey = 'evolua.auth.session';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return SharedPreferences.getInstance();
});

final authSessionStorageProvider = Provider<AuthSessionStorage>((ref) {
  return DefaultAuthSessionStorage(ref);
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
  Future<AuthSession?>? _refreshInFlight;

  @override
  Future<AuthSession?> build() async {
    final storage = ref.watch(authSessionStorageProvider);
    final session = await StartupDiagnostics.measure(
      'auth local session read',
      () => _readStoredSession(storage),
    );

    if (session == null) {
      StartupDiagnostics.mark('auth local session empty');
      return null;
    }

    if (!session.isExpired) {
      StartupDiagnostics.mark('auth local session valid');
      return session;
    }

    if (session.refreshToken == null || session.refreshToken!.isEmpty) {
      await _clearSession();
      StartupDiagnostics.mark('auth expired session without refresh token');
      return null;
    }

    final future = _refreshStoredSession(session, updateState: true);
    _refreshInFlight = future;
    future.whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });
    unawaited(future);
    StartupDiagnostics.mark('auth expired session accepted locally');
    return session;
  }

  Future<void> login({required String email, required String password}) async {
    final repository = ref.read(authRepositoryProvider);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await repository.login(email: email, password: password);
      await _saveSession(session);
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
    state = const AsyncLoading();

    AuthSession session;
    try {
      if (kDebugMode) {
        debugPrint('Auth register started.');
      }
      await repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (kDebugMode) {
        debugPrint('Auth register succeeded.');
        debugPrint('Auth post-register login started.');
      }
      session = await repository.login(email: email, password: password);
      await _saveSession(session);
      state = AsyncData(session);
      if (kDebugMode) {
        debugPrint('Auth post-register login succeeded.');
      }
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      if (kDebugMode) {
        debugPrint('Auth register failed: ${error.runtimeType}.');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

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
    } catch (_) {
      ref.invalidate(profileControllerProvider);
      return 'Sua conta foi criada, mas nao foi possivel concluir o perfil inicial agora. Voce pode completar isso no Perfil.';
    }
  }

  Future<void> completeGoogleLogin({required String code}) async {
    final repository = ref.read(authRepositoryProvider);

    state = const AsyncLoading();
    final nextState = await AsyncValue.guard(() async {
      final session = await repository.exchangeGoogleCode(code: code);
      await _saveSession(session);
      return session;
    });

    state = nextState;
    if (nextState.hasValue && nextState.value != null) {
      unawaited(_syncGoogleProfile(nextState.value!));
    }
  }

  Future<void> forgotPassword({required String email}) {
    return ref.read(authRepositoryProvider).forgotPassword(email: email);
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) {
    return ref
        .read(authRepositoryProvider)
        .resetPassword(token: token, newPassword: newPassword);
  }

  Future<void> _syncGoogleProfile(AuthSession session) async {
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

  Future<AuthSession?> refreshSession() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshCurrentSession();
    _refreshInFlight = future;
    future.whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });
    return future;
  }

  Future<AuthSession?> _refreshCurrentSession() async {
    final storage = ref.read(authSessionStorageProvider);
    final current = state.asData?.value ?? await _readStoredSession(storage);
    return _refreshStoredSession(current);
  }

  Future<AuthSession?> _refreshStoredSession(
    AuthSession? session, {
    bool updateState = true,
  }) async {
    final refreshToken = session?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearSession();
      if (updateState) {
        state = const AsyncData(null);
      }
      return null;
    }

    try {
      final refreshed = await ref
          .read(authRepositoryProvider)
          .refresh(refreshToken: refreshToken);
      if (!ref.mounted) {
        return refreshed;
      }
      await _saveSession(refreshed);
      if (!ref.mounted) {
        return refreshed;
      }
      if (updateState) {
        state = AsyncData(refreshed);
      }
      return refreshed;
    } catch (error) {
      if (_isInvalidRefreshFailure(error)) {
        if (!ref.mounted) {
          return null;
        }
        await _clearSession();
        if (!ref.mounted) {
          return null;
        }
        if (updateState) {
          state = const AsyncData(null);
        }
        if (kDebugMode) {
          debugPrint('Auth refresh rejected; session cleared.');
        }
        return null;
      }

      if (!ref.mounted) {
        return session;
      }
      if (updateState && session != null) {
        state = AsyncData(session);
      }
      if (kDebugMode) {
        debugPrint(
          'Auth refresh failed transiently; keeping stored session (${error.runtimeType}).',
        );
      }
      return session;
    }
  }

  bool _isInvalidRefreshFailure(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      return status == 400 || status == 401 || status == 403;
    }
    return false;
  }

  Future<AuthSession?> _readStoredSession(AuthSessionStorage storage) async {
    final rawSession = await storage.read();
    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawSession) as Map<String, dynamic>;
      return AuthSession.fromJson(decoded);
    } catch (_) {
      await storage.clear();
      return null;
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    await ref
        .read(authSessionStorageProvider)
        .write(jsonEncode(session.toJson()));
  }

  Future<void> _clearSession() async {
    await ref.read(authSessionStorageProvider).clear();
  }

  Future<void> logout() async {
    await _clearSession();
    state = const AsyncData(null);
  }
}

abstract class AuthSessionStorage {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> clear();
}

class DefaultAuthSessionStorage implements AuthSessionStorage {
  DefaultAuthSessionStorage(this._ref, {FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final Ref _ref;
  final FlutterSecureStorage _secureStorage;

  bool get _shouldUseSecureStorage {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Future<String?> read() async {
    if (_shouldUseSecureStorage) {
      final secureValue = await _readSecure();
      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    }

    final preferences = await _ref.read(sharedPreferencesProvider.future);
    final fallbackValue = preferences.getString(_sessionStorageKey);
    if (_shouldUseSecureStorage &&
        fallbackValue != null &&
        fallbackValue.isNotEmpty) {
      await write(fallbackValue);
    }
    return fallbackValue;
  }

  @override
  Future<void> write(String value) async {
    if (_shouldUseSecureStorage && await _writeSecure(value)) {
      final preferences = await _ref.read(sharedPreferencesProvider.future);
      await preferences.remove(_sessionStorageKey);
      return;
    }

    final preferences = await _ref.read(sharedPreferencesProvider.future);
    await preferences.setString(_sessionStorageKey, value);
  }

  @override
  Future<void> clear() async {
    if (_shouldUseSecureStorage) {
      await _deleteSecure();
    }

    final preferences = await _ref.read(sharedPreferencesProvider.future);
    await preferences.remove(_sessionStorageKey);
  }

  Future<String?> _readSecure() async {
    try {
      return await _secureStorage.read(key: _sessionStorageKey);
    } on Object {
      return null;
    }
  }

  Future<bool> _writeSecure(String value) async {
    try {
      await _secureStorage.write(key: _sessionStorageKey, value: value);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _deleteSecure() async {
    try {
      await _secureStorage.delete(key: _sessionStorageKey);
    } on Object {
      return;
    }
  }
}
