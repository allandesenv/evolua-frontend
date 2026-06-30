import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/auth/application/authenticated_session_reset.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/ads/application/monetization_access_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_summary.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_response.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/application/consciousness_timeline_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/notification/application/local_check_in_reminder_controller.dart';
import 'package:evolua_frontend/features/user/application/accessibility_preferences_controller.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/application/settings_privacy_preferences_controller.dart';
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
      await _flushSessionReset();

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
      await _flushSessionReset();
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
      await _flushSessionReset();

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

  test(
    'direct user switch clears authenticated cache before loading new user',
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
        _checkIn(userId: 'user-a', insight: 'Leitura do usuario A'),
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
      await _flushSessionReset();

      final firstCheckIns = await container.read(
        checkInControllerProvider.future,
      );
      expect(firstCheckIns.ownerUserId, 'user-a');

      profileRepository.profile = _profile(
        userId: 'user-b',
        displayName: 'Usuario B',
      );
      checkInRepository.item = _checkIn(
        userId: 'user-b',
        insight: 'Leitura do usuario B',
      );
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'b@evolua.test', password: '123456');
      await _flushSessionReset();

      final secondCheckIns = await container.read(
        checkInControllerProvider.future,
      );
      expect(secondCheckIns.ownerUserId, 'user-b');
      expect(
        secondCheckIns.latestCreatedCheckIn?.aiInsight?.insight,
        'Leitura do usuario B',
      );
    },
  );

  test(
    'session reset invalidates monetization preferences and reminder providers',
    () async {
      SharedPreferences.setMockInitialValues({});
      final observer = _DisposedProviderObserver();
      final scheduler = _FakeReminderScheduler();
      final container = _container(
        _FakeAuthRepository([
          _session(userId: 'user-a', email: 'a@evolua.test'),
        ]),
        _FakeProfileRepository(_profile(userId: 'user-a', displayName: 'A')),
        _FakeCheckInRepository(
          _checkIn(userId: 'user-a', insight: 'Leitura A'),
        ),
        observer: observer,
        reminderScheduler: scheduler,
      );
      addTearDown(container.dispose);

      container.read(authenticatedSessionResetObserverProvider);
      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@evolua.test', password: '123456');
      await _flushSessionReset();

      await container.read(monetizationAccessControllerProvider.future);
      await container.read(dailyCheckInReminderControllerProvider.future);
      await container.read(settingsPrivacyPreferencesControllerProvider.future);
      await container.read(accessibilityPreferencesControllerProvider.future);
      await container.read(trailStepResponsesProvider.future);
      await container.read(consciousnessTimelineProvider.future);
      await container.read(evolutionMirrorSummaryProvider.future);
      await container.read(
        trailStepResponseProvider((
          userId: 'user-a',
          trailId: 1,
          stepIndex: 0,
        )).future,
      );
      observer.disposedProviders.clear();

      await container.read(authControllerProvider.notifier).logout();
      await _flushSessionReset();

      expect(
        observer.disposedProviders,
        containsAll(<Object>[
          monetizationAccessControllerProvider,
          dailyCheckInReminderControllerProvider,
          settingsPrivacyPreferencesControllerProvider,
          accessibilityPreferencesControllerProvider,
          trailStepResponsesProvider,
          consciousnessTimelineProvider,
          evolutionMirrorSummaryProvider,
          trailStepResponseProvider((
            userId: 'user-a',
            trailId: 1,
            stepIndex: 0,
          )),
        ]),
      );
    },
  );

  test(
    'clears consciousness timeline and mirror summary when account changes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final authRepository = _FakeAuthRepository([
        _session(userId: 'user-a', email: 'a@evolua.test'),
        _session(userId: 'user-b', email: 'b@evolua.test'),
      ]);
      final apiAdapter = _FakeApiAdapter(
        timelineLabel: 'Linha do usuario A',
        stateLabel: 'estado-a',
        summaryMood: 'humor-a',
      );
      final observer = _DisposedProviderObserver();
      final container = _container(
        authRepository,
        _FakeProfileRepository(_profile(userId: 'user-a', displayName: 'A')),
        _FakeCheckInRepository(
          _checkIn(userId: 'user-a', insight: 'Leitura A'),
        ),
        observer: observer,
        apiDio: Dio()..httpClientAdapter = apiAdapter,
      );
      addTearDown(container.dispose);

      container.read(authenticatedSessionResetObserverProvider);
      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@evolua.test', password: '123456');
      await _flushSessionReset();

      final firstTimeline = await container.read(
        consciousnessTimelineProvider.future,
      );
      final firstSummary = await container.read(
        evolutionMirrorSummaryProvider.future,
      );
      expect(firstTimeline.items.single.title, 'Linha do usuario A');
      expect(firstSummary.dominantMood, 'humor-a');

      apiAdapter
        ..timelineLabel = 'Linha do usuario B'
        ..stateLabel = 'estado-b'
        ..summaryMood = 'humor-b';
      observer.disposedProviders.clear();

      await container.read(authControllerProvider.notifier).logout();
      await _flushSessionReset();

      expect(
        observer.disposedProviders,
        containsAll(<Object>[
          consciousnessTimelineProvider,
          evolutionMirrorSummaryProvider,
        ]),
      );
      expect(container.read(consciousnessTimelineProvider).isLoading, isTrue);
      expect(container.read(evolutionMirrorSummaryProvider).isLoading, isTrue);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'b@evolua.test', password: '123456');
      await _flushSessionReset();

      final secondTimeline = await container.read(
        consciousnessTimelineProvider.future,
      );
      final secondSummary = await container.read(
        evolutionMirrorSummaryProvider.future,
      );
      expect(secondTimeline.items.single.title, 'Linha do usuario B');
      expect(secondTimeline.items.single.identifiedState, 'estado-b');
      expect(secondTimeline.items.single.title, isNot('Linha do usuario A'));
      expect(secondSummary.dominantMood, 'humor-b');
      expect(secondSummary.dominantMood, isNot('humor-a'));
    },
  );

  test(
    'same-user refresh does not invalidate authenticated providers',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = _session(userId: 'user-a', email: 'a@evolua.test');
      final observer = _DisposedProviderObserver();
      final authRepository = _FakeAuthRepository([
        session,
      ], refreshSession: session);
      final container = _container(
        authRepository,
        _FakeProfileRepository(_profile(userId: 'user-a', displayName: 'A')),
        _FakeCheckInRepository(
          _checkIn(userId: 'user-a', insight: 'Leitura A'),
        ),
        observer: observer,
      );
      addTearDown(container.dispose);

      container.read(authenticatedSessionResetObserverProvider);
      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@evolua.test', password: '123456');
      await _flushSessionReset();

      await container.read(checkInControllerProvider.future);
      observer.disposedProviders.clear();

      await container.read(authControllerProvider.notifier).refreshSession();
      await _flushSessionReset();

      expect(
        observer.disposedProviders,
        isNot(contains(checkInControllerProvider)),
      );
    },
  );
}

ProviderContainer _container(
  AuthRepository authRepository,
  ProfileRepository profileRepository,
  CheckInRepository checkInRepository, {
  ProviderObserver? observer,
  DailyCheckInReminderScheduler? reminderScheduler,
  Dio? apiDio,
}) {
  final fakeApiDio = apiDio ?? _fakeApiDio();
  return ProviderContainer(
    observers: [?observer],
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      profileRepositoryProvider.overrideWithValue(profileRepository),
      checkInRepositoryProvider.overrideWithValue(checkInRepository),
      trailRepositoryProvider.overrideWithValue(_FakeTrailRepository()),
      authenticatedDioProvider(
        AppConfig.userBaseUrl,
      ).overrideWithValue(fakeApiDio),
      if (AppConfig.emotionalBaseUrl != AppConfig.userBaseUrl)
        authenticatedDioProvider(
          AppConfig.emotionalBaseUrl,
        ).overrideWithValue(fakeApiDio),
      if (reminderScheduler != null)
        dailyCheckInReminderSchedulerProvider.overrideWithValue(
          reminderScheduler,
        ),
    ],
  );
}

Dio _fakeApiDio() {
  return Dio()..httpClientAdapter = _FakeApiAdapter();
}

class _FakeApiAdapter implements HttpClientAdapter {
  _FakeApiAdapter({
    this.timelineLabel = 'Linha de teste',
    this.stateLabel = 'presenca',
    this.summaryMood = 'calma',
  });

  String timelineLabel;
  String stateLabel;
  String summaryMood;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/v1/profiles/me/privacy-settings' =>
        SettingsPrivacyPreferences.defaults().toJson(),
      '/v1/profiles/me/accessibility-settings' =>
        AccessibilityPreferences.defaults().toJson(),
      '/v1/check-ins/consciousness-timeline' => {
        'items': [
          {
            'checkInId': 1,
            'mood': 'calma',
            'energyLevel': 7,
            'title': timelineLabel,
            'insight': 'Parece um movimento de cuidado.',
            'identifiedState': stateLabel,
            'revealingQuestion': 'O que voce percebe agora?',
            'possibleNewState': 'Posso escolher presenca.',
            'microAction': 'Respirar por dois minutos.',
            'reflection': 'texto',
            'savedReading': false,
            'createdAt': DateTime(2026, 6, 8, 10).toIso8601String(),
          },
        ],
        'fullAccess': true,
        'premium': true,
        'rewardedAdAvailable': false,
      },
      '/v1/evolution-mirror/summary' => {
        'checkInCount': 1,
        'averageEnergy': 7,
        'energyTrend': 'sugere estabilidade recente',
        'dominantMood': summaryMood,
        'recurringStates': [
          {'label': stateLabel, 'count': 1},
        ],
        'emotionalThemes': const [],
        'revealingQuestions': const [],
        'microActions': const [],
        'progressSignal': 'Ainda ha poucos dados.',
        'disclaimer': 'Dados de apoio.',
      },
      _ => <String, Object?>{},
    };
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._loginSessions, {AuthSession? refreshSession})
    : _refreshSession = refreshSession;

  final List<AuthSession> _loginSessions;
  final AuthSession? _refreshSession;

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
    return _refreshSession ?? _loginSessions.first;
  }

  @override
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {}

  @override
  Future<void> resendEmailVerification({required String accessToken}) async {}
}

class _FakeTrailRepository implements TrailRepository {
  @override
  Future<Trail?> currentJourney() async => null;

  @override
  Future<List<TrailJourney>> listInProgressJourneys() async => const [];

  @override
  Future<TrailJourney> journey(int trailId) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> startJourney(int trailId) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> completeStep(int trailId, int stepIndex) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> updateVideoProgress({
    required int trailId,
    required int stepIndex,
    required int watchedSeconds,
    required int durationSeconds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TrailStepResponse?> stepResponse({
    required int trailId,
    required int stepIndex,
  }) async {
    return TrailStepResponse(
      id: 1,
      trailId: trailId,
      journeyKey: 'teste',
      stepIndex: stepIndex,
      stepTitle: 'Etapa',
      stepType: 'EXERCISE',
      responseText: 'Resposta',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<TrailStepResponse> saveStepResponse({
    required int trailId,
    required int stepIndex,
    required String responseText,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<TrailStepResponse>> listStepResponses({int limit = 20}) async {
    return const [];
  }

  @override
  Future<Trail> detail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<PaginatedResponse<TrailSummary>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? category,
    bool? premium,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Trail> create({
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Trail> update({
    required int id,
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(int id) {
    throw UnimplementedError();
  }
}

final class _DisposedProviderObserver extends ProviderObserver {
  final disposedProviders = <Object>[];

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    disposedProviders.add(context.provider);
  }
}

class _FakeReminderScheduler implements DailyCheckInReminderScheduler {
  @override
  Future<void> cancel() async {}

  @override
  Future<bool> consumePendingCheckInPayload() async => false;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {}
}

Future<void> _flushSessionReset() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
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
  Future<CheckIn> getById(int checkInId) async => item;

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
