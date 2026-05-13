import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final monetizationAccessControllerProvider =
    AsyncNotifierProvider<MonetizationAccessController, void>(
      MonetizationAccessController.new,
    );

class MonetizationAccessController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<MonetizationAccessStatus> access({
    required String resource,
    String? contextId,
  }) {
    return ref
        .read(subscriptionRepositoryProvider)
        .monetizationAccess(resource: resource, contextId: contextId);
  }

  Future<bool> unlockWithRewardedAd({
    required String resource,
    String? contextId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(rewardedAdServiceProvider)
          .showRewardedAd(rewardType: resource, contextId: contextId);
      await ref.read(subscriptionControllerProvider.notifier).refresh();
    });
    if (state.hasError) {
      return false;
    }
    final refreshed = await access(resource: resource, contextId: contextId);
    return rewardedAccessGranted(refreshed);
  }

  bool rewardedAccessGranted(MonetizationAccessStatus status) {
    return status.allowed || status.entitlementExpiresAt != null;
  }
}
