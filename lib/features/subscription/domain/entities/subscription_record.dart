class PlanView {
  const PlanView({
    required this.planCode,
    required this.title,
    required this.subtitle,
    required this.billingCycle,
    required this.premium,
    required this.price,
    required this.currency,
    required this.benefits,
    required this.active,
  });

  final String planCode;
  final String title;
  final String subtitle;
  final String billingCycle;
  final bool premium;
  final double price;
  final String currency;
  final List<String> benefits;
  final bool active;
}

class CurrentSubscription {
  const CurrentSubscription({
    required this.planCode,
    required this.status,
    required this.billingCycle,
    required this.premium,
    this.provider,
    this.currentPeriodEndsAt,
    this.canceledAt,
  });

  final String planCode;
  final String status;
  final String billingCycle;
  final bool premium;
  final String? provider;
  final DateTime? currentPeriodEndsAt;
  final DateTime? canceledAt;
}

class CheckoutSession {
  const CheckoutSession({
    required this.id,
    required this.planCode,
    required this.billingCycle,
    required this.status,
    required this.premium,
    this.checkoutUrl,
    this.failureReason,
    this.confirmedAt,
  });

  final String id;
  final String planCode;
  final String billingCycle;
  final String status;
  final bool premium;
  final String? checkoutUrl;
  final String? failureReason;
  final DateTime? confirmedAt;

  bool get isPending =>
      status == 'PENDING_PAYMENT' || status == 'PENDING' || status == 'IN_PROCESS';
  bool get isApproved => status == 'APPROVED' || status == 'ACTIVE';
}

class SubscriptionScreenState {
  const SubscriptionScreenState({
    required this.plans,
    required this.current,
    this.pendingCheckout,
    this.isBusy = false,
    this.message,
  });

  final List<PlanView> plans;
  final CurrentSubscription? current;
  final CheckoutSession? pendingCheckout;
  final bool isBusy;
  final String? message;

  SubscriptionScreenState copyWith({
    List<PlanView>? plans,
    CurrentSubscription? current,
    CheckoutSession? pendingCheckout,
    bool clearPendingCheckout = false,
    bool? isBusy,
    String? message,
    bool clearMessage = false,
  }) {
    return SubscriptionScreenState(
      plans: plans ?? this.plans,
      current: current ?? this.current,
      pendingCheckout: clearPendingCheckout
          ? null
          : (pendingCheckout ?? this.pendingCheckout),
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
