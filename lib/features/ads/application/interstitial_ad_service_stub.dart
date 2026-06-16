import 'package:evolua_frontend/features/ads/application/interstitial_ad_service_base.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

InterstitialAdService createInterstitialAdService(Ref ref) {
  return const WebInterstitialAdService();
}

class WebInterstitialAdService implements InterstitialAdService {
  const WebInterstitialAdService();

  @override
  Future<void> preload() async {}

  @override
  Future<bool> maybeShow({
    required InterstitialTrigger trigger,
    required AuthSession? session,
  }) async {
    debugInterstitial('skippedUnsupportedPlatform');
    return false;
  }

  @override
  Future<void> recordRewardedAdShown({AuthSession? session}) async {}

  @override
  void dispose() {}
}
