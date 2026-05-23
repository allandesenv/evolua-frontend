import 'dart:async';
import 'dart:io';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

RewardedAdService createRewardedAdService(Ref ref) {
  return MobileRewardedAdService(ref.read(subscriptionRepositoryProvider));
}

class MobileRewardedAdService implements RewardedAdService {
  MobileRewardedAdService(this._repository);

  static const _ssvConfirmationAttempts = 8;
  static const _ssvConfirmationDelay = Duration(seconds: 2);
  static const _aiRewardTypes = {'DEEP_EMOTIONAL_READING', 'AI_ACTION'};
  static const _premiumPassRewardTypes = {
    'ADVANCED_MIRROR',
    'SMART_RECOMMENDATION',
    'SPECIAL_REPORT',
    'PREMIUM_TRAIL_STEP',
  };

  final SubscriptionRepository _repository;

  @override
  Future<bool> showRewardedAd({
    required String rewardType,
    String? contextId,
    bool allowClientOpenedFallback = false,
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

    final completer = Completer<_RewardedAdOutcome>();
    RewardedAd? rewardedAd;
    var earnedReward = false;
    var openedFullScreen = false;
    DateTime? openedAt;

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
            onAdShowedFullScreenContent: (ad) {
              openedFullScreen = true;
              openedAt = DateTime.now();
            },
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(
                  _RewardedAdOutcome(
                    openedFullScreen: openedFullScreen,
                    earnedReward: earnedReward,
                    openedAt: openedAt,
                  ),
                );
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(
                  _RewardedAdOutcome(
                    openedFullScreen: openedFullScreen,
                    earnedReward: false,
                    openedAt: openedAt,
                  ),
                );
              }
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              earnedReward = true;
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint(_describeLoadError(error, rewardType, adUnitId));
          if (!completer.isCompleted) {
            completer.complete(const _RewardedAdOutcome());
          }
        },
      ),
    );

    final outcome = await completer.future.timeout(
      const Duration(seconds: 75),
      onTimeout: () {
        rewardedAd?.dispose();
        return _RewardedAdOutcome(
          openedFullScreen: openedFullScreen,
          earnedReward: earnedReward,
          openedAt: openedAt,
        );
      },
    );
    if (!outcome.openedFullScreen) {
      return false;
    }
    if (AppConfig.adMobUseTestAds) {
      try {
        await _repository.grantTestReward(session.id);
      } catch (error) {
        debugPrint('AdMob test reward grant failed: $error');
        return false;
      }
    }
    final remainingClientOpenedWindow = _remainingClientOpenedWindow(
      outcome.openedAt,
    );
    final confirmed = await _waitForServerSideReward(
      rewardType: rewardType,
      contextId: contextId,
      maxWait: allowClientOpenedFallback ? remainingClientOpenedWindow : null,
    );
    if (confirmed) {
      return true;
    }
    if (!allowClientOpenedFallback ||
        rewardType.trim().toUpperCase() != 'DEEP_EMOTIONAL_READING') {
      return false;
    }
    try {
      await _repository.grantClientOpenedReward(session.id);
    } catch (error) {
      debugPrint('AdMob client-opened reward grant failed: $error');
      return true;
    }
    final fallbackConfirmed = await _waitForServerSideReward(
      rewardType: rewardType,
      contextId: contextId,
      maxWait: const Duration(seconds: 4),
    );
    return fallbackConfirmed ||
        rewardType.trim().toUpperCase() == 'DEEP_EMOTIONAL_READING';
  }

  String _adUnitIdFor(String rewardType) {
    return adUnitIdFor(
      rewardType: rewardType,
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
      useTestAds: AppConfig.adMobUseTestAds,
    );
  }

  @visibleForTesting
  static String adUnitIdFor({
    required String rewardType,
    required bool isAndroid,
    required bool isIOS,
    required bool useTestAds,
  }) {
    final normalized = rewardType.trim().toUpperCase();
    if (useTestAds) {
      if (isIOS) {
        return AppConfig.adMobIosRewardedTestAdUnitId;
      }
      return AppConfig.adMobAndroidRewardedTestAdUnitId;
    }
    if (_aiRewardTypes.contains(normalized)) {
      return isIOS
          ? AppConfig.adMobIosRewardedAiExtraAdUnitId
          : AppConfig.adMobAndroidRewardedAiExtraAdUnitId;
    }
    if (_premiumPassRewardTypes.contains(normalized)) {
      return isIOS
          ? AppConfig.adMobIosRewardedPremiumPassAdUnitId
          : AppConfig.adMobAndroidRewardedPremiumPassAdUnitId;
    }
    throw UnsupportedError(
      'Rewarded ad is not configured for resource "$normalized".',
    );
  }

  String _describeLoadError(
    LoadAdError error,
    String rewardType,
    String adUnitId,
  ) {
    final hint = switch (error.code) {
      2 =>
        'Falha de rede/carregamento do SDK. Verifique internet, Google Play Services, bloqueios de rede e disponibilidade do bloco no AdMob.',
      3 =>
        'Sem inventario no momento. Em blocos recem-criados, aguarde a ativacao no AdMob ou teste com EVOLUA_ADMOB_USE_TEST_ADS=true.',
      _ => 'Falha ao carregar rewarded ad.',
    };
    return 'AdMob rewarded load failed: resource=$rewardType '
        'adUnitId=$adUnitId code=${error.code} domain=${error.domain} '
        'message=${error.message} responseInfo=${error.responseInfo} '
        'hint=$hint';
  }

  Future<bool> _waitForServerSideReward({
    required String rewardType,
    String? contextId,
    Duration? maxWait,
  }) async {
    final deadline = maxWait == null ? null : DateTime.now().add(maxWait);
    var attempt = 0;
    while (true) {
      try {
        final access = await _repository.monetizationAccess(
          resource: rewardType,
          contextId: contextId,
        );
        if (access.allowed || access.entitlementExpiresAt != null) {
          return true;
        }
      } catch (_) {
        if (deadline == null && attempt >= _ssvConfirmationAttempts - 1) {
          rethrow;
        }
      }
      attempt++;
      if (deadline == null && attempt >= _ssvConfirmationAttempts) {
        return false;
      }
      if (deadline != null && DateTime.now().isAfter(deadline)) {
        return false;
      }
      await Future<void>.delayed(_ssvConfirmationDelay);
    }
  }

  Duration _remainingClientOpenedWindow(DateTime? openedAt) {
    if (openedAt == null) {
      return Duration.zero;
    }
    final elapsed = DateTime.now().difference(openedAt);
    final remaining = const Duration(seconds: 80) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class _RewardedAdOutcome {
  const _RewardedAdOutcome({
    this.openedFullScreen = false,
    this.earnedReward = false,
    this.openedAt,
  });

  final bool openedFullScreen;
  final bool earnedReward;
  final DateTime? openedAt;
}
