enum RewardedAdResult {
  rewarded,
  noFill,
  loadFailed,
  showFailed,
  dismissedWithoutReward,
  timeout,
  unsupported,
}

extension RewardedAdResultX on RewardedAdResult {
  bool get isRewarded => this == RewardedAdResult.rewarded;
}

abstract final class RewardResources {
  static const deepEmotionalReading = 'DEEP_EMOTIONAL_READING';
  static const extraCheckIn = 'EXTRA_CHECK_IN';
  static const aiExtra = 'AI_ACTION';
  static const premiumPass = 'PREMIUM_PASS';
}

abstract class RewardedAdService {
  Future<RewardedAdResult> showRewardedAd({
    required String rewardType,
    String? contextId,
    void Function()? onAdClosed,
  });
}
