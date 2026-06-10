import 'package:evolua_frontend/core/config/app_config.dart';
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

      expect(adUnitId, AppConfig.adMobAndroidRewardedExtraCheckInAdUnitId);
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
}
