import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileRewardedAdService ad unit mapping', () {
    test('uses AI rewarded block for deep emotional reading', () {
      final adUnitId = MobileRewardedAdService.adUnitIdFor(
        rewardType: 'DEEP_EMOTIONAL_READING',
        isAndroid: true,
        isIOS: false,
        useTestAds: false,
      );

      expect(adUnitId, AppConfig.adMobAndroidRewardedAiExtraAdUnitId);
    });

    test('uses extra check-in block for extra check-in reward', () {
      final adUnitId = MobileRewardedAdService.adUnitIdFor(
        rewardType: 'EXTRA_CHECK_IN',
        isAndroid: true,
        isIOS: false,
        useTestAds: false,
      );
      final logicalName = MobileRewardedAdService.logicalAdUnitNameFor(
        rewardType: 'EXTRA_CHECK_IN',
        isIOS: false,
        useTestAds: false,
      );

      expect(adUnitId, AppConfig.adMobAndroidRewardedExtraCheckInAdUnitId);
      expect(logicalName, 'android_rewarded_extra_check_in');
    });

    test('extra check-in block falls back to AI extra by default', () {
      expect(
        AppConfig.adMobAndroidRewardedExtraCheckInAdUnitId,
        AppConfig.adMobAndroidRewardedAiExtraAdUnitId,
      );
    });

    test('uses premium pass block for advanced mirror', () {
      final adUnitId = MobileRewardedAdService.adUnitIdFor(
        rewardType: 'ADVANCED_MIRROR',
        isAndroid: true,
        isIOS: false,
        useTestAds: false,
      );

      expect(adUnitId, AppConfig.adMobAndroidRewardedPremiumPassAdUnitId);
    });

    test('uses premium pass block for premium trail step', () {
      final adUnitId = MobileRewardedAdService.adUnitIdFor(
        rewardType: 'PREMIUM_TRAIL_STEP',
        isAndroid: true,
        isIOS: false,
        useTestAds: false,
      );

      expect(adUnitId, AppConfig.adMobAndroidRewardedPremiumPassAdUnitId);
    });

    test('uses premium pass block for full check-in history timeline', () {
      final adUnitId = MobileRewardedAdService.adUnitIdFor(
        rewardType: RewardResources.checkInHistoryFull,
        isAndroid: true,
        isIOS: false,
        useTestAds: false,
      );
      final logicalName = MobileRewardedAdService.logicalAdUnitNameFor(
        rewardType: RewardResources.checkInHistoryFull,
        isIOS: false,
        useTestAds: false,
      );

      expect(adUnitId, AppConfig.adMobAndroidRewardedPremiumPassAdUnitId);
      expect(logicalName, 'android_rewarded_premium_pass');
      expect(logicalName, isNot('unknown_rewarded'));
    });

    test('uses official test block when test ads are enabled', () {
      final adUnitId = MobileRewardedAdService.adUnitIdFor(
        rewardType: 'ADVANCED_MIRROR',
        isAndroid: true,
        isIOS: false,
        useTestAds: true,
      );

      expect(adUnitId, AppConfig.adMobAndroidRewardedTestAdUnitId);
    });

    test('rejects unknown reward type outside test mode', () {
      expect(
        () => MobileRewardedAdService.adUnitIdFor(
          rewardType: 'UNKNOWN_RESOURCE',
          isAndroid: true,
          isIOS: false,
          useTestAds: false,
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('MobileRewardedAdService rewarded outcome policy', () {
    test('does not time out an opened full-screen ad after 20 seconds', () {
      final timedOut = rewardedLifecycleTimedOut(
        elapsedSinceWaitStart: const Duration(seconds: 45),
        openedFullScreen: true,
        elapsedSinceOpen: const Duration(seconds: 26),
      );

      expect(timedOut, isFalse);
    });

    test('times out while waiting for the rewarded ad to open', () {
      final timedOut = rewardedLifecycleTimedOut(
        elapsedSinceWaitStart: const Duration(seconds: 20),
        openedFullScreen: false,
      );

      expect(timedOut, isTrue);
    });

    test('keeps a full-screen safety timeout', () {
      final timedOut = rewardedLifecycleTimedOut(
        elapsedSinceWaitStart: const Duration(minutes: 3),
        openedFullScreen: true,
        elapsedSinceOpen: const Duration(minutes: 2),
      );

      expect(timedOut, isTrue);
    });

    test('continues to SSV when reward was earned before timeout', () {
      final result = rewardedResultBeforeSsv(
        openedFullScreen: true,
        earnedReward: true,
        outcomeResult: RewardedAdResult.timeout,
      );

      expect(result, isNull);
    });

    test('timeout before opening becomes show failed', () {
      final result = rewardedResultBeforeSsv(
        openedFullScreen: false,
        earnedReward: false,
        outcomeResult: RewardedAdResult.timeout,
      );

      expect(result, RewardedAdResult.showFailed);
    });

    test('keeps timeout when ad opened but no reward was earned', () {
      final result = rewardedResultBeforeSsv(
        openedFullScreen: true,
        earnedReward: false,
        outcomeResult: RewardedAdResult.timeout,
      );

      expect(result, RewardedAdResult.timeout);
    });
  });
}
