import 'package:evolua_frontend/features/ads/application/interstitial_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
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
    void Function()? onAdClosed,
  }) async {
    var result = RewardedAdResult.unsupported;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      result = await ref
          .read(rewardedAdServiceProvider)
          .showRewardedAd(
            rewardType: resource,
            contextId: contextId,
            onAdClosed: onAdClosed,
          );
      if (result.isRewarded) {
        await ref
            .read(interstitialAdServiceProvider)
            .recordRewardedAdShown(
              session: ref.read(authControllerProvider).asData?.value,
            );
        await ref.read(subscriptionControllerProvider.notifier).refresh();
      }
    });
    if (state.hasError || !result.isRewarded) {
      return false;
    }
    final refreshed = await access(resource: resource, contextId: contextId);
    return rewardedAccessGranted(refreshed);
  }

  Future<RewardedAdResult> unlockWithRewardedAdResult({
    required String resource,
    String? contextId,
    void Function()? onAdClosed,
  }) async {
    var result = RewardedAdResult.unsupported;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      result = await ref
          .read(rewardedAdServiceProvider)
          .showRewardedAd(
            rewardType: resource,
            contextId: contextId,
            onAdClosed: onAdClosed,
          );
      if (result.isRewarded) {
        await ref
            .read(interstitialAdServiceProvider)
            .recordRewardedAdShown(
              session: ref.read(authControllerProvider).asData?.value,
            );
        await ref.read(subscriptionControllerProvider.notifier).refresh();
      }
    });
    if (state.hasError) {
      return RewardedAdResult.loadFailed;
    }
    if (!result.isRewarded) {
      return result;
    }
    final refreshed = await access(resource: resource, contextId: contextId);
    return rewardedAccessGranted(refreshed)
        ? RewardedAdResult.rewarded
        : RewardedAdResult.rewardConfirmedButAccessDenied;
  }

  bool rewardedAccessGranted(MonetizationAccessStatus status) {
    return status.allowed || status.entitlementExpiresAt != null;
  }
}
