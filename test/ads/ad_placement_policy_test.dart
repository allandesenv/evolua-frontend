import 'package:evolua_frontend/features/ads/application/ad_placement_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('never shows ads for premium users', () {
    for (final format in AdFormat.values) {
      expect(
        AdPlacementPolicy.canShow(
          format: format,
          context: AdPlacementContext.trailCatalog,
          premium: true,
        ),
        isFalse,
      );
    }
  });

  test('blocks every ad format in sensitive emotional contexts', () {
    const sensitiveContexts = [
      AdPlacementContext.negativeCheckIn,
      AdPlacementContext.journal,
      AdPlacementContext.deepReflection,
      AdPlacementContext.emotionalCrisis,
      AdPlacementContext.onboarding,
      AdPlacementContext.ritualResult,
      AdPlacementContext.sensitiveEvolutionMirror,
      AdPlacementContext.futureMessages,
    ];

    for (final context in sensitiveContexts) {
      for (final format in AdFormat.values) {
        expect(
          AdPlacementPolicy.canShow(
            format: format,
            context: context,
            premium: false,
          ),
          isFalse,
        );
      }
    }
  });

  test('allows rewarded ads only in explicit reward contexts', () {
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.rewarded,
        context: AdPlacementContext.aiQuotaLimit,
        premium: false,
      ),
      isTrue,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.rewarded,
        context: AdPlacementContext.premiumTrailPreview,
        premium: false,
      ),
      isTrue,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.rewarded,
        context: AdPlacementContext.advancedMirror,
        premium: false,
      ),
      isTrue,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.rewarded,
        context: AdPlacementContext.specialReport,
        premium: false,
      ),
      isTrue,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.rewarded,
        context: AdPlacementContext.trailCatalog,
        premium: false,
      ),
      isFalse,
    );
  });

  test('keeps banners neutral and interstitial limited to safe exits', () {
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.banner,
        context: AdPlacementContext.trailCatalog,
        premium: false,
      ),
      isTrue,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: AdPlacementContext.neutralNavigation,
        premium: false,
      ),
      isFalse,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.interstitial,
        context: AdPlacementContext.neutralNavigation,
        premium: false,
        interstitialEnabled: true,
      ),
      isFalse,
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
        context: AdPlacementContext.trailCompletion,
        premium: false,
        interstitialEnabled: true,
      ),
      isTrue,
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
        context: AdPlacementContext.readingSavedExit,
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
        context: AdPlacementContext.trailCatalog,
        premium: false,
      ),
      isFalse,
    );
  });

  test('keeps native ads feature-flagged off by default', () {
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.native,
        context: AdPlacementContext.feedNeutral,
        premium: false,
      ),
      isFalse,
    );
    expect(
      AdPlacementPolicy.canShow(
        format: AdFormat.native,
        context: AdPlacementContext.feedNeutral,
        premium: false,
        nativeAdsEnabled: true,
      ),
      isTrue,
    );
  });
}
