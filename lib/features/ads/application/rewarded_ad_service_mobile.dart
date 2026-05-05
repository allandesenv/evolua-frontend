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

  final SubscriptionRepository _repository;

  @override
  Future<bool> showRewardedAd({required String rewardType}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    final session = await _repository.createRewardSession(rewardType: rewardType);
    final adUnitId = Platform.isIOS
        ? AppConfig.adMobIosRewardedAdUnitId
        : AppConfig.adMobAndroidRewardedAdUnitId;

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

    return completer.future.timeout(
      const Duration(seconds: 75),
      onTimeout: () {
        rewardedAd?.dispose();
        return earnedReward;
      },
    );
  }
}
