import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/notification/application/local_check_in_reminder_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads disabled 08:00 defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scheduler = _FakeReminderScheduler();
    final engagementScheduler = _FakeEngagementScheduler();
    final container = _container(preferences, scheduler, engagementScheduler);
    addTearDown(container.dispose);

    final reminder = await container.read(
      dailyCheckInReminderControllerProvider.future,
    );

    expect(reminder.enabled, isFalse);
    expect(reminder.formattedTime, '08:00');
    expect(reminder.promptAnswered, isFalse);
    expect(scheduler.scheduledTimes, isEmpty);
  });

  test(
    'requests permission and schedules daily reminder when enabled',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final scheduler = _FakeReminderScheduler(permissionGranted: true);
      final engagementScheduler = _FakeEngagementScheduler();
      final container = _container(preferences, scheduler, engagementScheduler);
      addTearDown(container.dispose);

      final enabled = await container
          .read(dailyCheckInReminderControllerProvider.notifier)
          .requestPermissionAndEnable();
      final reminder = container
          .read(dailyCheckInReminderControllerProvider)
          .value;

      expect(enabled, isTrue);
      expect(reminder?.enabled, isTrue);
      expect(reminder?.promptAnswered, isTrue);
      expect(scheduler.permissionRequests, 1);
      expect(scheduler.scheduledTimes, ['08:00']);
      expect(engagementScheduler.cancelAllCount, 0);
    },
  );

  test(
    'denied permission keeps reminder disabled and prompt answered',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final scheduler = _FakeReminderScheduler(permissionGranted: false);
      final engagementScheduler = _FakeEngagementScheduler();
      final container = _container(preferences, scheduler, engagementScheduler);
      addTearDown(container.dispose);

      final enabled = await container
          .read(dailyCheckInReminderControllerProvider.notifier)
          .requestPermissionAndEnable();
      final reminder = container
          .read(dailyCheckInReminderControllerProvider)
          .value;

      expect(enabled, isFalse);
      expect(reminder?.enabled, isFalse);
      expect(reminder?.promptAnswered, isTrue);
      expect(scheduler.cancelCount, 1);
      expect(scheduler.scheduledTimes, isEmpty);
      expect(engagementScheduler.cancelAllCount, 1);
    },
  );

  test('disabling cancels scheduled reminder', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scheduler = _FakeReminderScheduler();
    final engagementScheduler = _FakeEngagementScheduler();
    final container = _container(preferences, scheduler, engagementScheduler);
    addTearDown(container.dispose);

    await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .requestPermissionAndEnable();
    await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .setEnabled(false);
    final reminder = container
        .read(dailyCheckInReminderControllerProvider)
        .value;

    expect(reminder?.enabled, isFalse);
    expect(scheduler.cancelCount, greaterThanOrEqualTo(1));
    expect(engagementScheduler.cancelAllCount, 1);
  });

  test('changing time reschedules only one daily reminder id', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scheduler = _FakeReminderScheduler();
    final engagementScheduler = _FakeEngagementScheduler();
    final container = _container(preferences, scheduler, engagementScheduler);
    addTearDown(container.dispose);

    await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .requestPermissionAndEnable();
    await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .updateReminderTime(hour: 7, minute: 30);
    final reminder = container
        .read(dailyCheckInReminderControllerProvider)
        .value;

    expect(reminder?.formattedTime, '07:30');
    expect(scheduler.scheduledTimes, ['08:00', '07:30']);
    expect(scheduler.cancelCount, 0);
  });

  test('consumes pending check-in payload from scheduler', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scheduler = _FakeReminderScheduler(pendingPayload: true);
    final engagementScheduler = _FakeEngagementScheduler();
    final container = _container(preferences, scheduler, engagementScheduler);
    addTearDown(container.dispose);

    final consumed = await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .consumePendingCheckInPayload();

    expect(consumed, isTrue);
    expect(await scheduler.consumePendingCheckInPayload(), isFalse);
  });

  test('engagement categories are disabled by default', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scheduler = _FakeReminderScheduler();
    final engagementScheduler = _FakeEngagementScheduler();
    final container = _container(preferences, scheduler, engagementScheduler);
    addTearDown(container.dispose);

    final scheduled = await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .scheduleEngagementCandidate(
          EngagementNotificationCandidate(
            type: EngagementNotificationType.futureMessageReady,
            scheduledAt: DateTime(2026, 1, 1, 9),
            title: 'Mensagem pronta',
            body: 'Você tem uma mensagem pronta.',
          ),
        );

    expect(scheduled, isFalse);
    expect(engagementScheduler.scheduled, isEmpty);
  });

  test('schedules enabled engagement category and records fatigue', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scheduler = _FakeReminderScheduler();
    final engagementScheduler = _FakeEngagementScheduler();
    final container = _container(preferences, scheduler, engagementScheduler);
    addTearDown(container.dispose);

    await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .requestPermissionAndEnable();
    await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .setEngagementCategoryEnabled(
          type: EngagementNotificationType.futureMessageReady,
          enabled: true,
        );

    final scheduled = await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .scheduleEngagementCandidate(
          EngagementNotificationCandidate(
            type: EngagementNotificationType.futureMessageReady,
            scheduledAt: DateTime(2026, 1, 1, 9),
            title: 'Mensagem pronta',
            body: 'Você tem uma mensagem pronta.',
          ),
          now: DateTime(2026, 1, 1, 8),
        );
    final secondSameDay = await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .scheduleEngagementCandidate(
          EngagementNotificationCandidate(
            type: EngagementNotificationType.futureMessageReady,
            scheduledAt: DateTime(2026, 1, 1, 10),
            title: 'Outra mensagem',
            body: 'Você tem outra mensagem pronta.',
          ),
          now: DateTime(2026, 1, 1, 9),
        );

    expect(scheduled, isTrue);
    expect(secondSameDay, isFalse);
    expect(
      engagementScheduler.scheduled.single.type,
      EngagementNotificationType.futureMessageReady,
    );
  });

  test(
    'payload JSON resolves only allowed routes and keeps legacy payload',
    () {
      final payload = EngagementNotificationPayload(
        type: EngagementNotificationType.futureMessageReady,
        targetRoute: '/future-messages',
        createdAt: DateTime.utc(2026),
      ).encode();
      final unsafePayload = EngagementNotificationPayload(
        type: EngagementNotificationType.futureMessageReady,
        targetRoute: 'https://example.com',
        createdAt: DateTime.utc(2026),
      ).encode();
      final checkInRoutePayload = EngagementNotificationPayload(
        type: EngagementNotificationType.dailyCheckIn,
        targetRoute: '/check-in',
        createdAt: DateTime.utc(2026),
      ).encode();

      expect(engagementRouteFromPayload(dailyCheckInReminderPayload), '/home');
      expect(engagementRouteFromPayload(payload), '/future-messages');
      expect(engagementRouteFromPayload(unsafePayload), '/home');
      expect(engagementRouteFromPayload(checkInRoutePayload), '/home');
      expect(engagementRouteFromPayload('{bad json'), '/home');
    },
  );
}

ProviderContainer _container(
  SharedPreferences preferences,
  DailyCheckInReminderScheduler scheduler,
  EngagementNotificationScheduler engagementScheduler,
) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) async => preferences),
      dailyCheckInReminderSchedulerProvider.overrideWithValue(scheduler),
      engagementNotificationSchedulerProvider.overrideWithValue(
        engagementScheduler,
      ),
    ],
  );
}

class _FakeReminderScheduler implements DailyCheckInReminderScheduler {
  _FakeReminderScheduler({
    this.permissionGranted = true,
    this.pendingPayload = false,
  });

  final bool permissionGranted;
  bool pendingPayload;
  int permissionRequests = 0;
  int cancelCount = 0;
  final List<String> scheduledTimes = [];

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  Future<bool> consumePendingCheckInPayload() async {
    final consumed = pendingPayload;
    pendingPayload = false;
    return consumed;
  }

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
