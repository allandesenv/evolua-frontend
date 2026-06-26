import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';

RewardedAdService createRewardedAdService(SubscriptionRepository repository) {
  return const WebRewardedAdService();
}

class WebRewardedAdService implements RewardedAdService {
  const WebRewardedAdService();

  @override
  Future<RewardedAdResult> showRewardedAd({
    required String rewardType,
    String? contextId,
    void Function()? onAdClosed,
  }) async {
    return RewardedAdResult.unsupported;
  }
}
