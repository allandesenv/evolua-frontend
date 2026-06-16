import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';

bool rewardedAccessGranted(MonetizationAccessStatus status) {
  return status.allowed ||
      status.entitlementExpiresAt != null ||
      status.hasPendingRewardCredit;
}
