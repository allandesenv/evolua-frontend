enum AdPlacementContext {
  aiQuotaLimit,
  advancedMirror,
  smartRecommendation,
  specialReport,
  premiumTrailPreview,
  trailCatalog,
  communitiesList,
  plans,
  neutralNavigation,
  trailCompletion,
  readingSavedExit,
  ritualCompletedExit,
  timelineExit,
  readingVariationMilestone,
  negativeCheckIn,
  journal,
  deepReflection,
  emotionalCrisis,
  onboarding,
  ritualResult,
  sensitiveEvolutionMirror,
  futureMessages,
  feedNeutral,
}

enum AdFormat { rewarded, banner, interstitial, native }

class AdPlacementPolicy {
  const AdPlacementPolicy._();

  static bool canShow({
    required AdFormat format,
    required AdPlacementContext context,
    required bool premium,
    bool nativeAdsEnabled = false,
    bool interstitialEnabled = false,
  }) {
    if (premium || _sensitiveContexts.contains(context)) {
      return false;
    }

    return switch (format) {
      AdFormat.rewarded => _rewardedContexts.contains(context),
      AdFormat.banner => _bannerContexts.contains(context),
      AdFormat.interstitial =>
        interstitialEnabled && _interstitialContexts.contains(context),
      AdFormat.native => nativeAdsEnabled && _nativeContexts.contains(context),
    };
  }

  static bool isSensitive(AdPlacementContext context) {
    return _sensitiveContexts.contains(context);
  }

  static const _sensitiveContexts = {
    AdPlacementContext.negativeCheckIn,
    AdPlacementContext.journal,
    AdPlacementContext.deepReflection,
    AdPlacementContext.emotionalCrisis,
    AdPlacementContext.onboarding,
    AdPlacementContext.ritualResult,
    AdPlacementContext.sensitiveEvolutionMirror,
    AdPlacementContext.futureMessages,
  };

  static const _rewardedContexts = {
    AdPlacementContext.aiQuotaLimit,
    AdPlacementContext.advancedMirror,
    AdPlacementContext.smartRecommendation,
    AdPlacementContext.specialReport,
    AdPlacementContext.premiumTrailPreview,
  };

  static const _bannerContexts = {
    AdPlacementContext.trailCatalog,
    AdPlacementContext.communitiesList,
    AdPlacementContext.plans,
    AdPlacementContext.neutralNavigation,
  };

  static const _interstitialContexts = {
    AdPlacementContext.neutralNavigation,
    AdPlacementContext.trailCompletion,
    AdPlacementContext.readingSavedExit,
    AdPlacementContext.ritualCompletedExit,
    AdPlacementContext.timelineExit,
    AdPlacementContext.readingVariationMilestone,
  };

  static const _nativeContexts = {
    AdPlacementContext.feedNeutral,
    AdPlacementContext.trailCatalog,
    AdPlacementContext.communitiesList,
  };
}
