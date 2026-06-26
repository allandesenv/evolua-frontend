import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_stub.dart'
    if (dart.library.io) 'package:evolua_frontend/features/ads/application/rewarded_ad_service_mobile.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  ref.watch(authSessionGenerationProvider);

  return createRewardedAdService(repository);
});
