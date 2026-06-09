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

abstract class RewardedAdService {
  Future<RewardedAdResult> showRewardedAd({
    required String rewardType,
    String? contextId,
    void Function()? onAdClosed,
  });
}
