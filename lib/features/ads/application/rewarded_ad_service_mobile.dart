import 'dart:async';
import 'dart:io';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

RewardedAdService createRewardedAdService(Ref ref) {
  return MobileRewardedAdService(ref.read(subscriptionRepositoryProvider));
}

class MobileRewardedAdService implements RewardedAdService {
  MobileRewardedAdService(this._repository);

  static const _ssvConfirmationAttempts = 8;
  static const _ssvConfirmationDelay = Duration(seconds: 2);

  final SubscriptionRepository _repository;

  @override
  Future<bool> showRewardedAd({
    required String rewardType,
    String? contextId,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    final session = await _repository.createRewardSession(
      rewardType: rewardType,
      contextId: contextId,
    );
    final adUnitId = _adUnitIdFor(rewardType);

    await MobileAds.instance.initialize();

    final completer = Completer<bool>();
    RewardedAd? rewardedAd;
    var earnedReward = false;

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          rewardedAd = ad;
          ad.setServerSideOptions(
            ServerSideVerificationOptions(customData: session.customData),
          );
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(earnedReward);
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              earnedReward = true;
            },
          );
        },
        onAdFailedToLoad: (_) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      ),
    );

    final earned = await completer.future.timeout(
      const Duration(seconds: 75),
      onTimeout: () {
        rewardedAd?.dispose();
        return earnedReward;
      },
    );
    if (!earned) {
      return false;
    }
    return _waitForServerSideReward(
      rewardType: rewardType,
      contextId: contextId,
    );
  }

  String _adUnitIdFor(String rewardType) {
    final normalized = rewardType.trim().toUpperCase();
    if (Platform.isIOS) {
      return switch (normalized) {
        'DEEP_EMOTIONAL_READING' ||
        'AI_ACTION' => AppConfig.adMobIosRewardedAiExtraAdUnitId,
        'PREMIUM_TRAIL_STEP' => AppConfig.adMobIosRewardedPremiumPassAdUnitId,
        _ => AppConfig.adMobIosRewardedAdUnitId,
      };
    }
    return switch (normalized) {
      'DEEP_EMOTIONAL_READING' ||
      'AI_ACTION' => AppConfig.adMobAndroidRewardedAiExtraAdUnitId,
      'PREMIUM_TRAIL_STEP' => AppConfig.adMobAndroidRewardedPremiumPassAdUnitId,
      _ => AppConfig.adMobAndroidRewardedAdUnitId,
    };
  }

  Future<bool> _waitForServerSideReward({
    required String rewardType,
    String? contextId,
  }) async {
    for (var attempt = 0; attempt < _ssvConfirmationAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_ssvConfirmationDelay);
      }
      try {
        final access = await _repository.monetizationAccess(
          resource: rewardType,
          contextId: contextId,
        );
        if (access.allowed || access.entitlementExpiresAt != null) {
          return true;
        }
      } catch (_) {
        if (attempt == _ssvConfirmationAttempts - 1) {
          rethrow;
        }
      }
    }
    return false;
  }
}
