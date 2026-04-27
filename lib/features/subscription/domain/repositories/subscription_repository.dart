import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';

abstract class SubscriptionRepository {
  Future<List<PlanView>> listPlans();

  Future<CurrentSubscription?> current();

  Future<CheckoutSession> startCheckout({
    required String planCode,
    required String frontendBaseUrl,
  });

  Future<CheckoutSession> checkoutStatus(String checkoutId);

  Future<CurrentSubscription?> cancel();
}
