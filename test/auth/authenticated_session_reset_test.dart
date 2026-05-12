import 'dart:convert';
import 'dart:typed_data';

import 'package:evolua_frontend/features/auth/application/authenticated_session_reset.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'clears authenticated providers when logout/login switches users',
    () async {
      SharedPreferences.setMockInitialValues({});
      final authRepository = _FakeAuthRepository([
        _session(userId: 'user-a', email: 'a@evolua.test'),
        _session(userId: 'user-b', email: 'b@evolua.test'),
      ]);
      final profileRepository = _FakeProfileRepository(
        _profile(userId: 'user-a', displayName: 'Usuario A'),
      );
      final container = _container(authRepository, profileRepository);
      addTearDown(container.dispose);

      container.read(authenticatedSessionResetObserverProvider);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@evolua.test', password: '123456');
      await Future<void>.delayed(Duration.zero);

      final firstProfile = await container.read(profileControllerProvider.future);
      expect(firstProfile?.userId, 'user-a');

      await container.read(authControllerProvider.notifier).logout();
      profileRepository.profile = _profile(
        userId: 'user-b',
        displayName: 'Usuario B',
      );
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'b@evolua.test', password: '123456');
      await Future<void>.delayed(Duration.zero);

      final secondProfile = await container.read(
        profileControllerProvider.future,
      );
      expect(secondProfile?.userId, 'user-b');
      expect(secondProfile?.displayName, 'Usuario B');
    },
  );
}

ProviderContainer _container(
  AuthRepository authRepository,
  ProfileRepository profileRepository,
) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      profileRepositoryProvider.overrideWithValue(profileRepository),
    ],
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._loginSessions);

  final List<AuthSession> _loginSessions;

  @override
  Future<AuthSession> exchangeGoogleCode({required String code}) async {
    return _loginSessions.removeAt(0);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _loginSessions.removeAt(0);
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {}

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    return _loginSessions.first;
  }

  @override
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.profile);

  Profile profile;

  @override
  Future<Profile?> getMe() async => profile;

  @override
  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  }) async {
    return profile;
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return profile.avatarUrl ?? '';
  }
}

Profile _profile({required String userId, required String displayName}) {
  return Profile(
    id: userId == 'user-a' ? 1 : 2,
    userId: userId,
    displayName: displayName,
    bio: '',
    journeyLevel: 1,
    premium: false,
    birthDate: DateTime(2000, 1, 1),
    gender: 'CUSTOM',
    customGender: null,
    avatarUrl: null,
    createdAt: DateTime(2026, 5, 12),
  );
}

AuthSession _session({required String userId, required String email}) {
  return AuthSession(
    userId: userId,
    email: email,
    roles: const ['ROLE_USER'],
    accessToken: _jwt(userId: userId, email: email),
    refreshToken: 'refresh-$userId',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
}

String _jwt({required String userId, required String email}) {
  String encode(Map<String, Object> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  final header = encode({'alg': 'none', 'typ': 'JWT'});
  final payload = encode({
    'sub': userId,
    'email': email,
    'roles': const ['ROLE_USER'],
    'exp':
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000,
  });
  return '$header.$payload.signature';
}
