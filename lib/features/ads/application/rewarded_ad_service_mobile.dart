import 'dart:async';
import 'dart:io';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/features/ads/application/ad_mob_initialization_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_access_grant.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

RewardedAdService createRewardedAdService(Ref ref) {
  return MobileRewardedAdService(ref.read(subscriptionRepositoryProvider));
}

class MobileRewardedAdService implements RewardedAdService {
  MobileRewardedAdService(this._repository);

  static const _ssvConfirmationAttempts = 8;
  static const _ssvConfirmationDelay = Duration(seconds: 2);
  static const _ssvMaxWaitAfterAd = Duration(seconds: 30);

  static const _extraCheckInRewardTypes = {RewardResources.extraCheckIn};
  static const _aiRewardTypes = {
    RewardResources.deepEmotionalReading,
    RewardResources.aiExtra,
  };
  static const _premiumPassRewardTypes = {
    'ADVANCED_MIRROR',
    'SMART_RECOMMENDATION',
    'SPECIAL_REPORT',
    'PREMIUM_TRAIL_STEP',
  };

  final SubscriptionRepository _repository;

  @override
  Future<RewardedAdResult> showRewardedAd({
    required String rewardType,
    String? contextId,
    void Function()? onAdClosed,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return RewardedAdResult.unsupported;
    }

    final normalizedRewardType = rewardType.trim().toUpperCase();

    final session = await _repository.createRewardSession(
      rewardType: rewardType,
      contextId: contextId,
    );

    final adUnitId = _adUnitIdFor(rewardType);
    final logicalAdUnit = _logicalAdUnitNameFor(rewardType);

    debugPrint(
      'Evolua rewarded load requested: rewardType=$normalizedRewardType '
      'logicalAdUnit=$logicalAdUnit adUnitId=${_maskAdUnitId(adUnitId)}',
    );
    await adMobInitializationService.ensureInitialized();
    debugPrint(
      'Evolua rewarded MobileAds initialized: '
      'rewardType=$normalizedRewardType logicalAdUnit=$logicalAdUnit',
    );

    final completer = Completer<_RewardedAdOutcome>();
    RewardedAd? rewardedAd;

    var earnedReward = false;
    var openedFullScreen = false;
    var adClosedCallbackCalled = false;
    _RewardedAdLifecycleFallback? lifecycleFallback;

    void completeOutcome({
      required bool opened,
      required bool earned,
      String source = 'unknown',
      RewardedAdResult? result,
    }) {
      if (completer.isCompleted) {
        return;
      }

      debugPrint(
        'Evolua rewarded completed: source=$source '
        'opened=$opened earned=$earned rewardType=$normalizedRewardType',
      );

      completer.complete(
        _RewardedAdOutcome(
          openedFullScreen: opened,
          earnedReward: earned,
          result: result,
        ),
      );
    }

    void notifyAdClosedOnce() {
      if (adClosedCallbackCalled) {
        return;
      }

      adClosedCallbackCalled = true;
      onAdClosed?.call();
    }

    lifecycleFallback = _RewardedAdLifecycleFallback(
      onResumedAfterAd: () {
        if (!openedFullScreen || completer.isCompleted) {
          return;
        }

        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (completer.isCompleted) {
            return;
          }
          if (!earnedReward) {
            return;
          }

          notifyAdClosedOnce();

          completeOutcome(
            opened: openedFullScreen,
            earned: earnedReward,
            source: 'app_lifecycle_resumed',
          );
        });
      },
    );

    WidgetsBinding.instance.addObserver(lifecycleFallback);

    try {
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
                debugPrint(
                  'Evolua rewarded showed: rewardType=$normalizedRewardType',
                );
              },
              onAdDismissedFullScreenContent: (ad) {
                debugPrint(
                  'Evolua rewarded dismissed: '
                  'rewardType=$normalizedRewardType earned=$earnedReward',
                );

                ad.dispose();
                notifyAdClosedOnce();

                completeOutcome(
                  opened: openedFullScreen,
                  earned: earnedReward,
                  source: 'onAdDismissedFullScreenContent',
                );
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint(
                  'Evolua rewarded failed to show: '
                  'rewardType=$normalizedRewardType error=$error',
                );

                ad.dispose();

                if (openedFullScreen) {
                  notifyAdClosedOnce();
                }

                completeOutcome(
                  opened: openedFullScreen,
                  earned: earnedReward,
                  source: 'onAdFailedToShowFullScreenContent',
                  result: earnedReward ? null : RewardedAdResult.showFailed,
                );
              },
            );

            ad.show(
              onUserEarnedReward: (ad, reward) {
                earnedReward = true;
                openedFullScreen = true;

                debugPrint(
                  'Evolua rewarded earned: '
                  'rewardType=$normalizedRewardType '
                  'amount=${reward.amount} type=${reward.type}',
                );
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint(
              _describeLoadError(error, rewardType, adUnitId, logicalAdUnit),
            );

            completeOutcome(
              opened: false,
              earned: false,
              source: 'onAdFailedToLoad',
              result: error.code == 3
                  ? RewardedAdResult.noFill
                  : RewardedAdResult.loadFailed,
            );
          },
        ),
      );

      final outcome = await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint(
            'Evolua rewarded timeout: '
            'rewardType=$normalizedRewardType '
            'opened=$openedFullScreen earned=$earnedReward',
          );

          rewardedAd?.dispose();

          return _RewardedAdOutcome(
            openedFullScreen: openedFullScreen,
            earnedReward: earnedReward,
            result: RewardedAdResult.timeout,
          );
        },
      );

      final failureBeforeSsv = rewardedResultBeforeSsv(
        openedFullScreen: outcome.openedFullScreen,
        earnedReward: outcome.earnedReward,
        outcomeResult: outcome.result,
      );
      if (failureBeforeSsv != null) {
        return failureBeforeSsv;
      }

      if (AppConfig.adMobUseTestAds) {
        try {
          await _repository.grantTestReward(session.id);
        } catch (error) {
          debugPrint('AdMob test reward grant failed: $error');

          return RewardedAdResult.rewardConfirmedButAccessDenied;
        }
      }

      final confirmed = await _waitForServerSideReward(
        rewardType: rewardType,
        contextId: contextId,
        maxWait: _ssvMaxWaitAfterAd,
      );

      if (confirmed) {
        debugPrint(
          'Evolua rewarded ssv confirmed: rewardType=$normalizedRewardType',
        );
        return RewardedAdResult.rewarded;
      }

      debugPrint(
        'Evolua rewarded ssv not confirmed after wait: '
        'rewardType=$normalizedRewardType',
      );
      debugPrint(
        'Evolua rewarded rewardConfirmedButAccessDenied: '
        'rewardType=$normalizedRewardType',
      );
      return RewardedAdResult.rewardConfirmedButAccessDenied;
    } finally {
      WidgetsBinding.instance.removeObserver(lifecycleFallback);
    }
  }

  String _adUnitIdFor(String rewardType) {
    return adUnitIdFor(
      rewardType: rewardType,
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
      useTestAds: AppConfig.adMobUseTestAds,
    );
  }

  String _logicalAdUnitNameFor(String rewardType) {
    final normalized = rewardType.trim().toUpperCase();
    if (AppConfig.adMobUseTestAds) {
      return Platform.isIOS ? 'ios_rewarded_test' : 'android_rewarded_test';
    }
    if (_extraCheckInRewardTypes.contains(normalized)) {
      return Platform.isIOS
          ? 'ios_rewarded_extra_check_in'
          : 'android_rewarded_extra_check_in';
    }
    if (_aiRewardTypes.contains(normalized)) {
      return Platform.isIOS
          ? 'ios_rewarded_ai_extra'
          : 'android_rewarded_ai_extra';
    }
    if (_premiumPassRewardTypes.contains(normalized)) {
      return Platform.isIOS
          ? 'ios_rewarded_premium_pass'
          : 'android_rewarded_premium_pass';
    }
    return 'unknown_rewarded';
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

    if (_extraCheckInRewardTypes.contains(normalized)) {
      return isIOS
          ? AppConfig.adMobIosRewardedExtraCheckInAdUnitId
          : AppConfig.adMobAndroidRewardedExtraCheckInAdUnitId;
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
    String logicalAdUnit,
  ) {
    final hint = switch (error.code) {
      2 =>
        'Falha de rede/carregamento do SDK. Verifique internet, Google Play Services, bloqueios de rede e disponibilidade do bloco no AdMob.',
      3 =>
        'Sem inventário no momento. Em blocos recém-criados, aguarde a ativação no AdMob ou teste com EVOLUA_ADMOB_USE_TEST_ADS=true.',
      _ => 'Falha ao carregar rewarded ad.',
    };
    final responseInfo = error.responseInfo;
    final adapterResponses = responseInfo?.adapterResponses
        ?.map(
          (adapter) =>
              '${adapter.adapterClassName}'
              '(source=${adapter.adSourceName}, '
              'latencyMs=${adapter.latencyMillis}, '
              'error=${adapter.adError})',
        )
        .join(' | ');

    return 'AdMob rewarded load failed: resource=$rewardType '
        'logicalAdUnit=$logicalAdUnit '
        'adUnitId=${_maskAdUnitId(adUnitId)} '
        'code=${error.code} domain=${error.domain} '
        'message=${error.message} '
        'responseId=${responseInfo?.responseId} '
        'mediationAdapter=${responseInfo?.mediationAdapterClassName} '
        'responseExtras=${responseInfo?.responseExtras} '
        'adapterResponses=$adapterResponses '
        'hint=$hint';
  }

  String _maskAdUnitId(String adUnitId) {
    final trimmed = adUnitId.trim();
    if (trimmed.length <= 8) {
      return trimmed.isEmpty ? '<empty>' : '***';
    }
    return '${trimmed.substring(0, 6)}...'
        '${trimmed.substring(trimmed.length - 4)}';
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

        if (rewardedAccessGranted(access)) {
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
}

class _RewardedAdLifecycleFallback extends WidgetsBindingObserver {
  _RewardedAdLifecycleFallback({required this.onResumedAfterAd});

  final VoidCallback onResumedAfterAd;
  var _wasInactiveOrPaused = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasInactiveOrPaused = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _wasInactiveOrPaused) {
      _wasInactiveOrPaused = false;
      onResumedAfterAd();
    }
  }
}

class _RewardedAdOutcome {
  const _RewardedAdOutcome({
    this.openedFullScreen = false,
    this.earnedReward = false,
    this.result,
  });

  final bool openedFullScreen;
  final bool earnedReward;
  final RewardedAdResult? result;
}

@visibleForTesting
RewardedAdResult? rewardedResultBeforeSsv({
  required bool openedFullScreen,
  required bool earnedReward,
  RewardedAdResult? outcomeResult,
}) {
  if (earnedReward) {
    return null;
  }
  if (!openedFullScreen) {
    return outcomeResult ?? RewardedAdResult.loadFailed;
  }
  return outcomeResult == RewardedAdResult.timeout
      ? RewardedAdResult.timeout
      : RewardedAdResult.dismissedWithoutReward;
}
