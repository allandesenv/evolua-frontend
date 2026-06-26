import 'dart:async';
import 'dart:typed_data';

import 'package:evolua_frontend/app/startup/app_startup_controller.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_response.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/features/social/domain/repositories/community_repository.dart';
import 'package:evolua_frontend/features/social/domain/repositories/social_post_repository.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('warms only local notifications, check-ins and current trail', () async {
    final harness = _Harness();
    final container = harness.container();
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final warmUp = container
        .read(appStartupControllerProvider)
        .warmUpForTesting(harness.session);
    await _flushMicrotasks();

    expect(harness.localNotificationCalls, 1);
    expect(harness.checkIns.listCalls, 1);
    expect(harness.trails.currentJourneyCalls, 1);
    expect(harness.profiles.getMeCalls, 0);
    expect(harness.communities.listCalls, 0);
    expect(harness.posts.listCalls, 0);
    var completed = false;
    unawaited(warmUp.then((_) => completed = true));
    await _flushMicrotasks();
    expect(completed, isFalse);

    harness.completeImmediateWork();
    await warmUp;
  });

  test(
    'deduplicates concurrent calls and waits for all immediate tasks',
    () async {
      final harness = _Harness();
      final container = harness.container();
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final first = container
          .read(appStartupControllerProvider)
          .warmUpForTesting(harness.session);
      final second = container
          .read(appStartupControllerProvider)
          .warmUpForTesting(harness.session);
      await _flushMicrotasks();

      expect(harness.localNotificationCalls, 1);
      expect(harness.checkIns.listCalls, 1);
      expect(harness.trails.currentJourneyCalls, 1);

      harness.localNotifications.complete();
      await _flushMicrotasks();
      var completed = false;
      unawaited(first.then((_) => completed = true));
      await _flushMicrotasks();
      expect(completed, isFalse);

      harness.checkIns.complete();
      await _flushMicrotasks();
      expect(completed, isFalse);

      harness.trails.complete();
      await Future.wait([first, second]);
    },
  );

  test('does not repeat after completion until reset', () async {
    final harness = _Harness();
    final container = harness.container();
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final controller = container.read(appStartupControllerProvider);
    final first = controller.warmUpForTesting(harness.session);
    harness.completeImmediateWork();
    await first;

    await controller.warmUpForTesting(harness.session);
    expect(harness.localNotificationCalls, 1);
    expect(harness.checkIns.listCalls, 1);
    expect(harness.trails.currentJourneyCalls, 1);

    controller.reset();
    harness.invalidateWarmUpProviders(container);
    harness.setSession(harness.session);
    harness.resetGates();
    final afterReset = controller.warmUpForTesting(harness.session);
    await _flushMicrotasks();
    expect(harness.localNotificationCalls, 2);
    expect(harness.checkIns.listCalls, 2);
    expect(harness.trails.currentJourneyCalls, 2);
    harness.completeImmediateWork();
    await afterReset;
  });

  test(
    'late completion from old generation does not block new session',
    () async {
      final harness = _Harness();
      final container = harness.container();
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final controller = container.read(appStartupControllerProvider);
      final oldWarmUp = controller.warmUpForTesting(harness.session);
      await _flushMicrotasks();
      expect(harness.checkIns.listCalls, 1);

      final nextSession = _session('user-b');
      harness.setSession(nextSession);
      controller.reset();
      harness.invalidateWarmUpProviders(container);
      harness.resetGates();

      final newWarmUp = controller.warmUpForTesting(nextSession);
      await _flushMicrotasks();
      expect(harness.checkIns.listCalls, 2);
      expect(harness.trails.currentJourneyCalls, 2);

      harness.completePreviousImmediateWork();
      unawaited(oldWarmUp);
      final duplicate = controller.warmUpForTesting(nextSession);
      await _flushMicrotasks();
      expect(harness.checkIns.listCalls, 2);

      harness.completeImmediateWork();
      await Future.wait([newWarmUp, duplicate]);
    },
  );
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _Harness {
  _Harness() {
    _authController = _FakeAuthController(session);
  }

  final AuthSession session = _session('user-a');
  final _FakeCheckInRepository checkIns = _FakeCheckInRepository();
  final _FakeTrailRepository trails = _FakeTrailRepository();
  final _FakeProfileRepository profiles = _FakeProfileRepository();
  final _FakeCommunityRepository communities = _FakeCommunityRepository();
  final _FakeSocialPostRepository posts = _FakeSocialPostRepository();
  late final _FakeAuthController _authController;
  Completer<void> localNotifications = Completer<void>();
  Completer<void>? _previousLocalNotifications;
  int localNotificationCalls = 0;

  ProviderContainer container() {
    return ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => _authController),
        appStartupControllerProvider.overrideWith(
          (ref) => AppStartupController(
            ref,
            allowWarmUpInTests: true,
            initializeLocalNotifications: () {
              localNotificationCalls++;
              return localNotifications.future;
            },
          ),
        ),
        profileRepositoryProvider.overrideWithValue(profiles),
        checkInRepositoryProvider.overrideWithValue(checkIns),
        trailRepositoryProvider.overrideWithValue(trails),
        communityRepositoryProvider.overrideWithValue(communities),
        socialPostRepositoryProvider.overrideWithValue(posts),
      ],
    );
  }

  void resetGates() {
    _previousLocalNotifications = localNotifications;
    localNotifications = Completer<void>();
    checkIns.resetGate();
    trails.resetGate();
  }

  void setSession(AuthSession? session) {
    _authController.setSession(session);
  }

  void invalidateWarmUpProviders(ProviderContainer container) {
    container
      ..invalidate(checkInControllerProvider)
      ..invalidate(currentJourneyTrailProvider);
  }

  void completeImmediateWork() {
    if (!localNotifications.isCompleted) {
      localNotifications.complete();
    }
    checkIns.complete();
    trails.complete();
  }

  void completePreviousImmediateWork() {
    final previousLocal = _previousLocalNotifications;
    if (previousLocal != null && !previousLocal.isCompleted) {
      previousLocal.complete();
    }
    checkIns.completePrevious();
    trails.completePrevious();
  }
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._session);

  AuthSession? _session;

  @override
  Future<AuthSession?> build() async => _session;

  void setSession(AuthSession? session) {
    _session = session;
    state = AsyncData(session);
  }
}

class _FakeCheckInRepository implements CheckInRepository {
  int listCalls = 0;
  Completer<PaginatedResponse<CheckIn>> _gate = Completer();
  Completer<PaginatedResponse<CheckIn>>? _previousGate;

  void resetGate() {
    _previousGate = _gate;
    _gate = Completer();
  }

  void complete() {
    if (!_gate.isCompleted) {
      _gate.complete(_page(const []));
    }
  }

  void completePrevious() {
    final previous = _previousGate;
    if (previous != null && !previous.isCompleted) {
      previous.complete(_page(const []));
    }
  }

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
  }) {
    listCalls++;
    return _gate.future;
  }

  @override
  Future<CheckIn> getById(int checkInId) {
    throw UnimplementedError();
  }

  @override
  Future<CheckIn> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> createRitualFromReading(
    int checkInId, {
    required DateTime localDate,
    required String type,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CheckIn> generateDeepReading(int checkInId, {String style = 'deep'}) {
    throw UnimplementedError();
  }

  @override
  Future<CheckIn> saveReading(int checkInId) {
    throw UnimplementedError();
  }
}

class _FakeTrailRepository implements TrailRepository {
  int currentJourneyCalls = 0;
  Completer<Trail?> _gate = Completer();
  Completer<Trail?>? _previousGate;

  void resetGate() {
    _previousGate = _gate;
    _gate = Completer();
  }

  void complete() {
    if (!_gate.isCompleted) {
      _gate.complete(null);
    }
  }

  void completePrevious() {
    final previous = _previousGate;
    if (previous != null && !previous.isCompleted) {
      previous.complete(null);
    }
  }

  @override
  Future<Trail?> currentJourney() {
    currentJourneyCalls++;
    return _gate.future;
  }

  @override
  Future<List<TrailJourney>> listInProgressJourneys() {
    throw UnimplementedError();
  }

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
  }) {
    throw UnimplementedError();
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
  Future<List<TrailStepResponse>> listStepResponses({int limit = 20}) {
    throw UnimplementedError();
  }

  @override
  Future<PaginatedResponse<Trail>> list({
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

class _FakeProfileRepository implements ProfileRepository {
  int getMeCalls = 0;

  @override
  Future<Profile?> getMe() async {
    getMeCalls++;
    return null;
  }

  @override
  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) {
    throw UnimplementedError();
  }
}

class _FakeCommunityRepository implements CommunityRepository {
  int listCalls = 0;

  @override
  Future<PaginatedResponse<Community>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? visibility,
    String? category,
    bool? joined,
  }) async {
    listCalls++;
    return _page(const []);
  }

  @override
  Future<Community> create({
    required String name,
    required String slug,
    required String description,
    required String visibility,
    required String category,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Community> join(String id) {
    throw UnimplementedError();
  }

  @override
  Future<Community> leave(String id) {
    throw UnimplementedError();
  }
}

class _FakeSocialPostRepository implements SocialPostRepository {
  int listCalls = 0;

  @override
  Future<PaginatedResponse<SocialPost>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? community,
    String? visibility,
    bool? mine,
  }) async {
    listCalls++;
    return _page(const []);
  }

  @override
  Future<SocialPost> create({
    required String content,
    required String community,
    required String visibility,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) {
    throw UnimplementedError();
  }

  @override
  Future<SocialPost> update({required String id, required String content}) {
    throw UnimplementedError();
  }
}

PaginatedResponse<T> _page<T>(List<T> items) {
  return PaginatedResponse<T>(
    items: items,
    page: 0,
    size: items.length,
    totalItems: items.length,
    totalPages: 1,
    hasNext: false,
    hasPrevious: false,
    sortBy: 'createdAt',
    sortDir: 'desc',
    filters: const {},
  );
}

AuthSession _session(String userId) {
  return AuthSession(
    userId: userId,
    email: '$userId@evolua.test',
    roles: const ['ROLE_USER'],
    accessToken: 'test-token',
  );
}
