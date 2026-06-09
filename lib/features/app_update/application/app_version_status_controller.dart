import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/app_update/application/app_update_platform.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

final appVersionDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(baseUrl: AppConfig.versionStatusBaseUrl));
});

final appUpdateClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final appUpdatePlatformProvider = Provider<String>((ref) {
  return currentAppUpdatePlatform();
});

final appVersionStatusProvider =
    AsyncNotifierProvider<AppVersionStatusController, AppVersionCheckState>(
      AppVersionStatusController.new,
    );

final disabledAppFeaturesProvider = Provider<List<String>>((ref) {
  return ref.watch(appVersionStatusProvider).asData?.value.disabledFeatures ??
      const [];
});

class AppVersionStatusController extends AsyncNotifier<AppVersionCheckState> {
  static const Duration requiredCacheTtl = Duration(hours: 24);

  @override
  Future<AppVersionCheckState> build() async {
    if (!AppConfig.appUpdateCheckEnabled) {
      return AppVersionCheckState.disabled();
    }

    final packageInfo = await ref.watch(packageInfoProvider.future);
    final platform = ref.watch(appUpdatePlatformProvider);
    final versionCode = int.tryParse(packageInfo.buildNumber.trim()) ?? 0;
    final versionName = packageInfo.version;
    final cacheKey = RequiredUpdateCache.cacheKey(
      platform: platform,
      versionCode: versionCode,
      apiBaseUrl: AppConfig.versionStatusBaseUrl,
    );
    final preferences = await ref.watch(sharedPreferencesProvider.future);
    final cache = RequiredUpdateCache(preferences);

    try {
      final dio = ref.read(appVersionDioProvider);
      final response = await dio.get<dynamic>(
        '/v1/app/version-status',
        queryParameters: {
          'platform': platform,
          'versionCode': versionCode,
          'versionName': versionName,
        },
      );
      final status = AppVersionStatus.fromJson(
        ApiPayloadParser.dataMap(response.data),
      );
      if (status.updateRequired) {
        await cache.write(
          key: cacheKey,
          status: status,
          storedAt: ref.read(appUpdateClockProvider)(),
        );
      } else {
        await cache.clear(cacheKey);
      }
      return AppVersionCheckState(
        status: status,
        platform: platform,
        versionCode: versionCode,
        versionName: versionName,
        cacheKey: cacheKey,
        fromCache: false,
        endpointFailed: false,
        disabled: false,
      );
    } catch (error) {
      _debugLog('version status failed: $error');
      final cached = cache.read(
        key: cacheKey,
        now: ref.read(appUpdateClockProvider)(),
        ttl: requiredCacheTtl,
      );
      if (cached != null && cached.updateRequired) {
        return AppVersionCheckState(
          status: cached,
          platform: platform,
          versionCode: versionCode,
          versionName: versionName,
          cacheKey: cacheKey,
          fromCache: true,
          endpointFailed: true,
          disabled: false,
        );
      }
      return AppVersionCheckState(
        status: AppVersionStatus.none(),
        platform: platform,
        versionCode: versionCode,
        versionName: versionName,
        cacheKey: cacheKey,
        fromCache: false,
        endpointFailed: true,
        disabled: false,
      );
    }
  }

  void _debugLog(String message) {
    if (!kReleaseMode) {
      debugPrint('[app-update] $message');
    }
  }
}

class AppVersionCheckState {
  const AppVersionCheckState({
    required this.status,
    required this.platform,
    required this.versionCode,
    required this.versionName,
    required this.cacheKey,
    required this.fromCache,
    required this.endpointFailed,
    required this.disabled,
  });

  factory AppVersionCheckState.disabled() {
    return AppVersionCheckState(
      status: AppVersionStatus.none(),
      platform: 'web',
      versionCode: 0,
      versionName: '',
      cacheKey: '',
      fromCache: false,
      endpointFailed: false,
      disabled: true,
    );
  }

  final AppVersionStatus status;
  final String platform;
  final int versionCode;
  final String versionName;
  final String cacheKey;
  final bool fromCache;
  final bool endpointFailed;
  final bool disabled;

  List<String> get disabledFeatures => status.disabledFeatures;
}

enum UpdateMode {
  none,
  flexible,
  immediate,
  store;

  static UpdateMode fromJson(Object? value) {
    return switch (value?.toString().toLowerCase()) {
      'flexible' => UpdateMode.flexible,
      'immediate' => UpdateMode.immediate,
      'store' => UpdateMode.store,
      _ => UpdateMode.none,
    };
  }
}

class AppVersionStatus {
  const AppVersionStatus({
    required this.latestVersionCode,
    required this.minimumSupportedVersionCode,
    required this.updateRecommended,
    required this.updateRequired,
    required this.updateMode,
    required this.message,
    required this.storeUrl,
    required this.disabledFeatures,
    required this.maintenanceMode,
  });

  factory AppVersionStatus.none() {
    return const AppVersionStatus(
      latestVersionCode: 0,
      minimumSupportedVersionCode: 0,
      updateRecommended: false,
      updateRequired: false,
      updateMode: UpdateMode.none,
      message: '',
      storeUrl: AppConfig.evoluaPlayStoreUrl,
      disabledFeatures: [],
      maintenanceMode: false,
    );
  }

  factory AppVersionStatus.fromJson(Map<String, dynamic> json) {
    return AppVersionStatus(
      latestVersionCode: (json['latestVersionCode'] as num?)?.toInt() ?? 0,
      minimumSupportedVersionCode:
          (json['minimumSupportedVersionCode'] as num?)?.toInt() ?? 0,
      updateRecommended: json['updateRecommended'] as bool? ?? false,
      updateRequired: json['updateRequired'] as bool? ?? false,
      updateMode: UpdateMode.fromJson(json['updateMode']),
      message: json['message']?.toString() ?? '',
      storeUrl: (json['storeUrl']?.toString().trim().isNotEmpty ?? false)
          ? json['storeUrl'].toString()
          : AppConfig.evoluaPlayStoreUrl,
      disabledFeatures: (json['disabledFeatures'] as List? ?? const [])
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latestVersionCode': latestVersionCode,
      'minimumSupportedVersionCode': minimumSupportedVersionCode,
      'updateRecommended': updateRecommended,
      'updateRequired': updateRequired,
      'updateMode': updateMode.name,
      'message': message,
      'storeUrl': storeUrl,
      'disabledFeatures': disabledFeatures,
      'maintenanceMode': maintenanceMode,
    };
  }

  final int latestVersionCode;
  final int minimumSupportedVersionCode;
  final bool updateRecommended;
  final bool updateRequired;
  final UpdateMode updateMode;
  final String message;
  final String storeUrl;
  final List<String> disabledFeatures;
  final bool maintenanceMode;
}

class RequiredUpdateCache {
  RequiredUpdateCache(this._preferences);

  final SharedPreferences _preferences;

  static String cacheKey({
    required String platform,
    required int versionCode,
    required String apiBaseUrl,
  }) {
    return 'evolua.required-update.$platform.$versionCode.${Uri.encodeComponent(apiBaseUrl)}';
  }

  Future<void> write({
    required String key,
    required AppVersionStatus status,
    required DateTime storedAt,
  }) async {
    await _preferences.setString(
      '$key.status.updateMode',
      status.updateMode.name,
    );
    await _preferences.setInt('$key.status.latest', status.latestVersionCode);
    await _preferences.setInt(
      '$key.status.minimum',
      status.minimumSupportedVersionCode,
    );
    await _preferences.setString('$key.status.message', status.message);
    await _preferences.setString('$key.status.storeUrl', status.storeUrl);
    await _preferences.setStringList(
      '$key.status.disabledFeatures',
      status.disabledFeatures,
    );
    await _preferences.setBool(
      '$key.status.maintenanceMode',
      status.maintenanceMode,
    );
    await _preferences.setInt('$key.storedAt', storedAt.millisecondsSinceEpoch);
  }

  AppVersionStatus? read({
    required String key,
    required DateTime now,
    required Duration ttl,
  }) {
    final storedAtMillis = _preferences.getInt('$key.storedAt');
    if (storedAtMillis == null) {
      return null;
    }
    final storedAt = DateTime.fromMillisecondsSinceEpoch(storedAtMillis);
    if (now.difference(storedAt) > ttl) {
      return null;
    }
    return AppVersionStatus(
      latestVersionCode: _preferences.getInt('$key.status.latest') ?? 0,
      minimumSupportedVersionCode:
          _preferences.getInt('$key.status.minimum') ?? 0,
      updateRecommended: false,
      updateRequired: true,
      updateMode: UpdateMode.fromJson(
        _preferences.getString('$key.status.updateMode'),
      ),
      message: _preferences.getString('$key.status.message') ?? '',
      storeUrl:
          _preferences.getString('$key.status.storeUrl') ??
          AppConfig.evoluaPlayStoreUrl,
      disabledFeatures:
          _preferences.getStringList('$key.status.disabledFeatures') ??
          const [],
      maintenanceMode:
          _preferences.getBool('$key.status.maintenanceMode') ?? false,
    );
  }

  Future<void> clear(String key) async {
    await _preferences.remove('$key.status.updateMode');
    await _preferences.remove('$key.status.latest');
    await _preferences.remove('$key.status.minimum');
    await _preferences.remove('$key.status.message');
    await _preferences.remove('$key.status.storeUrl');
    await _preferences.remove('$key.status.disabledFeatures');
    await _preferences.remove('$key.status.maintenanceMode');
    await _preferences.remove('$key.storedAt');
  }
}
