abstract class RewardedAdService {
  Future<bool> showRewardedAd({
    required String rewardType,
    String? contextId,
    bool allowClientOpenedFallback = false,
  });
}
