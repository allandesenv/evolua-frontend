import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

RewardedAdService createRewardedAdService(Ref ref) {
  return const WebRewardedAdService();
}

class WebRewardedAdService implements RewardedAdService {
  const WebRewardedAdService();

  @override
  Future<bool> showRewardedAd({
    required String rewardType,
    String? contextId,
  }) async {
    return false;
  }
}
