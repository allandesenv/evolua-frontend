import 'package:evolua_frontend/features/ads/application/ad_placement_policy.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum InterstitialTrigger {
  trailCompletion(AdPlacementContext.trailCompletion),
  readingSavedExit(AdPlacementContext.readingSavedExit),
  ritualCompletedExit(AdPlacementContext.ritualCompletedExit),
  futureMessageScheduledExit(AdPlacementContext.futureMessageScheduledExit),
  futureMessageReadExit(AdPlacementContext.futureMessageReadExit),
  timelineExit(AdPlacementContext.timelineExit),
  readingVariationMilestone(AdPlacementContext.readingVariationMilestone);

  const InterstitialTrigger(this.context);

  final AdPlacementContext context;
}

class InterstitialPlacementConfig {
  const InterstitialPlacementConfig._();

  static bool isEnabled(InterstitialTrigger trigger) {
    return switch (trigger) {
      InterstitialTrigger.ritualCompletedExit => true,
      InterstitialTrigger.trailCompletion => true,
      InterstitialTrigger.futureMessageScheduledExit => true,
      InterstitialTrigger.futureMessageReadExit => true,
      InterstitialTrigger.readingSavedExit => false,
      InterstitialTrigger.timelineExit => false,
      InterstitialTrigger.readingVariationMilestone => false,
    };
  }
}

abstract class InterstitialAdService {
  Future<void> preload();

  Future<bool> maybeShow({
    required InterstitialTrigger trigger,
    required AuthSession? session,
  });

  Future<void> recordRewardedAdShown({AuthSession? session});

  void dispose();
}

class InterstitialFrequencyCap {
  const InterstitialFrequencyCap({
    this.minInterval = const Duration(minutes: 5),
    this.rewardedCooldown = const Duration(minutes: 8),
    this.maxPerDay = 3,
    this.minActionsBetweenShows = 1,
  });

  final Duration minInterval;
  final Duration rewardedCooldown;
  final int maxPerDay;
  final int minActionsBetweenShows;

  Future<InterstitialFrequencyDecision> checkAndRecordAction({
    required SharedPreferences preferences,
    required String userId,
    required DateTime now,
  }) async {
    final prefix = _prefix(userId);
    final today = _dateKey(now);
    final storedDate = preferences.getString('$prefix.date');
    if (storedDate != today) {
      await preferences.setString('$prefix.date', today);
      await preferences.setInt('$prefix.daily_count', 0);
      await preferences.setInt('$prefix.actions', 0);
    }

    final actions = preferences.getInt('$prefix.actions') ?? 0;
    final nextActions = actions + 1;
    await preferences.setInt('$prefix.actions', nextActions);

    if (nextActions < minActionsBetweenShows) {
      return const InterstitialFrequencyDecision.blocked('frequency cap');
    }

    final count = preferences.getInt('$prefix.daily_count') ?? 0;
    if (count >= maxPerDay) {
      return const InterstitialFrequencyDecision.blocked('frequency cap');
    }

    final lastShown = _readMillis(preferences, '$prefix.last_shown_at');
    if (lastShown != null && now.difference(lastShown) < minInterval) {
      return const InterstitialFrequencyDecision.blocked('frequency cap');
    }

    final lastRewarded = _readMillis(preferences, '$prefix.last_rewarded_at');
    if (lastRewarded != null &&
        now.difference(lastRewarded) < rewardedCooldown) {
      return const InterstitialFrequencyDecision.blocked('rewarded recente');
    }

    return const InterstitialFrequencyDecision.allowed();
  }

  Future<void> recordShown({
    required SharedPreferences preferences,
    required String userId,
    required DateTime now,
  }) async {
    final prefix = _prefix(userId);
    final today = _dateKey(now);
    final storedDate = preferences.getString('$prefix.date');
    if (storedDate != today) {
      await preferences.setString('$prefix.date', today);
      await preferences.setInt('$prefix.daily_count', 0);
    }
    final count = preferences.getInt('$prefix.daily_count') ?? 0;
    await preferences.setInt('$prefix.daily_count', count + 1);
    await preferences.setInt('$prefix.actions', 0);
    await preferences.setInt(
      '$prefix.last_shown_at',
      now.millisecondsSinceEpoch,
    );
  }

  Future<void> recordRewarded({
    required SharedPreferences preferences,
    required String userId,
    required DateTime now,
  }) async {
    await preferences.setInt(
      '${_prefix(userId)}.last_rewarded_at',
      now.millisecondsSinceEpoch,
    );
  }

  static String adUnitIdFor({
    required bool isAndroid,
    required bool isIOS,
    required bool useTestAds,
    required String androidRealAdUnitId,
    required String iosRealAdUnitId,
    required String androidTestAdUnitId,
    required String iosTestAdUnitId,
  }) {
    if (useTestAds) {
      return isIOS ? iosTestAdUnitId : androidTestAdUnitId;
    }
    if (isAndroid) {
      return androidRealAdUnitId;
    }
    if (isIOS) {
      return iosRealAdUnitId;
    }
    return '';
  }

  DateTime? _readMillis(SharedPreferences preferences, String key) {
    final value = preferences.getInt(key);
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  String _prefix(String userId) => 'evolua.interstitial.$userId';

  String _dateKey(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class InterstitialFrequencyDecision {
  const InterstitialFrequencyDecision._({
    required this.allowed,
    required this.reason,
  });

  const InterstitialFrequencyDecision.allowed()
    : this._(allowed: true, reason: null);

  const InterstitialFrequencyDecision.blocked(String reason)
    : this._(allowed: false, reason: reason);

  final bool allowed;
  final String? reason;
}

void debugInterstitial(String message) {
  if (!kReleaseMode) {
    debugPrint('Evolua interstitial $message');
  }
}
