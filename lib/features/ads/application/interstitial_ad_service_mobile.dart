import 'dart:async';
import 'dart:io';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/features/ads/application/ad_mob_initialization_service.dart';
import 'package:evolua_frontend/features/ads/application/ad_placement_policy.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service_base.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

InterstitialAdService createInterstitialAdService(Ref ref) {
  return MobileInterstitialAdService(
    preferencesReader: () => ref.read(sharedPreferencesProvider.future),
  );
}

class MobileInterstitialAdService implements InterstitialAdService {
  MobileInterstitialAdService({
    required Future<SharedPreferencesLike> Function() preferencesReader,
    InterstitialFrequencyCap frequencyCap = const InterstitialFrequencyCap(),
  }) : _preferencesReader = preferencesReader,
       _frequencyCap = frequencyCap;

  final Future<SharedPreferencesLike> Function() _preferencesReader;
  final InterstitialFrequencyCap _frequencyCap;

  InterstitialAd? _ad;
  bool _isLoading = false;
  bool _isShowing = false;

  @override
  Future<void> preload() async {
    if (_ad != null || _isLoading || _isShowing || !_platformSupported) {
      return;
    }
    final adUnitId = _adUnitId;
    if (adUnitId.trim().isEmpty) {
      debugInterstitial('skippedMissingAdUnit');
      return;
    }

    _isLoading = true;
    debugInterstitial('loadStarted');
    await adMobInitializationService.ensureInitialized();
    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          _ad = ad;
          debugInterstitial('loaded');
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _ad = null;
          debugInterstitial(
            'failedToLoad code=${error.code} domain=${error.domain} '
            'message=${error.message}',
          );
        },
      ),
    );
  }

  @override
  Future<bool> maybeShow({
    required InterstitialTrigger trigger,
    required AuthSession? session,
  }) async {
    if (!_platformSupported) {
      debugInterstitial('skippedUnsupportedPlatform');
      return false;
    }
    final currentSession = session;
    if (currentSession == null) {
      debugInterstitial('skippedMissingSession');
      return false;
    }
    if (isAdFreeSession(currentSession)) {
      debugInterstitial('skippedForPremium trigger=${trigger.name}');
      return false;
    }
    if (!InterstitialPlacementConfig.isEnabled(trigger)) {
      debugInterstitial('skippedDisabledPlacement trigger=${trigger.name}');
      return false;
    }
    if (!AdPlacementPolicy.canShow(
      format: AdFormat.interstitial,
      context: trigger.context,
      premium: isAdFreeSession(currentSession),
      interstitialEnabled: true,
    )) {
      debugInterstitial('skippedDisabledPlacement trigger=${trigger.name}');
      return false;
    }

    final preferences = await _preferencesReader();
    final decision = await _frequencyCap.checkAndRecordAction(
      preferences: preferences,
      userId: currentSession.userId,
      now: DateTime.now(),
    );
    if (!decision.allowed) {
      debugInterstitial(
        'skippedByCooldown trigger=${trigger.name} reason=${decision.reason}',
      );
      return false;
    }

    final readyAd = _ad;
    if (readyAd == null || _isShowing) {
      debugInterstitial('skippedNoAdReady trigger=${trigger.name}');
      unawaited(preload());
      return false;
    }

    _ad = null;
    _isShowing = true;
    final completer = Completer<bool>();

    readyAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugInterstitial('shown trigger=${trigger.name}');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugInterstitial('dismissed trigger=${trigger.name}');
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugInterstitial(
          'failed to show code=${error.code} domain=${error.domain} '
          'message=${error.message}',
        );
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    try {
      readyAd.show();
      final shown = await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugInterstitial('timeout');
          return false;
        },
      );
      if (shown) {
        await _frequencyCap.recordShown(
          preferences: preferences,
          userId: currentSession.userId,
          now: DateTime.now(),
        );
      }
      return shown;
    } finally {
      _isShowing = false;
      unawaited(preload());
    }
  }

  @override
  Future<void> recordRewardedAdShown({AuthSession? session}) async {
    final currentSession = session;
    if (currentSession == null) {
      return;
    }
    final preferences = await _preferencesReader();
    await _frequencyCap.recordRewarded(
      preferences: preferences,
      userId: currentSession.userId,
      now: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
  }

  bool get _platformSupported => Platform.isAndroid || Platform.isIOS;

  @visibleForTesting
  static bool isAdFreeSession(AuthSession session) {
    if (session.isPremium) {
      return true;
    }
    return session.roles.any((role) {
      final normalized = role.trim().toUpperCase();
      return normalized == 'ROLE_FOUNDER' ||
          normalized == 'ROLE_FOUNDING_MEMBER' ||
          normalized == 'ROLE_FUNDADOR';
    });
  }

  String get _adUnitId {
    return adUnitIdFor(
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
      useTestAds: AppConfig.adMobUseTestAds,
    );
  }

  @visibleForTesting
  static String adUnitIdFor({
    required bool isAndroid,
    required bool isIOS,
    required bool useTestAds,
  }) {
    return InterstitialFrequencyCap.adUnitIdFor(
      isAndroid: isAndroid,
      isIOS: isIOS,
      useTestAds: useTestAds,
      androidRealAdUnitId: AppConfig.adMobAndroidInterstitialFreeAdUnitId,
      iosRealAdUnitId: AppConfig.adMobIosInterstitialFreeAdUnitId,
      androidTestAdUnitId: AppConfig.adMobAndroidInterstitialTestAdUnitId,
      iosTestAdUnitId: AppConfig.adMobIosInterstitialTestAdUnitId,
    );
  }
}

typedef SharedPreferencesLike = SharedPreferences;
