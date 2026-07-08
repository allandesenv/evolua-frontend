import 'dart:async';

import 'package:evolua_frontend/features/ads/application/ad_placement_policy.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service_base.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service_mobile.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:flutter/foundation.dart';
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

  test('policy allows interstitial only in explicit safe exits', () {
    expect(
      InterstitialPlacementConfig.isEnabled(
        InterstitialTrigger.ritualCompletedExit,
      ),
      isTrue,
    );
    expect(
      InterstitialPlacementConfig.isEnabled(
        InterstitialTrigger.trailCompletion,
      ),
      isTrue,
    );
    expect(
      InterstitialPlacementConfig.isEnabled(
        InterstitialTrigger.readingSavedExit,
      ),
      isFalse,
    );
    expect(
      InterstitialPlacementConfig.isEnabled(
        InterstitialTrigger.futureMessageScheduledExit,
      ),
      isTrue,
    );
    expect(
      InterstitialPlacementConfig.isEnabled(
        InterstitialTrigger.futureMessageReadExit,
      ),
      isTrue,
    );
    expect(
      InterstitialPlacementConfig.isEnabled(
        InterstitialTrigger.readingVariationMilestone,
      ),
      isFalse,
    );

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
        context: AdPlacementContext.ritualCompletedExit,
        premium: false,
        interstitialEnabled: true,
      ),
      isTrue,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: AdPlacementContext.readingSavedExit,
        premium: false,
        interstitialEnabled: true,
      ),
      isFalse,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: AdPlacementContext.futureMessageScheduledExit,
        premium: false,
        interstitialEnabled: true,
      ),
      isTrue,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: AdPlacementContext.futureMessageReadExit,
        premium: false,
        interstitialEnabled: true,
      ),
      isTrue,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: AdPlacementContext.futureMessages,
        premium: false,
        interstitialEnabled: true,
      ),
      isFalse,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: AdPlacementContext.timelineExit,
        premium: false,
        interstitialEnabled: true,
      ),
      isFalse,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: AdPlacementContext.readingVariationMilestone,
        premium: false,
        interstitialEnabled: true,
      ),
      isFalse,
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

  test('frequency cap always allows configured interstitial points', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    const cap = InterstitialFrequencyCap(
      maxPerDay: 0,
      minActionsBetweenShows: 3,
    );
    final now = DateTime(2026, 6, 8, 10);

    final decision = await cap.checkAndRecordAction(
      preferences: preferences,
      userId: 'free-user',
      now: now,
    );

    expect(decision.allowed, isTrue);
    expect(decision.reason, isNull);
  });

  test(
    'frequency cap does not block cooldown, rewarded, daily max, or actions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      const cap = InterstitialFrequencyCap(
        minInterval: Duration(hours: 1),
        rewardedCooldown: Duration(hours: 1),
        maxPerDay: 1,
        minActionsBetweenShows: 3,
      );
      final now = DateTime(2026, 6, 8, 10);

      final first = await cap.checkAndRecordAction(
        preferences: preferences,
        userId: 'free-user',
        now: now,
      );
      expect(first.allowed, isTrue);
      await cap.recordShown(
        preferences: preferences,
        userId: 'free-user',
        now: now,
      );
      final blockedByCooldown = await cap.checkAndRecordAction(
        preferences: preferences,
        userId: 'free-user',
        now: now.add(const Duration(minutes: 4)),
      );
      expect(blockedByCooldown.allowed, isTrue);
      expect(blockedByCooldown.reason, isNull);

      await cap.recordRewarded(
        preferences: preferences,
        userId: 'free-user',
        now: now.add(const Duration(minutes: 6)),
      );
      final blockedByRewarded = await cap.checkAndRecordAction(
        preferences: preferences,
        userId: 'free-user',
        now: now.add(const Duration(minutes: 7)),
      );

      expect(blockedByRewarded.allowed, isTrue);
      expect(blockedByRewarded.reason, isNull);

      final later = now.add(const Duration(minutes: 20));
      for (var i = 0; i < 2; i++) {
        final allowed = await cap.checkAndRecordAction(
          preferences: preferences,
          userId: 'free-user',
          now: later.add(Duration(minutes: i * 10)),
        );
        expect(allowed.allowed, isTrue);
        await cap.recordShown(
          preferences: preferences,
          userId: 'free-user',
          now: later.add(Duration(minutes: i * 10)),
        );
      }

      final dailyMax = await cap.checkAndRecordAction(
        preferences: preferences,
        userId: 'free-user',
        now: later.add(const Duration(hours: 1)),
      );

      expect(dailyMax.allowed, isTrue);
      expect(dailyMax.reason, isNull);
    },
  );

  test('premium and founder sessions are recognized as non eligible', () {
    const premiumSession = AuthSession(
      userId: 'premium-user',
      email: 'premium@evolua.test',
      roles: ['ROLE_PREMIUM'],
      accessToken: 'token',
    );

    expect(premiumSession.isPremium, isTrue);
    expect(MobileInterstitialAdService.isAdFreeSession(premiumSession), isTrue);
    expect(
      MobileInterstitialAdService.isAdFreeSession(
        const AuthSession(
          userId: 'founder-user',
          email: 'founder@evolua.test',
          roles: ['ROLE_FOUNDER'],
          accessToken: 'token',
        ),
      ),
      isTrue,
    );
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

  test('preload and maybeShow share a single pending load', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final loader = _FakeInterstitialLoader();
    final service = _testService(preferences: preferences, loader: loader.call);

    final preload = service.preload();
    final shown = service.maybeShow(
      trigger: InterstitialTrigger.trailCompletion,
      session: _freeSession,
    );

    expect(loader.calls, 1);
    loader.completeLoaded(_FakeInterstitialAdHandle());

    await preload;
    expect(await shown, isTrue);
    await loader.waitForCalls(2);
    loader.completeFailed();
    expect(loader.calls, 2);
  });

  test('maybeShow loads missing ad within timeout and shows it', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final loader = _FakeInterstitialLoader();
    final handle = _FakeInterstitialAdHandle();
    final service = _testService(preferences: preferences, loader: loader.call);

    final shown = service.maybeShow(
      trigger: InterstitialTrigger.trailCompletion,
      session: _freeSession,
    );
    await loader.waitForCalls(1);
    loader.completeLoaded(handle);

    expect(await shown, isTrue);
    await loader.waitForCalls(2);
    loader.completeFailed();
    expect(loader.calls, 2);
    expect(handle.showCalls, 1);
  });

  test('maybeShow returns false when load fails without throwing', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final loader = _FakeInterstitialLoader();
    final service = _testService(preferences: preferences, loader: loader.call);

    final shown = service.maybeShow(
      trigger: InterstitialTrigger.trailCompletion,
      session: _freeSession,
    );
    await loader.waitForCalls(1);
    loader.completeFailed();

    expect(await shown, isFalse);
    await loader.waitForCalls(2);
    loader.completeFailed();
    expect(loader.calls, 2);
  });

  test('maybeShow returns false when load times out safely', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final loader = _FakeInterstitialLoader();
    final service = _testService(
      preferences: preferences,
      loader: loader.call,
      readyTimeout: const Duration(milliseconds: 1),
    );

    final shown = await service.maybeShow(
      trigger: InterstitialTrigger.trailCompletion,
      session: _freeSession,
    );

    expect(shown, isFalse);
    expect(loader.calls, 1);
    loader.completeFailed();
  });

  test('premium and founder sessions block before loading an ad', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final loader = _FakeInterstitialLoader();
    final service = _testService(preferences: preferences, loader: loader.call);

    final premiumShown = await service.maybeShow(
      trigger: InterstitialTrigger.trailCompletion,
      session: const AuthSession(
        userId: 'premium-user',
        email: 'premium@evolua.test',
        roles: ['ROLE_PREMIUM'],
        accessToken: 'token',
      ),
    );
    final founderShown = await service.maybeShow(
      trigger: InterstitialTrigger.trailCompletion,
      session: const AuthSession(
        userId: 'founder-user',
        email: 'founder@evolua.test',
        roles: ['ROLE_FOUNDER'],
        accessToken: 'token',
      ),
    );

    expect(premiumShown, isFalse);
    expect(founderShown, isFalse);
    expect(loader.calls, 0);
  });

  test('frequency settings do not block loading an ad', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final loader = _FakeInterstitialLoader();
    final service = _testService(
      preferences: preferences,
      loader: loader.call,
      frequencyCap: const InterstitialFrequencyCap(maxPerDay: 0),
    );

    final shown = service.maybeShow(
      trigger: InterstitialTrigger.trailCompletion,
      session: _freeSession,
    );

    await loader.waitForCalls(1);
    loader.completeLoaded(_FakeInterstitialAdHandle());

    expect(await shown, isTrue);
    await loader.waitForCalls(2);
    loader.completeFailed();
    expect(loader.calls, 2);
  });
}

const _freeSession = AuthSession(
  userId: 'free-user',
  email: 'free@evolua.test',
  roles: ['ROLE_USER'],
  accessToken: 'token',
);

MobileInterstitialAdService _testService({
  required SharedPreferences preferences,
  required InterstitialAdLoader loader,
  InterstitialFrequencyCap frequencyCap = const InterstitialFrequencyCap(),
  Duration readyTimeout = const Duration(seconds: 3),
}) {
  return MobileInterstitialAdService(
    preferencesReader: () async => preferences,
    frequencyCap: frequencyCap,
    adLoader: loader,
    platformSupported: true,
    adUnitId: 'ca-app-pub-test/interstitial',
    useTestAds: false,
    readyTimeout: readyTimeout,
    showTimeout: const Duration(milliseconds: 50),
  );
}

class _FakeInterstitialLoader {
  int calls = 0;
  final List<Completer<InterstitialAdLoadResult>> _pending = [];

  Future<InterstitialAdLoadResult> call(String adUnitId) {
    calls += 1;
    final completer = Completer<InterstitialAdLoadResult>();
    _pending.add(completer);
    return completer.future;
  }

  Future<void> waitForCalls(int expectedCalls) async {
    while (calls < expectedCalls) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void completeLoaded(_FakeInterstitialAdHandle handle) {
    final completer = _pending.removeAt(0);
    completer.complete(InterstitialAdLoadResult.loaded(handle));
  }

  void completeFailed() {
    final completer = _pending.removeAt(0);
    completer.complete(
      const InterstitialAdLoadResult.failed(
        InterstitialAdErrorInfo(code: 3, domain: 'test', message: 'no fill'),
      ),
    );
  }
}

class _FakeInterstitialAdHandle implements InterstitialAdHandle {
  int showCalls = 0;
  int disposeCalls = 0;
  VoidCallback? _onShown;
  VoidCallback? _onDismissed;

  @override
  void setCallbacks({
    required VoidCallback onShown,
    required VoidCallback onDismissed,
    required void Function(InterstitialAdErrorInfo error) onFailedToShow,
  }) {
    _onShown = onShown;
    _onDismissed = onDismissed;
  }

  @override
  void show() {
    showCalls += 1;
    _onShown?.call();
    _onDismissed?.call();
  }

  @override
  void dispose() {
    disposeCalls += 1;
  }
}
