import 'dart:async';
import 'dart:convert';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/notification/application/local_check_in_reminder_controller.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations_en.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations_pt.dart';
import 'package:evolua_frontend/l10n/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final engagementNotificationPlannerProvider =
    Provider<EngagementNotificationPlanner>((ref) {
      return EngagementNotificationPlanner(ref);
    });

class EngagementNotificationPlanner {
  const EngagementNotificationPlanner(this._ref);

  final Ref _ref;

  Future<void> evaluateAfterWarmUp(AuthSession session) async {
    await _guarded(() async {
      final generation = _ref.read(authSessionGenerationProvider);
      if (!_isCurrentSession(session.userId, generation)) {
        return;
      }

      final checkIns = _readCheckInStateIfLoaded();
      if (!_isCurrentSession(session.userId, generation)) {
        return;
      }

      await _planWeeklyMirror(
        userId: session.userId,
        recentCheckIns: checkIns?.result.items ?? const <CheckIn>[],
      );
    });
  }

  Future<void> onCheckInCreated(CheckIn checkIn) async {
    await _guarded(() async {
      final session = _ref.read(authControllerProvider).asData?.value;
      final generation = _ref.read(authSessionGenerationProvider);
      if (session == null ||
          session.userId != checkIn.userId ||
          !_isCurrentSession(session.userId, generation)) {
        return;
      }

      await _ref
          .read(dailyCheckInReminderControllerProvider.notifier)
          .rescheduleDailyCheckInAfterSuccessfulCheckIn(checkIn.createdAt);

      final checkIns = _readCheckInStateIfLoaded();
      if (!_isCurrentSession(session.userId, generation)) {
        return;
      }
      await _planWeeklyMirror(
        userId: session.userId,
        recentCheckIns: checkIns?.result.items ?? <CheckIn>[checkIn],
      );
    });
  }

  Future<void> onTrailJourneyChanged(TrailJourney journey) async {
    await _guarded(() async {
      final session = _ref.read(authControllerProvider).asData?.value;
      final generation = _ref.read(authSessionGenerationProvider);
      if (session == null || !_isCurrentSession(session.userId, generation)) {
        return;
      }
      final latestCheckIn = _readCheckInStateIfLoaded()?.latestCreatedCheckIn;
      await _planTrailResume(
        journey,
        userId: session.userId,
        lastCheckInAt: latestCheckIn?.createdAt,
      );
    });
  }

  Future<void> _planTrailResume(
    TrailJourney journey, {
    required String userId,
    DateTime? lastCheckInAt,
  }) async {
    final progress = journey.progress;
    if (progress == null) {
      return;
    }

    final controller = _ref.read(
      dailyCheckInReminderControllerProvider.notifier,
    );
    if (journey.isCompleted) {
      await _ref
          .read(engagementNotificationSchedulerProvider)
          .cancel(EngagementNotificationType.trailResume);
      await _saveScheduleState(
        userId: userId,
        state: (await _loadScheduleState(userId)).withoutTrailResume(),
      );
      return;
    }

    final state = await _loadScheduleState(userId);
    final progressKey = progress.updatedAt.toUtc().toIso8601String();
    if (state.trailId == journey.trail.id &&
        state.trailProgressUpdatedAt == progressKey) {
      return;
    }

    final l10n = await _notificationLocalizations();
    final scheduledAt = _safeDaytime(
      progress.updatedAt.add(const Duration(hours: 24)),
    );
    final scheduled = await controller.scheduleEngagementCandidate(
      EngagementNotificationCandidate(
        type: EngagementNotificationType.trailResume,
        scheduledAt: scheduledAt,
        title: l10n.engagementTrailResumeTitle,
        body: l10n.engagementTrailResumeBody,
        metadata: {
          'trailId': journey.trail.id,
          'stepIndex': journey.nextStep?.index ?? progress.currentStepIndex,
        },
      ),
      now: DateTime.now(),
      lastCheckInAt: lastCheckInAt,
    );
    if (!scheduled) {
      return;
    }
    await _saveScheduleState(
      userId: userId,
      state: state.copyWith(
        trailId: journey.trail.id,
        trailProgressUpdatedAt: progressKey,
      ),
    );
  }

  Future<void> _planWeeklyMirror({
    required String userId,
    required List<CheckIn> recentCheckIns,
    TrailJourney? recentJourney,
  }) async {
    final now = DateTime.now();
    final weekKey = _weekKey(now);
    final state = await _loadScheduleState(userId);
    if (state.weeklyMirrorWeekKey == weekKey) {
      return;
    }
    if (!_hasWeeklyMirrorActivity(now, recentCheckIns, recentJourney)) {
      return;
    }

    final l10n = await _notificationLocalizations();
    final scheduled = await _ref
        .read(dailyCheckInReminderControllerProvider.notifier)
        .scheduleEngagementCandidate(
          EngagementNotificationCandidate(
            type: EngagementNotificationType.weeklyMirror,
            scheduledAt: _nextSundayEvening(now),
            title: l10n.engagementWeeklyMirrorTitle,
            body: l10n.engagementWeeklyMirrorBody,
          ),
          now: now,
          lastCheckInAt: recentCheckIns.firstOrNull?.createdAt,
        );
    if (!scheduled) {
      return;
    }
    await _saveScheduleState(
      userId: userId,
      state: state.copyWith(weeklyMirrorWeekKey: weekKey),
    );
  }

  bool _hasWeeklyMirrorActivity(
    DateTime now,
    List<CheckIn> checkIns,
    TrailJourney? recentJourney,
  ) {
    final since = now.subtract(const Duration(days: 7));
    final recentCheckInCount = checkIns
        .where((checkIn) => checkIn.createdAt.isAfter(since))
        .length;
    if (recentCheckInCount >= 2) {
      return true;
    }
    final updatedAt = recentJourney?.progress?.updatedAt;
    return updatedAt != null && updatedAt.isAfter(since);
  }

  DateTime _safeDaytime(DateTime value) {
    final local = value.toLocal();
    if (local.hour < 9) {
      return DateTime(local.year, local.month, local.day, 9);
    }
    if (local.hour > 20 || (local.hour == 20 && local.minute > 30)) {
      final nextDay = local.add(const Duration(days: 1));
      return DateTime(nextDay.year, nextDay.month, nextDay.day, 9);
    }
    return local;
  }

  DateTime _nextSundayEvening(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final daysUntilSunday = DateTime.sunday - today.weekday;
    var target = today.add(
      Duration(days: daysUntilSunday < 0 ? 7 : daysUntilSunday),
    );
    target = DateTime(target.year, target.month, target.day, 19);
    if (!target.isAfter(now)) {
      final next = target.add(const Duration(days: 7));
      return DateTime(next.year, next.month, next.day, 19);
    }
    return target;
  }

  Future<_EngagementScheduleState> _loadScheduleState(String userId) async {
    final preferences = await _preferences();
    final raw = preferences.getString(_scheduleStateKey(userId));
    if (raw == null || raw.isEmpty) {
      return const _EngagementScheduleState();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return _EngagementScheduleState.fromJson(decoded);
      }
    } catch (_) {
      // Corrupted planner state is replaced by an empty conservative state.
    }
    return const _EngagementScheduleState();
  }

  Future<void> _saveScheduleState({
    required String userId,
    required _EngagementScheduleState state,
  }) async {
    final preferences = await _preferences();
    await preferences.setString(
      _scheduleStateKey(userId),
      jsonEncode(state.toJson()),
    );
  }

  String _scheduleStateKey(String userId) {
    return '$engagementNotificationScheduleStateStorageKey.$userId';
  }

  Future<SharedPreferences> _preferences() {
    return _ref.read(sharedPreferencesProvider.future);
  }

  Future<AppLocalizations> _notificationLocalizations() async {
    final preferences = await _preferences();
    final language = effectiveAppLanguageTag(
      preference: preferences.getString(localePreferenceStorageKey),
      systemLocale: const Locale('pt', 'BR'),
    );
    return language == 'en-US'
        ? AppLocalizationsEnUs()
        : AppLocalizationsPtBr();
  }

  CheckInHistoryState? _readCheckInStateIfLoaded() {
    if (!_ref.exists(checkInControllerProvider)) {
      return null;
    }
    return _ref.read(checkInControllerProvider).asData?.value;
  }

  bool _isCurrentSession(String userId, int generation) {
    if (!_ref.mounted) {
      return false;
    }
    final session = _ref.read(authControllerProvider).asData?.value;
    return session?.userId == userId &&
        _ref.read(authSessionGenerationProvider) == generation;
  }

  Future<void> _guarded(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      return;
    }
  }
}

class _EngagementScheduleState {
  const _EngagementScheduleState({
    this.trailId,
    this.trailProgressUpdatedAt,
    this.weeklyMirrorWeekKey,
  });

  factory _EngagementScheduleState.fromJson(Map<String, dynamic> json) {
    return _EngagementScheduleState(
      trailId: json['trailId'] is num ? (json['trailId'] as num).toInt() : null,
      trailProgressUpdatedAt: json['trailProgressUpdatedAt']?.toString(),
      weeklyMirrorWeekKey: json['weeklyMirrorWeekKey']?.toString(),
    );
  }

  final int? trailId;
  final String? trailProgressUpdatedAt;
  final String? weeklyMirrorWeekKey;

  _EngagementScheduleState copyWith({
    int? trailId,
    String? trailProgressUpdatedAt,
    String? weeklyMirrorWeekKey,
  }) {
    return _EngagementScheduleState(
      trailId: trailId ?? this.trailId,
      trailProgressUpdatedAt:
          trailProgressUpdatedAt ?? this.trailProgressUpdatedAt,
      weeklyMirrorWeekKey: weeklyMirrorWeekKey ?? this.weeklyMirrorWeekKey,
    );
  }

  _EngagementScheduleState withoutTrailResume() {
    return _EngagementScheduleState(weeklyMirrorWeekKey: weeklyMirrorWeekKey);
  }

  Map<String, dynamic> toJson() {
    return {
      'trailId': trailId,
      'trailProgressUpdatedAt': trailProgressUpdatedAt,
      'weeklyMirrorWeekKey': weeklyMirrorWeekKey,
    };
  }
}

String _weekKey(DateTime date) {
  final local = date.toLocal();
  final monday = DateTime(
    local.year,
    local.month,
    local.day,
  ).subtract(Duration(days: local.weekday - 1));
  return '${monday.year.toString().padLeft(4, '0')}-'
      '${monday.month.toString().padLeft(2, '0')}-'
      '${monday.day.toString().padLeft(2, '0')}';
}
