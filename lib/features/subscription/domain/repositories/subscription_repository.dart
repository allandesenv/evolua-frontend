import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';

abstract class SubscriptionRepository {
  Future<List<SubscriptionRecord>> list();

  Future<SubscriptionRecord> create({
    required String planCode,
    required String status,
    required String billingCycle,
    required bool premium,
  });
}
