import 'package:evolua_frontend/features/ads/application/interstitial_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_access_grant.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
        try {
          await ref.read(currentSubscriptionProvider.notifier).refresh();
        } catch (_) {
          // The protected action still verifies access after the reward.
        }
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
    state = const AsyncLoading();
    RewardedAdResult? result;
    try {
      result = await ref
          .read(rewardedAdServiceProvider)
          .showRewardedAd(
            rewardType: resource,
            contextId: contextId,
            onAdClosed: onAdClosed,
          );
      if (!result.isRewarded) {
        state = const AsyncData(null);
        return result;
      }

      await ref
          .read(interstitialAdServiceProvider)
          .recordRewardedAdShown(
            session: ref.read(authControllerProvider).asData?.value,
          );
      try {
        await ref.read(currentSubscriptionProvider.notifier).refresh();
      } catch (_) {
        // The reward can still be consumed by the protected action even if
        // refreshing subscription UI state fails transiently.
      }
      final refreshed = await access(resource: resource, contextId: contextId);
      final granted = rewardedAccessGranted(refreshed);
      state = const AsyncData(null);
      return granted
          ? RewardedAdResult.rewarded
          : RewardedAdResult.rewardConfirmedButAccessDenied;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        if (error is DioException) {
          debugPrint(
            'Evolua rewarded unlockWithRewardedAdResult failed: '
            'resource=$resource result=${result?.name} '
            'statusCode=${error.response?.statusCode} '
            'path=${error.requestOptions.path} '
            'errorType=${error.runtimeType}',
          );
        } else {
          debugPrint(
            'Evolua rewarded unlockWithRewardedAdResult failed: '
            'resource=$resource result=${result?.name} '
            'errorType=${error.runtimeType}',
          );
        }
      }
      state = AsyncError(error, stackTrace);
      if (result?.isRewarded == true) {
        return RewardedAdResult.rewardConfirmedButAccessDenied;
      }
      return RewardedAdResult.loadFailed;
    }
  }
}
