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
    final container = _container(preferences, scheduler);
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
      final container = _container(preferences, scheduler);
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
    },
  );

  test(
    'denied permission keeps reminder disabled and prompt answered',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final scheduler = _FakeReminderScheduler(permissionGranted: false);
      final container = _container(preferences, scheduler);
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
    },
  );

  test('disabling cancels scheduled reminder', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scheduler = _FakeReminderScheduler();
    final container = _container(preferences, scheduler);
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
  });

  test('changing time reschedules only one daily reminder id', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scheduler = _FakeReminderScheduler();
    final container = _container(preferences, scheduler);
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
    final container = _container(preferences, scheduler);
    addTearDown(container.dispose);

    final consumed = await container
        .read(dailyCheckInReminderControllerProvider.notifier)
        .consumePendingCheckInPayload();

    expect(consumed, isTrue);
    expect(await scheduler.consumePendingCheckInPayload(), isFalse);
  });
}

ProviderContainer _container(
  SharedPreferences preferences,
  DailyCheckInReminderScheduler scheduler,
) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) async => preferences),
      dailyCheckInReminderSchedulerProvider.overrideWithValue(scheduler),
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
