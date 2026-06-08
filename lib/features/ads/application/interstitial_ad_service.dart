import 'package:evolua_frontend/features/ads/application/interstitial_ad_service_base.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service_stub.dart'
    if (dart.library.io) 'package:evolua_frontend/features/ads/application/interstitial_ad_service_mobile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final interstitialAdServiceProvider = Provider<InterstitialAdService>((ref) {
  final service = createInterstitialAdService(ref);
  ref.onDispose(service.dispose);
  return service;
});
