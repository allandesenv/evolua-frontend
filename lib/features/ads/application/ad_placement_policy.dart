enum AdPlacementContext {
  aiQuotaLimit,
  premiumTrailPreview,
  trailCatalog,
  communitiesList,
  plans,
  neutralNavigation,
  negativeCheckIn,
  journal,
  deepReflection,
  emotionalCrisis,
  onboarding,
  ritualResult,
  sensitiveEvolutionMirror,
  futureMessages,
}

enum AdFormat { rewarded, banner, interstitial }

class AdPlacementPolicy {
  const AdPlacementPolicy._();

  static bool canShow({
    required AdFormat format,
    required AdPlacementContext context,
    required bool premium,
  }) {
    if (premium || _sensitiveContexts.contains(context)) {
      return false;
    }

    return switch (format) {
      AdFormat.rewarded => _rewardedContexts.contains(context),
      AdFormat.banner => _bannerContexts.contains(context),
      AdFormat.interstitial => _interstitialContexts.contains(context),
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
    AdPlacementContext.premiumTrailPreview,
  };

  static const _bannerContexts = {
    AdPlacementContext.trailCatalog,
    AdPlacementContext.communitiesList,
    AdPlacementContext.plans,
    AdPlacementContext.neutralNavigation,
  };

  static const _interstitialContexts = {AdPlacementContext.neutralNavigation};
}
