import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobInitializationService {
  AdMobInitializationService();

  Future<InitializationStatus>? _initialization;
  bool _loggedAdapterStatuses = false;

  Future<InitializationStatus> ensureInitialized() {
    return _initialization ??= _initialize();
  }

  Future<InitializationStatus> _initialize() async {
    await _prepareNetworkPrivacySignals();
    final status = await MobileAds.instance.initialize();
    _logAdapterStatuses(status);
    return status;
  }

  Future<void> _prepareNetworkPrivacySignals() async {
    // Keep current consent behavior. Network-specific consent calls should be
    // wired here before MobileAds initialization when a consent source exists.
  }

  void _logAdapterStatuses(InitializationStatus status) {
    if (!kDebugMode || _loggedAdapterStatuses) {
      return;
    }
    _loggedAdapterStatuses = true;
    for (final entry in status.adapterStatuses.entries) {
      final adapter = entry.key;
      final state = entry.value.state.name;
      final latency = entry.value.latency;
      final description = entry.value.description;
      debugPrint(
        'Evolua AdMob adapter: $adapter state=$state '
        'latency=${latency}ms description=$description',
      );
    }
  }
}

final adMobInitializationService = AdMobInitializationService();
