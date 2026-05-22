import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';

abstract class SubscriptionRepository {
  Future<List<PlanView>> listPlans();

  Future<CurrentSubscription?> current();

  Future<CheckoutSession> startCheckout({
    required String planCode,
    required String frontendBaseUrl,
  });

  Future<CheckoutSession> checkoutStatus(String checkoutId);

  Future<CheckoutSession> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    required String packageName,
    required String planCode,
  });

  Future<CurrentSubscription?> cancel();

  Future<AdRewardSession> createRewardSession({
    required String rewardType,
    String? contextId,
  });

  Future<AdRewardSession> grantTestReward(String sessionId);

  Future<AdRewardSession> grantClientOpenedReward(String sessionId);

  Future<MonetizationAccessStatus> monetizationAccess({
    required String resource,
    String? contextId,
  });
}
