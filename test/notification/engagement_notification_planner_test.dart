import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_progress.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/notification/application/engagement_notification_planner.dart';
import 'package:evolua_frontend/features/notification/application/local_check_in_reminder_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('does not schedule when engagement preferences are disabled', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scheduler = _FakeReminderScheduler();
    final engagementScheduler = _FakeEngagementScheduler();
    final container = _container(preferences, scheduler, engagementScheduler);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await container
        .read(engagementNotificationPlannerProvider)
        .onTrailJourneyChanged(_journey());

    expect(engagementScheduler.scheduled, isEmpty);
    expect(scheduler.scheduledTimes, isEmpty);
  });

  test(
    'reschedules daily check-in through legacy scheduler after check-in',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final scheduler = _FakeReminderScheduler(permissionGranted: true);
      final engagementScheduler = _FakeEngagementScheduler();
      final container = _container(preferences, scheduler, engagementScheduler);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      await container
          .read(dailyCheckInReminderControllerProvider.notifier)
          .requestPermissionAndEnableInitialEngagementNotifications();

      await container
          .read(engagementNotificationPlannerProvider)
          .onCheckInCreated(_checkIn(id: 1));

      expect(scheduler.scheduledTimes, ['08:00', '08:00']);
      expect(
        engagementScheduler.scheduled.where(
          (item) => item.type == EngagementNotificationType.dailyCheckIn,
        ),
        isEmpty,
      );
    },
  );

  test('schedules trail resume once for the same progress update', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scheduler = _FakeReminderScheduler(permissionGranted: true);
    final engagementScheduler = _FakeEngagementScheduler();
    final container = _container(preferences, scheduler, engagementScheduler);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .requestPermissionAndEnableInitialEngagementNotifications();

    final journey = _journey(updatedAt: DateTime(2026, 1, 1, 10));
    await container
        .read(engagementNotificationPlannerProvider)
        .onTrailJourneyChanged(journey);
    await container
        .read(engagementNotificationPlannerProvider)
        .onTrailJourneyChanged(journey);

    expect(engagementScheduler.scheduled, hasLength(1));
    expect(
      engagementScheduler.scheduled.single.type,
      EngagementNotificationType.trailResume,
    );
    expect(engagementScheduler.scheduled.single.scheduledAt.hour, 10);
  });

  test('cancels trail resume for completed journey', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scheduler = _FakeReminderScheduler(permissionGranted: true);
    final engagementScheduler = _FakeEngagementScheduler();
    final container = _container(preferences, scheduler, engagementScheduler);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .requestPermissionAndEnableInitialEngagementNotifications();

    await container
        .read(engagementNotificationPlannerProvider)
        .onTrailJourneyChanged(_journey(completed: true));

    expect(engagementScheduler.cancelled, [
      EngagementNotificationType.trailResume,
    ]);
    expect(engagementScheduler.scheduled, isEmpty);
  });

  test(
    'schedules weekly mirror from already loaded check-ins once per week',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final scheduler = _FakeReminderScheduler(permissionGranted: true);
      final engagementScheduler = _FakeEngagementScheduler();
      final container = _container(
        preferences,
        scheduler,
        engagementScheduler,
        checkInState: _historyState([
          _checkIn(
            id: 1,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          _checkIn(
            id: 2,
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ]),
      );
      addTearDown(container.dispose);
      final session = await container.read(authControllerProvider.future);
      await container.read(checkInControllerProvider.future);
      await container
          .read(dailyCheckInReminderControllerProvider.notifier)
          .requestPermissionAndEnableInitialEngagementNotifications();

      await container
          .read(engagementNotificationPlannerProvider)
          .evaluateAfterWarmUp(session!);
      await container
          .read(engagementNotificationPlannerProvider)
          .evaluateAfterWarmUp(session);

      final weekly = engagementScheduler.scheduled.where(
        (item) => item.type == EngagementNotificationType.weeklyMirror,
      );
      expect(weekly, hasLength(1));
    },
  );

  test(
    'corrupted planner state is ignored without enabling categories',
    () async {
      SharedPreferences.setMockInitialValues({
        '$engagementNotificationScheduleStateStorageKey.user-123': '{bad json',
      });
      final preferences = await SharedPreferences.getInstance();
      final scheduler = _FakeReminderScheduler();
      final engagementScheduler = _FakeEngagementScheduler();
      final container = _container(preferences, scheduler, engagementScheduler);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container
          .read(engagementNotificationPlannerProvider)
          .onTrailJourneyChanged(_journey());

      final engagement = await container
          .read(dailyCheckInReminderControllerProvider.notifier)
          .engagementPreferences();
      expect(engagement.enabled, isFalse);
      expect(engagementScheduler.scheduled, isEmpty);
    },
  );
}

ProviderContainer _container(
  SharedPreferences preferences,
  DailyCheckInReminderScheduler scheduler,
  EngagementNotificationScheduler engagementScheduler, {
  CheckInHistoryState? checkInState,
}) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) async => preferences),
      authControllerProvider.overrideWith(
        () => _FakeAuthController(_session()),
      ),
      dailyCheckInReminderSchedulerProvider.overrideWithValue(scheduler),
      engagementNotificationSchedulerProvider.overrideWithValue(
        engagementScheduler,
      ),
      if (checkInState != null)
        checkInControllerProvider.overrideWith(
          () => _FakeCheckInController(checkInState),
        ),
    ],
  );
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}

class _FakeCheckInController extends CheckInController {
  _FakeCheckInController(this._state);

  final CheckInHistoryState _state;

  @override
  Future<CheckInHistoryState> build() async => _state;
}

class _FakeReminderScheduler implements DailyCheckInReminderScheduler {
  _FakeReminderScheduler({this.permissionGranted = true});

  final bool permissionGranted;
  int permissionRequests = 0;
  int cancelCount = 0;
  final List<String> scheduledTimes = [];

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  Future<bool> consumePendingCheckInPayload() async => false;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduledTimes.add(
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    );
  }
}

class _FakeEngagementScheduler implements EngagementNotificationScheduler {
  int cancelAllCount = 0;
  final cancelled = <EngagementNotificationType>[];
  final scheduled = <EngagementNotificationCandidate>[];

  @override
  Future<void> cancel(EngagementNotificationType type) async {
    cancelled.add(type);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
  }

  @override
  Future<void> schedule(EngagementNotificationCandidate candidate) async {
    scheduled.add(candidate);
  }
}

AuthSession _session() {
  return const AuthSession(
    userId: 'user-123',
    email: 'user@example.com',
    roles: [],
    accessToken: 'header.payload.signature',
  );
}

CheckIn _checkIn({required int id, DateTime? createdAt}) {
  return CheckIn(
    id: id,
    userId: 'user-123',
    mood: 'calm',
    reflection: '',
    energyLevel: 4,
    recommendedPractice: '',
    aiInsight: null,
    createdAt: createdAt ?? DateTime(2026, 1, 1, 8),
  );
}

CheckInHistoryState _historyState(List<CheckIn> items) {
  return CheckInHistoryState(
    result: PaginatedResponse(
      items: items,
      page: 0,
      size: 6,
      totalItems: items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: 'createdAt',
      sortDir: 'desc',
      filters: const {},
    ),
    selectedGrouping: 'monthly',
    ownerUserId: 'user-123',
    latestCreatedCheckIn: items.firstOrNull,
  );
}

TrailJourney _journey({DateTime? updatedAt, bool completed = false}) {
  final steps = [
    TrailJourneyStep(
      index: 0,
      title: 'Respirar',
      type: 'EXERCISE',
      summary: '',
      content: '',
      status: completed ? 'completed' : 'current',
      estimatedMinutes: 2,
      mediaLinks: const [],
    ),
  ];
  final progressUpdatedAt = updatedAt ?? DateTime(2026, 1, 1, 10);
  return TrailJourney(
    trail: _trail(),
    steps: steps,
    progress: TrailProgress(
      currentStepIndex: 0,
      completedStepIndexes: completed ? const [0] : const [],
      startedAt: DateTime(2026, 1, 1, 9),
      updatedAt: progressUpdatedAt,
      completedAt: completed ? progressUpdatedAt : null,
    ),
    progressPercent: completed ? 100 : 0,
    nextStep: completed ? null : steps.first,
  );
}

Trail _trail() {
  return Trail(
    id: 10,
    userId: 'user-123',
    title: 'Trilha',
    summary: 'Resumo',
    content: '',
    category: 'clareza',
    premium: false,
    privateTrail: false,
    activeJourney: true,
    generatedByAi: false,
    journeyKey: 'clareza',
    sourceStyle: 'briefing',
    accessible: true,
    mediaLinks: const [],
    steps: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}
