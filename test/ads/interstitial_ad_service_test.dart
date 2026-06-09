import 'package:evolua_frontend/features/ads/application/ad_placement_policy.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service_base.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service_mobile.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'uses required Android interstitial test id when test ads are enabled',
    () {
      final adUnitId = MobileInterstitialAdService.adUnitIdFor(
        isAndroid: true,
        isIOS: false,
        useTestAds: true,
      );

      expect(adUnitId, 'ca-app-pub-3940256099942544/1033173712');
    },
  );

  test(
    'uses required Android real interstitial id when test ads are disabled',
    () {
      final adUnitId = MobileInterstitialAdService.adUnitIdFor(
        isAndroid: true,
        isIOS: false,
        useTestAds: false,
      );

      expect(adUnitId, 'ca-app-pub-1136517314419681/5451133226');
    },
  );

  test('uses required iOS interstitial test id when test ads are enabled', () {
    final adUnitId = MobileInterstitialAdService.adUnitIdFor(
      isAndroid: false,
      isIOS: true,
      useTestAds: true,
    );

    expect(adUnitId, 'ca-app-pub-3940256099942544/4411468910');
  });

  test('policy allows interstitial only in permitted natural transitions', () {
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: AdPlacementContext.trailCompletion,
        premium: false,
        interstitialEnabled: true,
      ),
      isTrue,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: AdPlacementContext.deepReflection,
        premium: false,
        interstitialEnabled: true,
      ),
      isFalse,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: AdPlacementContext.trailCompletion,
        premium: true,
        interstitialEnabled: true,
      ),
      isFalse,
    );
  });

  test(
    'frequency cap requires two relevant actions before first show',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      const cap = InterstitialFrequencyCap();
      final now = DateTime(2026, 6, 8, 10);

      final first = await cap.checkAndRecordAction(
        preferences: preferences,
        userId: 'free-user',
        now: now,
      );
      final second = await cap.checkAndRecordAction(
        preferences: preferences,
        userId: 'free-user',
        now: now.add(const Duration(minutes: 1)),
      );

      expect(first.allowed, isFalse);
      expect(second.allowed, isTrue);
    },
  );

  test('frequency cap blocks recent rewarded and daily max', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    const cap = InterstitialFrequencyCap();
    final now = DateTime(2026, 6, 8, 10);

    await cap.recordRewarded(
      preferences: preferences,
      userId: 'free-user',
      now: now,
    );
    await cap.checkAndRecordAction(
      preferences: preferences,
      userId: 'free-user',
      now: now.add(const Duration(minutes: 1)),
    );
    final blockedByRewarded = await cap.checkAndRecordAction(
      preferences: preferences,
      userId: 'free-user',
      now: now.add(const Duration(minutes: 2)),
    );

    expect(blockedByRewarded.allowed, isFalse);
    expect(blockedByRewarded.reason, 'rewarded recente');

    final later = now.add(const Duration(minutes: 20));
    for (var i = 0; i < 3; i++) {
      await cap.checkAndRecordAction(
        preferences: preferences,
        userId: 'free-user',
        now: later.add(Duration(minutes: i * 10)),
      );
      final allowed = await cap.checkAndRecordAction(
        preferences: preferences,
        userId: 'free-user',
        now: later.add(Duration(minutes: i * 10 + 1)),
      );
      expect(allowed.allowed, isTrue);
      await cap.recordShown(
        preferences: preferences,
        userId: 'free-user',
        now: later.add(Duration(minutes: i * 10 + 1)),
      );
    }

    await cap.checkAndRecordAction(
      preferences: preferences,
      userId: 'free-user',
      now: later.add(const Duration(hours: 1)),
    );
    final dailyMax = await cap.checkAndRecordAction(
      preferences: preferences,
      userId: 'free-user',
      now: later.add(const Duration(hours: 1, minutes: 1)),
    );

    expect(dailyMax.allowed, isFalse);
    expect(dailyMax.reason, 'frequency cap');
  });

  test('premium session is recognized as non eligible by policy layer', () {
    const premiumSession = AuthSession(
      userId: 'premium-user',
      email: 'premium@evolua.test',
      roles: ['ROLE_PREMIUM'],
      accessToken: 'token',
    );

    expect(premiumSession.isPremium, isTrue);
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: InterstitialTrigger.timelineExit.context,
        premium: premiumSession.isPremium,
        interstitialEnabled: true,
      ),
      isFalse,
    );
  });
}
