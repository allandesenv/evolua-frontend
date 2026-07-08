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
    @visibleForTesting InterstitialAdLoader? adLoader,
    @visibleForTesting bool? platformSupported,
    @visibleForTesting String? adUnitId,
    @visibleForTesting bool? useTestAds,
    @visibleForTesting Duration readyTimeout = const Duration(seconds: 3),
    @visibleForTesting Duration showTimeout = const Duration(seconds: 8),
  }) : _preferencesReader = preferencesReader,
       _frequencyCap = frequencyCap,
       _adLoader = adLoader ?? _loadMobileInterstitialAd,
       _platformSupportedOverride = platformSupported,
       _adUnitIdOverride = adUnitId,
       _useTestAdsOverride = useTestAds,
       _readyTimeout = readyTimeout,
       _showTimeout = showTimeout;

  final Future<SharedPreferencesLike> Function() _preferencesReader;
  final InterstitialFrequencyCap _frequencyCap;
  final InterstitialAdLoader _adLoader;
  final bool? _platformSupportedOverride;
  final String? _adUnitIdOverride;
  final bool? _useTestAdsOverride;
  final Duration _readyTimeout;
  final Duration _showTimeout;

  InterstitialAdHandle? _ad;
  Future<bool>? _loadFuture;
  bool _isShowing = false;

  @override
  Future<void> preload() async {
    await _ensureLoaded();
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

    var readyAd = _ad;
    if (readyAd == null || _isShowing) {
      debugInterstitial('waitingForReadyAd trigger=${trigger.name}');
      final loaded = await _ensureLoaded().timeout(
        _readyTimeout,
        onTimeout: () {
          debugInterstitial(
            'readyTimeout trigger=${trigger.name} timeout=${_readyTimeout.inMilliseconds}ms',
          );
          return false;
        },
      );
      readyAd = _ad;
      if (!loaded || readyAd == null || _isShowing) {
        debugInterstitial('skippedNoAdReady trigger=${trigger.name}');
        unawaited(preload());
        return false;
      }
    }

    _ad = null;
    _isShowing = true;
    final completer = Completer<bool>();

    readyAd.setCallbacks(
      onShown: () {
        debugInterstitial('shown trigger=${trigger.name}');
      },
      onDismissed: () {
        debugInterstitial('dismissed trigger=${trigger.name}');
        readyAd?.dispose();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onFailedToShow: (error) {
        debugInterstitial(
          'failed to show code=${error.code} domain=${error.domain} '
          'message=${error.message}',
        );
        readyAd?.dispose();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    try {
      readyAd.show();
      final shown = await completer.future.timeout(
        _showTimeout,
        onTimeout: () {
          debugInterstitial('timeout trigger=${trigger.name}');
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

  Future<bool> _ensureLoaded() {
    if (_ad != null) {
      return Future.value(true);
    }
    if (_isShowing || !_platformSupported) {
      return Future.value(false);
    }
    final existing = _loadFuture;
    if (existing != null) {
      return existing;
    }

    final adUnitId = _adUnitId;
    if (adUnitId.trim().isEmpty) {
      debugInterstitial('skippedMissingAdUnit');
      return Future.value(false);
    }

    final future = _load(adUnitId);
    _loadFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_loadFuture, future)) {
          _loadFuture = null;
        }
      }),
    );
    return future;
  }

  Future<bool> _load(String adUnitId) async {
    debugInterstitial(
      'loadStarted platform=$_platformLabel usingTestAds=$_useTestAds '
      'adUnit=${_maskAdUnitId(adUnitId)}',
    );
    try {
      final result = await _adLoader(adUnitId);
      if (result.ad != null) {
        _ad = result.ad;
        debugInterstitial(
          'loaded platform=$_platformLabel usingTestAds=$_useTestAds '
          'adUnit=${_maskAdUnitId(adUnitId)}',
        );
        return true;
      }
      final error = result.error;
      if (error != null) {
        debugInterstitial(
          'failedToLoad code=${error.code} domain=${error.domain} '
          'message=${error.message} adUnit=${_maskAdUnitId(adUnitId)}',
        );
      } else {
        debugInterstitial('failedToLoad adUnit=${_maskAdUnitId(adUnitId)}');
      }
      return false;
    } catch (error) {
      debugInterstitial(
        'failedToLoad errorType=${error.runtimeType} '
        'adUnit=${_maskAdUnitId(adUnitId)}',
      );
      return false;
    }
  }

  bool get _platformSupported =>
      _platformSupportedOverride ?? (Platform.isAndroid || Platform.isIOS);

  String get _platformLabel {
    if (_platformSupportedOverride != null) {
      return _platformSupportedOverride ? 'test-mobile' : 'unsupported';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'unsupported';
  }

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
    final override = _adUnitIdOverride;
    if (override != null) {
      return override;
    }
    return adUnitIdFor(
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
      useTestAds: _useTestAds,
    );
  }

  bool get _useTestAds => _useTestAdsOverride ?? AppConfig.adMobUseTestAds;

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

typedef InterstitialAdLoader =
    Future<InterstitialAdLoadResult> Function(String adUnitId);

abstract class InterstitialAdHandle {
  void setCallbacks({
    required VoidCallback onShown,
    required VoidCallback onDismissed,
    required void Function(InterstitialAdErrorInfo error) onFailedToShow,
  });

  void show();

  void dispose();
}

class InterstitialAdLoadResult {
  const InterstitialAdLoadResult.loaded(this.ad) : error = null;

  const InterstitialAdLoadResult.failed(this.error) : ad = null;

  final InterstitialAdHandle? ad;
  final InterstitialAdErrorInfo? error;
}

class InterstitialAdErrorInfo {
  const InterstitialAdErrorInfo({
    required this.code,
    required this.domain,
    required this.message,
  });

  final int code;
  final String domain;
  final String message;

  factory InterstitialAdErrorInfo.fromLoadAdError(LoadAdError error) {
    return InterstitialAdErrorInfo(
      code: error.code,
      domain: error.domain,
      message: error.message,
    );
  }

  factory InterstitialAdErrorInfo.fromAdError(AdError error) {
    return InterstitialAdErrorInfo(
      code: error.code,
      domain: error.domain,
      message: error.message,
    );
  }
}

Future<InterstitialAdLoadResult> _loadMobileInterstitialAd(
  String adUnitId,
) async {
  final completer = Completer<InterstitialAdLoadResult>();
  try {
    await adMobInitializationService.ensureInitialized();
    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) {
            completer.complete(
              InterstitialAdLoadResult.loaded(_MobileInterstitialAdHandle(ad)),
            );
          }
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) {
            completer.complete(
              InterstitialAdLoadResult.failed(
                InterstitialAdErrorInfo.fromLoadAdError(error),
              ),
            );
          }
        },
      ),
    );
  } catch (error) {
    if (!completer.isCompleted) {
      completer.complete(
        InterstitialAdLoadResult.failed(
          InterstitialAdErrorInfo(
            code: -1,
            domain: 'exception',
            message: error.runtimeType.toString(),
          ),
        ),
      );
    }
  }
  return completer.future;
}

class _MobileInterstitialAdHandle implements InterstitialAdHandle {
  _MobileInterstitialAdHandle(this._ad);

  final InterstitialAd _ad;

  @override
  void setCallbacks({
    required VoidCallback onShown,
    required VoidCallback onDismissed,
    required void Function(InterstitialAdErrorInfo error) onFailedToShow,
  }) {
    _ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => onShown(),
      onAdDismissedFullScreenContent: (_) => onDismissed(),
      onAdFailedToShowFullScreenContent: (_, error) {
        onFailedToShow(InterstitialAdErrorInfo.fromAdError(error));
      },
    );
  }

  @override
  void show() {
    _ad.show();
  }

  @override
  void dispose() {
    _ad.dispose();
  }
}

String _maskAdUnitId(String adUnitId) {
  final trimmed = adUnitId.trim();
  if (trimmed.length <= 8) {
    return '***';
  }
  return '${trimmed.substring(0, 8)}...${trimmed.substring(trimmed.length - 4)}';
}
