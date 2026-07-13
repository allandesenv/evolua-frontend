import 'dart:async';
import 'dart:convert';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations_en.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations_pt.dart';
import 'package:evolua_frontend/l10n/locale_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
const engagementNotificationPreferencesStorageKey =
    'evolua.engagement_notifications.preferences.v1';
const engagementNotificationFatigueStorageKey =
    'evolua.engagement_notifications.fatigue.v1';

enum EngagementNotificationType {
  dailyCheckIn(
    storageKey: 'dailyCheckIn',
    notificationId: 8001,
    targetRoute: '/home',
  ),
  trailResume(
    storageKey: 'trailResume',
    notificationId: 8010,
    targetRoute: '/home',
  ),
  futureMessageReady(
    storageKey: 'futureMessageReady',
    notificationId: 8020,
    targetRoute: '/future-messages',
  ),
  morningRitual(
    storageKey: 'morningRitual',
    notificationId: 8030,
    targetRoute: '/daily-ritual?type=morning',
  ),
  eveningRitual(
    storageKey: 'eveningRitual',
    notificationId: 8031,
    targetRoute: '/daily-ritual?type=evening',
  ),
  weeklyMirror(
    storageKey: 'weeklyMirror',
    notificationId: 8040,
    targetRoute: '/home?profileSection=evolutionMirror',
  ),
  gentleComeback(
    storageKey: 'gentleComeback',
    notificationId: 8050,
    targetRoute: '/home',
  );

  const EngagementNotificationType({
    required this.storageKey,
    required this.notificationId,
    required this.targetRoute,
  });

  final String storageKey;
  final int notificationId;
  final String targetRoute;

  static EngagementNotificationType? fromStorageKey(String? value) {
    for (final type in EngagementNotificationType.values) {
      if (type.storageKey == value) {
        return type;
      }
    }
    return null;
  }
}

class EngagementNotificationPreferences {
  const EngagementNotificationPreferences({
    required this.enabled,
    required this.categories,
  });

  factory EngagementNotificationPreferences.defaults() {
    return EngagementNotificationPreferences(
      enabled: false,
      categories: {
        for (final type in EngagementNotificationType.values) type: false,
      },
    );
  }

  factory EngagementNotificationPreferences.fromJson(
    Map<String, dynamic> json,
  ) {
    final defaults = EngagementNotificationPreferences.defaults();
    final rawCategories = json['categories'];
    final categories = Map<EngagementNotificationType, bool>.from(
      defaults.categories,
    );
    if (rawCategories is Map) {
      for (final entry in rawCategories.entries) {
        final type = EngagementNotificationType.fromStorageKey(
          entry.key?.toString(),
        );
        if (type != null && entry.value is bool) {
          categories[type] = entry.value as bool;
        }
      }
    }
    return EngagementNotificationPreferences(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
      categories: categories,
    );
  }

  final bool enabled;
  final Map<EngagementNotificationType, bool> categories;

  bool isEnabled(EngagementNotificationType type) {
    return enabled && (categories[type] ?? false);
  }

  EngagementNotificationPreferences copyWith({
    bool? enabled,
    Map<EngagementNotificationType, bool>? categories,
  }) {
    return EngagementNotificationPreferences(
      enabled: enabled ?? this.enabled,
      categories: categories ?? this.categories,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'categories': {
        for (final entry in categories.entries)
          entry.key.storageKey: entry.value,
      },
    };
  }
}

class EngagementNotificationPayload {
  const EngagementNotificationPayload({
    required this.type,
    required this.targetRoute,
    required this.createdAt,
    this.metadata = const {},
  });

  factory EngagementNotificationPayload.fromJson(Map<String, dynamic> json) {
    final type = EngagementNotificationType.fromStorageKey(
      json['type']?.toString(),
    );
    if (type == null) {
      throw const FormatException('Invalid engagement notification type.');
    }
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (createdAt == null) {
      throw const FormatException('Invalid engagement notification date.');
    }
    final metadata = json['metadata'];
    return EngagementNotificationPayload(
      type: type,
      targetRoute: _safeEngagementRoute(
        json['targetRoute']?.toString(),
        fallback: type.targetRoute,
      ),
      createdAt: createdAt.toUtc(),
      metadata: metadata is Map
          ? Map<String, dynamic>.from(metadata)
          : const <String, dynamic>{},
    );
  }

  final EngagementNotificationType type;
  final String targetRoute;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  String encode() => jsonEncode(toJson());

  Map<String, dynamic> toJson() {
    return {
      'type': type.storageKey,
      'targetRoute': _safeEngagementRoute(
        targetRoute,
        fallback: type.targetRoute,
      ),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'metadata': metadata,
    };
  }
}

class EngagementNotificationCandidate {
  EngagementNotificationCandidate({
    required this.type,
    required this.scheduledAt,
    required this.title,
    required this.body,
    String? targetRoute,
    this.metadata = const {},
  }) : targetRoute = targetRoute ?? type.targetRoute;

  final EngagementNotificationType type;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String targetRoute;
  final Map<String, dynamic> metadata;
}

class EngagementNotificationFatigueState {
  const EngagementNotificationFatigueState({
    required this.dayKey,
    required this.weekKey,
    required this.dailyCount,
    required this.weeklyCount,
    required this.lastScheduledAt,
    required this.lastShownType,
    required this.lastPeriodKey,
  });

  factory EngagementNotificationFatigueState.empty() {
    return const EngagementNotificationFatigueState(
      dayKey: '',
      weekKey: '',
      dailyCount: 0,
      weeklyCount: 0,
      lastScheduledAt: null,
      lastShownType: null,
      lastPeriodKey: null,
    );
  }

  factory EngagementNotificationFatigueState.fromJson(
    Map<String, dynamic> json,
  ) {
    return EngagementNotificationFatigueState(
      dayKey: json['dayKey']?.toString() ?? '',
      weekKey: json['weekKey']?.toString() ?? '',
      dailyCount: json['dailyCount'] is num
          ? (json['dailyCount'] as num).toInt()
          : 0,
      weeklyCount: json['weeklyCount'] is num
          ? (json['weeklyCount'] as num).toInt()
          : 0,
      lastScheduledAt: DateTime.tryParse(
        json['lastScheduledAt']?.toString() ?? '',
      ),
      lastShownType: EngagementNotificationType.fromStorageKey(
        json['lastShownType']?.toString(),
      ),
      lastPeriodKey: json['lastPeriodKey']?.toString(),
    );
  }

  final String dayKey;
  final String weekKey;
  final int dailyCount;
  final int weeklyCount;
  final DateTime? lastScheduledAt;
  final EngagementNotificationType? lastShownType;
  final String? lastPeriodKey;

  bool canSchedule(DateTime now, {DateTime? lastCheckInAt}) {
    final normalized = _normalizedFor(now);
    if (normalized.dailyCount >= 1 || normalized.weeklyCount >= 3) {
      return false;
    }
    if (normalized.lastPeriodKey == _periodKey(now)) {
      return false;
    }
    if (lastCheckInAt != null &&
        now.difference(lastCheckInAt).inHours >= 0 &&
        now.difference(lastCheckInAt).inHours < 4) {
      return false;
    }
    return true;
  }

  EngagementNotificationFatigueState record(
    EngagementNotificationType type,
    DateTime now,
  ) {
    final normalized = _normalizedFor(now);
    return EngagementNotificationFatigueState(
      dayKey: _dayKey(now),
      weekKey: _weekKey(now),
      dailyCount: normalized.dailyCount + 1,
      weeklyCount: normalized.weeklyCount + 1,
      lastScheduledAt: now.toUtc(),
      lastShownType: type,
      lastPeriodKey: _periodKey(now),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayKey': dayKey,
      'weekKey': weekKey,
      'dailyCount': dailyCount,
      'weeklyCount': weeklyCount,
      'lastScheduledAt': lastScheduledAt?.toUtc().toIso8601String(),
      'lastShownType': lastShownType?.storageKey,
      'lastPeriodKey': lastPeriodKey,
    };
  }

  EngagementNotificationFatigueState _normalizedFor(DateTime now) {
    final currentDayKey = _dayKey(now);
    final currentWeekKey = _weekKey(now);
    return EngagementNotificationFatigueState(
      dayKey: currentDayKey,
      weekKey: currentWeekKey,
      dailyCount: dayKey == currentDayKey ? dailyCount : 0,
      weeklyCount: weekKey == currentWeekKey ? weeklyCount : 0,
      lastScheduledAt: lastScheduledAt,
      lastShownType: lastShownType,
      lastPeriodKey: lastPeriodKey,
    );
  }
}

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

abstract class EngagementNotificationScheduler {
  Future<void> schedule(EngagementNotificationCandidate candidate);
  Future<void> cancel(EngagementNotificationType type);
  Future<void> cancelAll();
}

final dailyCheckInReminderSchedulerProvider =
    Provider<DailyCheckInReminderScheduler>((ref) {
      return const FlutterDailyCheckInReminderScheduler();
    });

final engagementNotificationSchedulerProvider =
    Provider<EngagementNotificationScheduler>((ref) {
      return const FlutterEngagementNotificationScheduler();
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
    final engagement = await _loadEngagementPreferences();
    await _saveEngagementPreferences(
      engagement.copyWith(
        enabled: allowed,
        categories: {
          ...engagement.categories,
          EngagementNotificationType.dailyCheckIn: allowed,
        },
      ),
    );
    if (allowed) {
      await _schedule(updated);
    } else {
      await ref.read(dailyCheckInReminderSchedulerProvider).cancel();
      await ref.read(engagementNotificationSchedulerProvider).cancelAll();
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
    final engagement = await _loadEngagementPreferences();
    await _saveEngagementPreferences(
      engagement.copyWith(
        enabled: false,
        categories: {
          ...engagement.categories,
          EngagementNotificationType.dailyCheckIn: false,
        },
      ),
    );
    await ref.read(dailyCheckInReminderSchedulerProvider).cancel();
    await ref.read(engagementNotificationSchedulerProvider).cancelAll();
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

  Future<EngagementNotificationPreferences> engagementPreferences() {
    return _loadEngagementPreferences();
  }

  Future<void> setEngagementCategoryEnabled({
    required EngagementNotificationType type,
    required bool enabled,
  }) async {
    final current = await _loadEngagementPreferences();
    await _saveEngagementPreferences(
      current.copyWith(categories: {...current.categories, type: enabled}),
    );
    if (!enabled) {
      await ref.read(engagementNotificationSchedulerProvider).cancel(type);
    }
  }

  Future<bool> scheduleEngagementCandidate(
    EngagementNotificationCandidate candidate, {
    DateTime? now,
    DateTime? lastCheckInAt,
  }) async {
    final engagement = await _loadEngagementPreferences();
    if (!engagement.isEnabled(candidate.type)) {
      return false;
    }
    final currentTime = now ?? DateTime.now();
    final fatigue = await _loadFatigueState();
    if (!fatigue.canSchedule(currentTime, lastCheckInAt: lastCheckInAt)) {
      return false;
    }
    await ref.read(engagementNotificationSchedulerProvider).schedule(candidate);
    await _saveFatigueState(fatigue.record(candidate.type, currentTime));
    return true;
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

  Future<EngagementNotificationPreferences> _loadEngagementPreferences() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final raw = preferences.getString(
      engagementNotificationPreferencesStorageKey,
    );
    if (raw == null || raw.isEmpty) {
      return EngagementNotificationPreferences.defaults();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return EngagementNotificationPreferences.fromJson(decoded);
      }
    } catch (_) {
      // Invalid local preferences must not enable notifications.
    }
    return EngagementNotificationPreferences.defaults();
  }

  Future<void> _saveEngagementPreferences(
    EngagementNotificationPreferences engagement,
  ) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setString(
      engagementNotificationPreferencesStorageKey,
      jsonEncode(engagement.toJson()),
    );
  }

  Future<EngagementNotificationFatigueState> _loadFatigueState() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final raw = preferences.getString(engagementNotificationFatigueStorageKey);
    if (raw == null || raw.isEmpty) {
      return EngagementNotificationFatigueState.empty();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return EngagementNotificationFatigueState.fromJson(decoded);
      }
    } catch (_) {
      // Invalid fatigue data falls back to conservative empty state.
    }
    return EngagementNotificationFatigueState.empty();
  }

  Future<void> _saveFatigueState(
    EngagementNotificationFatigueState fatigue,
  ) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setString(
      engagementNotificationFatigueStorageKey,
      jsonEncode(fatigue.toJson()),
    );
  }

  Future<void> _schedule(DailyCheckInReminderPreferences preferences) async {
    final l10n = await _notificationLocalizations();
    return ref
        .read(dailyCheckInReminderSchedulerProvider)
        .scheduleDaily(
          hour: preferences.hour,
          minute: preferences.minute,
          title: l10n.checkInReminderMorningTitle,
          body: l10n.checkInReminderMorningMessage,
          payload: dailyCheckInReminderPayload,
        );
  }

  Future<AppLocalizations> _notificationLocalizations() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final language = effectiveAppLanguageTag(
      preference: preferences.getString(localePreferenceStorageKey),
      systemLocale: const Locale('pt', 'BR'),
    );
    return language == 'en-US'
        ? AppLocalizationsEnUs()
        : AppLocalizationsPtBr();
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

class FlutterEngagementNotificationScheduler
    implements EngagementNotificationScheduler {
  const FlutterEngagementNotificationScheduler();

  @override
  Future<void> schedule(EngagementNotificationCandidate candidate) {
    return LocalCheckInReminderNotifications.scheduleEngagement(candidate);
  }

  @override
  Future<void> cancel(EngagementNotificationType type) {
    return LocalCheckInReminderNotifications.cancelEngagement(type);
  }

  @override
  Future<void> cancelAll() {
    return LocalCheckInReminderNotifications.cancelAllEngagement();
  }
}

class LocalCheckInReminderNotifications {
  const LocalCheckInReminderNotifications._();

  static const _notificationId = 8001;
  static const _channelId = 'daily_checkin_reminder';
  static const _channelName = 'Lembrete diário de check-in';
  static const _channelDescription =
      'Lembretes locais para registrar seu momento no Evolua.';
  static const _engagementChannelId = 'evolua_engagement_notifications';
  static const _engagementChannelName = 'Notificações de evolução';
  static const _engagementChannelDescription =
      'Lembretes locais leves para continuar sua evolução.';
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
        _isSupportedPayload(response?.payload)) {
      await _storePendingPayload(response!.payload!);
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

  static Future<void> scheduleEngagement(
    EngagementNotificationCandidate candidate,
  ) async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    final payload = EngagementNotificationPayload(
      type: candidate.type,
      targetRoute: candidate.targetRoute,
      createdAt: DateTime.now().toUtc(),
      metadata: candidate.metadata,
    ).encode();
    await _plugin.zonedSchedule(
      id: candidate.type.notificationId,
      title: candidate.title,
      body: candidate.body,
      scheduledDate: tz.TZDateTime.from(candidate.scheduledAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _engagementChannelId,
          _engagementChannelName,
          channelDescription: _engagementChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  static Future<void> cancelDailyReminder() {
    return _plugin.cancel(id: _notificationId);
  }

  static Future<void> cancelEngagement(EngagementNotificationType type) {
    return _plugin.cancel(id: type.notificationId);
  }

  static Future<void> cancelAllEngagement() async {
    for (final type in EngagementNotificationType.values) {
      await cancelEngagement(type);
    }
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
    if (_isSupportedPayload(payload)) {
      _storePendingPayload(payload!);
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
  final payload = response.payload;
  if (_isSupportedPayload(payload)) {
    LocalCheckInReminderNotifications._storePendingPayload(payload!);
  }
}

String engagementRouteFromPayload(String? payload) {
  if (payload == dailyCheckInReminderPayload) {
    return '/home';
  }
  if (payload == null || payload.isEmpty) {
    return '/home';
  }
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      return EngagementNotificationPayload.fromJson(decoded).targetRoute;
    }
  } catch (_) {
    // Invalid payloads must not navigate to arbitrary routes.
  }
  return '/home';
}

bool _isSupportedPayload(String? payload) {
  if (payload == dailyCheckInReminderPayload) {
    return true;
  }
  if (payload == null || payload.isEmpty) {
    return false;
  }
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      EngagementNotificationPayload.fromJson(decoded);
      return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}

String _safeEngagementRoute(String? route, {required String fallback}) {
  if (route == null || route.isEmpty) {
    return fallback;
  }
  if (route == '/check-in') {
    return '/home';
  }
  const allowed = {
    '/home',
    '/future-messages',
    '/daily-ritual?type=morning',
    '/daily-ritual?type=evening',
    '/home?profileSection=evolutionMirror',
  };
  return allowed.contains(route) ? route : '/home';
}

String _dayKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _weekKey(DateTime date) {
  final local = date.toLocal();
  final firstDay = DateTime(local.year, 1, 1);
  final dayOffset = DateTime(
    local.year,
    local.month,
    local.day,
  ).difference(firstDay).inDays;
  final week = (dayOffset / 7).floor() + 1;
  return '${local.year.toString().padLeft(4, '0')}-'
      '${week.toString().padLeft(2, '0')}';
}

String _periodKey(DateTime date) {
  final hour = date.toLocal().hour;
  if (hour < 12) {
    return '${_dayKey(date)}-morning';
  }
  if (hour < 18) {
    return '${_dayKey(date)}-afternoon';
  }
  return '${_dayKey(date)}-evening';
}
