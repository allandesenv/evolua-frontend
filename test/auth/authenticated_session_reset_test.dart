import 'dart:convert';
import 'dart:typed_data';

import 'package:evolua_frontend/features/auth/application/authenticated_session_reset.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
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
      final checkInRepository = _FakeCheckInRepository(
        _checkIn(userId: 'user-a', insight: 'Leitura do usuário A'),
      );
      final container = _container(
        authRepository,
        profileRepository,
        checkInRepository,
      );
      addTearDown(container.dispose);

      container.read(authenticatedSessionResetObserverProvider);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@evolua.test', password: '123456');
      await Future<void>.delayed(Duration.zero);

      final firstProfile = await container.read(
        profileControllerProvider.future,
      );
      expect(firstProfile?.userId, 'user-a');
      final firstCheckInHistory = await container.read(
        checkInControllerProvider.future,
      );
      expect(firstCheckInHistory.ownerUserId, 'user-a');
      expect(
        firstCheckInHistory.latestCreatedCheckIn?.aiInsight?.insight,
        'Leitura do usuário A',
      );

      await container.read(authControllerProvider.notifier).logout();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(checkInControllerProvider).isLoading, isTrue);

      profileRepository.profile = _profile(
        userId: 'user-b',
        displayName: 'Usuario B',
      );
      checkInRepository.item = _checkIn(
        userId: 'user-b',
        insight: 'Leitura do usuário B',
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
      final secondCheckInHistory = await container.read(
        checkInControllerProvider.future,
      );
      expect(secondCheckInHistory.ownerUserId, 'user-b');
      expect(
        secondCheckInHistory.latestCreatedCheckIn?.aiInsight?.insight,
        'Leitura do usuário B',
      );
    },
  );
}

ProviderContainer _container(
  AuthRepository authRepository,
  ProfileRepository profileRepository,
  CheckInRepository checkInRepository,
) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      profileRepositoryProvider.overrideWithValue(profileRepository),
      checkInRepositoryProvider.overrideWithValue(checkInRepository),
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

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository(this.item);

  CheckIn item;

  @override
  Future<PaginatedResponse<CheckIn>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? mood,
    String? energyRange,
    DateTime? from,
    DateTime? to,
  }) async {
    return PaginatedResponse(
      items: [item],
      page: page,
      size: size,
      totalItems: 1,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<CheckIn> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) async {
    item = _checkIn(userId: item.userId, insight: 'Nova leitura');
    return item;
  }

  @override
  Future<CheckIn> generateDeepReading(
    int checkInId, {
    String style = 'deep',
  }) async => item;

  @override
  Future<CheckIn> saveReading(int checkInId) async => item;

  @override
  Future<void> createRitualFromReading(
    int checkInId, {
    required DateTime localDate,
    required String type,
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

CheckIn _checkIn({required String userId, required String insight}) {
  return CheckIn(
    id: userId == 'user-a' ? 1 : 2,
    userId: userId,
    mood: 'calma',
    reflection: '',
    energyLevel: 7,
    recommendedPractice: 'Respire por dois minutos.',
    aiInsight: CheckInAiInsight(
      insight: insight,
      suggestedAction: 'Respire com calma.',
      riskLevel: 'low',
      suggestedTrailId: null,
      suggestedTrailTitle: null,
      suggestedTrailReason: '',
      suggestedSpace: null,
      journeyPlan: null,
      generatedTrailDraft: null,
      fallbackUsed: false,
    ),
    createdAt: DateTime.now(),
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
