import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_stub.dart'
    if (dart.library.io) 'package:evolua_frontend/features/ads/application/rewarded_ad_service_mobile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) {
  return createRewardedAdService(ref);
});
