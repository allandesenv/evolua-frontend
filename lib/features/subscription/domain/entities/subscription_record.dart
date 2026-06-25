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
    this.planFamily = 'STANDARD',
    this.badge,
    this.highlighted = false,
    this.availabilityNote,
    this.providerProductId,
    this.sortOrder = 0,
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
  final String planFamily;
  final String? badge;
  final bool highlighted;
  final String? availabilityNote;
  final String? providerProductId;
  final int sortOrder;

  bool get isFounder => planFamily.toUpperCase() == 'FOUNDER';
}

class CurrentSubscription {
  const CurrentSubscription({
    required this.planCode,
    required this.status,
    required this.billingCycle,
    required this.premium,
    required this.adsEnabled,
    required this.aiQuotaRemainingToday,
    required this.mentorPremiumPassActive,
    required this.mentorRewardedAdAvailable,
    this.provider,
    this.mentorPremiumPassEndsAt,
    this.currentPeriodEndsAt,
    this.canceledAt,
  });

  final String planCode;
  final String status;
  final String billingCycle;
  final bool premium;
  final bool adsEnabled;
  final int aiQuotaRemainingToday;
  final bool mentorPremiumPassActive;
  final bool mentorRewardedAdAvailable;
  final String? provider;
  final DateTime? mentorPremiumPassEndsAt;
  final DateTime? currentPeriodEndsAt;
  final DateTime? canceledAt;
}

class AdRewardSession {
  const AdRewardSession({
    required this.id,
    required this.provider,
    required this.rewardType,
    this.contextId,
    required this.status,
    required this.customData,
    required this.expiresAt,
    this.grantedAt,
  });

  final String id;
  final String provider;
  final String rewardType;
  final String? contextId;
  final String status;
  final String customData;
  final DateTime expiresAt;
  final DateTime? grantedAt;
}

class MonetizationAccessStatus {
  const MonetizationAccessStatus({
    required this.resource,
    this.contextId,
    required this.allowed,
    required this.premium,
    required this.rewardedAdAvailable,
    required this.upgradeRecommended,
    this.limitMessage,
    this.entitlementExpiresAt,
    this.rewardedCreditsGrantedToday = 0,
    this.rewardedCreditsUsedToday = 0,
  });

  final String resource;
  final String? contextId;
  final bool allowed;
  final bool premium;
  final bool rewardedAdAvailable;
  final bool upgradeRecommended;
  final String? limitMessage;
  final DateTime? entitlementExpiresAt;
  final int rewardedCreditsGrantedToday;
  final int rewardedCreditsUsedToday;

  bool get hasPendingRewardCredit =>
      rewardedCreditsGrantedToday > rewardedCreditsUsedToday;
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
      status == 'PENDING_PAYMENT' ||
      status == 'PENDING' ||
      status == 'IN_PROCESS';
  bool get isApproved => status == 'APPROVED' || status == 'ACTIVE';
}

class SubscriptionScreenState {
  const SubscriptionScreenState({
    required this.plans,
    required this.current,
    this.pendingCheckout,
    this.isBusy = false,
    this.busyPlanCode,
    this.message,
  });

  final List<PlanView> plans;
  final CurrentSubscription? current;
  final CheckoutSession? pendingCheckout;
  final bool isBusy;
  final String? busyPlanCode;
  final String? message;

  SubscriptionScreenState copyWith({
    List<PlanView>? plans,
    CurrentSubscription? current,
    bool clearCurrent = false,
    CheckoutSession? pendingCheckout,
    bool clearPendingCheckout = false,
    bool? isBusy,
    String? busyPlanCode,
    bool clearBusyPlanCode = false,
    String? message,
    bool clearMessage = false,
  }) {
    return SubscriptionScreenState(
      plans: plans ?? this.plans,
      current: clearCurrent ? null : (current ?? this.current),
      pendingCheckout: clearPendingCheckout
          ? null
          : (pendingCheckout ?? this.pendingCheckout),
      isBusy: isBusy ?? this.isBusy,
      busyPlanCode: clearBusyPlanCode
          ? null
          : (busyPlanCode ?? this.busyPlanCode),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
