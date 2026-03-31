class SubscriptionRecord {
  const SubscriptionRecord({
    required this.id,
    required this.userId,
    required this.planCode,
    required this.status,
    required this.billingCycle,
    required this.premium,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String planCode;
  final String status;
  final String billingCycle;
  final bool premium;
  final DateTime createdAt;
}
