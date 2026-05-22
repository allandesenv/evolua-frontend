import 'dart:async';
import 'dart:convert';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const dailyCheckInReminderStorageKey = 'evolua.daily_checkin_reminder.v1';
const dailyCheckInReminderPendingPayloadKey =
    'evolua.daily_checkin_reminder.pending_payload.v1';
const dailyCheckInReminderPayload = 'check-in';

class DailyCheckInReminderPreferences {
  const DailyCheckInReminderPreferences({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.promptAnswered,
  });

  factory DailyCheckInReminderPreferences.defaults() {
    return const DailyCheckInReminderPreferences(
      enabled: false,
      hour: 8,
      minute: 0,
      promptAnswered: false,
    );
  }

  factory DailyCheckInReminderPreferences.fromJson(Map<String, dynamic> json) {
    final defaults = DailyCheckInReminderPreferences.defaults();
    return DailyCheckInReminderPreferences(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
      hour: _readTimePart(json['hour'], defaults.hour, max: 23),
      minute: _readTimePart(json['minute'], defaults.minute, max: 59),
      promptAnswered: json['promptAnswered'] is bool
          ? json['promptAnswered'] as bool
          : false,
    );
  }

  final bool enabled;
  final int hour;
  final int minute;
  final bool promptAnswered;

  String get formattedTime {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  DailyCheckInReminderPreferences copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    bool? promptAnswered,
  }) {
    return DailyCheckInReminderPreferences(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      promptAnswered: promptAnswered ?? this.promptAnswered,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'hour': hour,
      'minute': minute,
      'promptAnswered': promptAnswered,
    };
  }

  static int _readTimePart(Object? value, int fallback, {required int max}) {
    if (value is! num) {
      return fallback;
    }
    final parsed = value.toInt();
    return parsed >= 0 && parsed <= max ? parsed : fallback;
  }
}

abstract class DailyCheckInReminderScheduler {
  Future<bool> requestPermission();
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  });
  Future<void> cancel();
  Future<bool> consumePendingCheckInPayload();
}

final dailyCheckInReminderSchedulerProvider =
    Provider<DailyCheckInReminderScheduler>((ref) {
      return const FlutterDailyCheckInReminderScheduler();
    });

final dailyCheckInReminderControllerProvider =
    AsyncNotifierProvider<
      DailyCheckInReminderController,
      DailyCheckInReminderPreferences
    >(DailyCheckInReminderController.new);

final dailyCheckInReminderTapProvider = StreamProvider<String>((ref) {
  return LocalCheckInReminderNotifications.tapStream;
});

class DailyCheckInReminderController
    extends AsyncNotifier<DailyCheckInReminderPreferences> {
  @override
  Future<DailyCheckInReminderPreferences> build() async {
    final preferences = await _load();
    if (preferences.enabled) {
      await _schedule(preferences);
    }
    return preferences;
  }

  Future<bool> requestPermissionAndEnable() async {
    final current = state.value ?? await _load();
    state = AsyncData(current);
    final allowed = await ref
        .read(dailyCheckInReminderSchedulerProvider)
        .requestPermission();
    final updated = current.copyWith(enabled: allowed, promptAnswered: true);
    await _save(updated);
    if (allowed) {
      await _schedule(updated);
    } else {
      await ref.read(dailyCheckInReminderSchedulerProvider).cancel();
    }
    state = AsyncData(updated);
    return allowed;
  }

  Future<void> dismissPrompt() async {
    final current = state.value ?? await _load();
    final updated = current.copyWith(promptAnswered: true);
    await _save(updated);
    state = AsyncData(updated);
  }

  Future<bool> setEnabled(bool enabled) async {
    if (enabled) {
      return requestPermissionAndEnable();
    }

    final current = state.value ?? await _load();
    final updated = current.copyWith(enabled: false, promptAnswered: true);
    await _save(updated);
    await ref.read(dailyCheckInReminderSchedulerProvider).cancel();
    state = AsyncData(updated);
    return true;
  }

  Future<void> updateReminderTime({
    required int hour,
    required int minute,
  }) async {
    final current = state.value ?? await _load();
    final updated = current.copyWith(hour: hour, minute: minute);
    await _save(updated);
    if (updated.enabled) {
      await _schedule(updated);
    }
    state = AsyncData(updated);
  }

  Future<bool> consumePendingCheckInPayload() {
    return ref
        .read(dailyCheckInReminderSchedulerProvider)
        .consumePendingCheckInPayload();
  }

  Future<DailyCheckInReminderPreferences> _load() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final raw = preferences.getString(dailyCheckInReminderStorageKey);
    if (raw == null || raw.isEmpty) {
      return DailyCheckInReminderPreferences.defaults();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return DailyCheckInReminderPreferences.fromJson(decoded);
      }
      return DailyCheckInReminderPreferences.defaults();
    } catch (_) {
      return DailyCheckInReminderPreferences.defaults();
    }
  }

  Future<void> _save(DailyCheckInReminderPreferences reminder) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setString(
      dailyCheckInReminderStorageKey,
      jsonEncode(reminder.toJson()),
    );
  }

  Future<void> _schedule(DailyCheckInReminderPreferences preferences) {
    return ref
        .read(dailyCheckInReminderSchedulerProvider)
        .scheduleDaily(
          hour: preferences.hour,
          minute: preferences.minute,
          title: 'Bom dia 🌱',
          body:
              'Como você está começando o dia? Registre seu momento no Evolua.',
          payload: dailyCheckInReminderPayload,
        );
  }
}

class FlutterDailyCheckInReminderScheduler
    implements DailyCheckInReminderScheduler {
  const FlutterDailyCheckInReminderScheduler();

  @override
  Future<bool> requestPermission() {
    return LocalCheckInReminderNotifications.requestPermission();
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) {
    return LocalCheckInReminderNotifications.scheduleDaily(
      hour: hour,
      minute: minute,
      title: title,
      body: body,
      payload: payload,
    );
  }

  @override
  Future<void> cancel() {
    return LocalCheckInReminderNotifications.cancelDailyReminder();
  }

  @override
  Future<bool> consumePendingCheckInPayload() {
    return LocalCheckInReminderNotifications.consumePendingCheckInPayload();
  }
}

class LocalCheckInReminderNotifications {
  const LocalCheckInReminderNotifications._();

  static const _notificationId = 8001;
  static const _channelId = 'daily_checkin_reminder';
  static const _channelName = 'Lembrete diário de check-in';
  static const _channelDescription =
      'Lembretes locais para registrar seu momento no Evolua.';
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final StreamController<String> _tapController =
      StreamController<String>.broadcast();
  static bool _initialized = false;

  static Stream<String> get tapStream => _tapController.stream;

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) {
      return;
    }
    _initialized = true;
    await _configureLocalTimezone();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackgroundHandler,
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        response?.payload == dailyCheckInReminderPayload) {
      await _storePendingPayload(dailyCheckInReminderPayload);
    }
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) {
      return false;
    }
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  static Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    await cancelDailyReminder();
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  static Future<void> cancelDailyReminder() {
    return _plugin.cancel(id: _notificationId);
  }

  static Future<bool> consumePendingCheckInPayload() async {
    final preferences = await SharedPreferences.getInstance();
    final payload = preferences.getString(
      dailyCheckInReminderPendingPayloadKey,
    );
    if (payload != dailyCheckInReminderPayload) {
      return false;
    }
    await preferences.remove(dailyCheckInReminderPendingPayloadKey);
    return true;
  }

  static Future<void> _configureLocalTimezone() async {
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == dailyCheckInReminderPayload) {
      _storePendingPayload(dailyCheckInReminderPayload);
    }
  }

  static Future<void> _storePendingPayload(String payload) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(dailyCheckInReminderPendingPayloadKey, payload);
    _tapController.add(payload);
  }
}

@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse response) {
  if (response.payload == dailyCheckInReminderPayload) {
    LocalCheckInReminderNotifications._storePendingPayload(
      dailyCheckInReminderPayload,
    );
  }
}
