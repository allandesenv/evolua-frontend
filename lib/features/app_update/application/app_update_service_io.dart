import 'dart:io' show Platform;

import 'package:evolua_frontend/features/app_update/application/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

AppUpdateService createAppUpdateService() => const IoAppUpdateService();

class IoAppUpdateService implements AppUpdateService {
  const IoAppUpdateService();

  @override
  Future<bool> startFlexibleUpdate() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable ||
          !info.flexibleUpdateAllowed) {
        return false;
      }
      await InAppUpdate.startFlexibleUpdate();
      await InAppUpdate.completeFlexibleUpdate();
      return true;
    } catch (error) {
      _debugLog('flexible update failed: $error');
      return false;
    }
  }

  @override
  Future<bool> performImmediateUpdate() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable ||
          !info.immediateUpdateAllowed) {
        return false;
      }
      await InAppUpdate.performImmediateUpdate();
      return true;
    } catch (error) {
      _debugLog('immediate update failed: $error');
      return false;
    }
  }

  @override
  Future<bool> openStore(String storeUrl) async {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) {
      return false;
    }
    try {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      _debugLog('store fallback failed: $error');
      return false;
    }
  }

  void _debugLog(String message) {
    if (!kReleaseMode) {
      debugPrint('[app-update] $message');
    }
  }
}
