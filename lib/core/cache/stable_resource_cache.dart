import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StableResource {
  planCatalog('plan_catalog'),
  appVersionStatus('app_version_status'),
  supportConfig('support_config'),
  trailCatalog('trail_catalog');

  const StableResource(this.storageName);

  final String storageName;
}

class StableResourceCacheContext {
  const StableResourceCacheContext({
    required this.appVersion,
    required this.locale,
  });

  final String appVersion;
  final String locale;
}

final stableResourceClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final stableResourceCacheContextProvider =
    FutureProvider<StableResourceCacheContext>((ref) async {
      String appVersion = 'unknown';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {
        // Unit tests may not install package_info_plus mocks.
      }

      final locale = PlatformDispatcher.instance.locale.toLanguageTag();
      return StableResourceCacheContext(appVersion: appVersion, locale: locale);
    });

final stableResourceCacheProvider = FutureProvider<StableResourceCache>((
  ref,
) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return StableResourceCache(
    preferences,
    now: ref.watch(stableResourceClockProvider),
  );
});

class StableResourceCache {
  StableResourceCache(this._preferences, {required DateTime Function() now})
    : _now = now;

  static const schemaVersion = 1;
  static const maxPayloadBytes = 256 * 1024;
  static const _keyPrefix = 'evolua.stable-resource-cache.v1';
  static const _maxEntriesPerResource = 20;

  final SharedPreferences _preferences;
  final DateTime Function() _now;
  final Map<String, Future<Object?>> _inFlight = {};
  final Map<String, int> _writeGeneration = {};

  Future<T> getOrFetch<T>({
    required StableResource resource,
    required Dio dio,
    required String path,
    Map<String, Object?> queryParameters = const {},
    required String appVersion,
    required String locale,
    String? userId,
    required Duration ttl,
    required Duration maxStale,
    required bool force,
    required Object? Function(dynamic responseData) extractPayload,
    required T Function(Object? payload) decodePayload,
    bool Function()? canWrite,
  }) async {
    final key = StableCacheKey(
      resource: resource,
      baseUrl: dio.options.baseUrl,
      path: path,
      queryParameters: queryParameters,
      appVersion: appVersion,
      locale: locale,
      userId: userId,
    );

    StableCacheEntry? entry;
    try {
      entry = read(key);
      if (!force && entry != null && entry.isFresh(_now(), ttl)) {
        return decodePayload(entry.payload);
      }
    } catch (_) {
      await remove(key);
      entry = null;
    }

    final existing = _inFlight[key.storageKey];
    if (existing != null) {
      return await existing as T;
    }

    final generation = (_writeGeneration[key.storageKey] ?? 0) + 1;
    _writeGeneration[key.storageKey] = generation;

    final future = _fetchAndCache(
      key: key,
      dio: dio,
      path: path,
      queryParameters: queryParameters,
      ttl: ttl,
      maxStale: maxStale,
      existingEntry: entry,
      generation: generation,
      extractPayload: extractPayload,
      decodePayload: decodePayload,
      canWrite: canWrite,
    );
    _inFlight[key.storageKey] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[key.storageKey], future)) {
        _inFlight.remove(key.storageKey);
      }
    }
  }

  StableCacheEntry? read(StableCacheKey key) {
    final raw = _preferences.getString(key.storageKey);
    if (raw == null) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Envelope invalido.');
    }

    final schema = decoded['schemaVersion'] as int?;
    if (schema != schemaVersion) {
      throw const FormatException('Schema de cache desconhecido.');
    }

    if (decoded['resource'] != key.resource.storageName ||
        decoded['cacheKey'] != key.canonical ||
        decoded['appVersion'] != key.appVersion ||
        decoded['locale'] != key.locale) {
      throw const FormatException('Envelope nao corresponde a chave.');
    }

    final cachedAtRaw = decoded['cachedAtUtc']?.toString();
    final cachedAt = cachedAtRaw == null
        ? null
        : DateTime.tryParse(cachedAtRaw)?.toUtc();
    if (cachedAt == null || cachedAt.isAfter(_now().toUtc())) {
      throw const FormatException('Timestamp de cache invalido.');
    }

    return StableCacheEntry(
      key: key,
      cachedAtUtc: cachedAt,
      etag: _nonEmpty(decoded['etag']),
      payload: decoded['payload'],
    );
  }

  Future<void> write({
    required StableCacheKey key,
    required Object? payload,
    required String? etag,
    DateTime? cachedAtUtc,
  }) async {
    final now = (cachedAtUtc ?? _now()).toUtc();
    final envelope = <String, Object?>{
      'schemaVersion': schemaVersion,
      'resource': key.resource.storageName,
      'cacheKey': key.canonical,
      'cachedAtUtc': now.toIso8601String(),
      'appVersion': key.appVersion,
      'locale': key.locale,
      'userId': key.userId,
      'etag': _nonEmpty(etag),
      'payload': payload,
    };
    final encoded = jsonEncode(envelope);
    if (utf8.encode(encoded).length > maxPayloadBytes) {
      await remove(key);
      return;
    }

    await _preferences.setString(key.storageKey, encoded);
    await _remember(key);
    await _prune(key.resource);
  }

  Future<void> touch304(StableCacheEntry entry) {
    return write(
      key: entry.key,
      payload: entry.payload,
      etag: entry.etag,
      cachedAtUtc: _now().toUtc(),
    );
  }

  Future<void> remove(StableCacheKey key) async {
    await _preferences.remove(key.storageKey);
    final indexKey = _indexKey(key.resource);
    final keys = _preferences.getStringList(indexKey) ?? const [];
    if (keys.contains(key.storageKey)) {
      await _preferences.setStringList(
        indexKey,
        keys.where((item) => item != key.storageKey).toList(),
      );
    }
  }

  Future<void> invalidateResource(StableResource resource) async {
    final indexKey = _indexKey(resource);
    final keys = _preferences.getStringList(indexKey) ?? const [];
    for (final key in keys) {
      await _preferences.remove(key);
    }
    await _preferences.remove(indexKey);
  }

  Future<void> invalidateUserResource({
    required StableResource resource,
    required String userId,
  }) async {
    final indexKey = _indexKey(resource);
    final keys = _preferences.getStringList(indexKey) ?? const [];
    final remaining = <String>[];
    for (final storageKey in keys) {
      final raw = _preferences.getString(storageKey);
      var matchesUser = false;
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          matchesUser =
              decoded is Map<String, dynamic> && decoded['userId'] == userId;
        } catch (_) {
          matchesUser = true;
        }
      }
      if (matchesUser) {
        await _preferences.remove(storageKey);
      } else {
        remaining.add(storageKey);
      }
    }
    await _preferences.setStringList(indexKey, remaining);
  }

  Future<T> _fetchAndCache<T>({
    required StableCacheKey key,
    required Dio dio,
    required String path,
    required Map<String, Object?> queryParameters,
    required Duration ttl,
    required Duration maxStale,
    required StableCacheEntry? existingEntry,
    required int generation,
    required Object? Function(dynamic responseData) extractPayload,
    required T Function(Object? payload) decodePayload,
    required bool Function()? canWrite,
  }) async {
    try {
      final response = await _request(
        dio: dio,
        path: path,
        queryParameters: queryParameters,
        etag: existingEntry?.etag,
      );

      if (response.statusCode == 304) {
        final entry = existingEntry;
        if (entry != null) {
          if (_canWrite(key, generation, canWrite)) {
            await touch304(entry);
          }
          return decodePayload(entry.payload);
        }
        final retry = await _request(
          dio: dio,
          path: path,
          queryParameters: queryParameters,
          etag: null,
        );
        return _handleSuccess(
          key: key,
          response: retry,
          generation: generation,
          extractPayload: extractPayload,
          decodePayload: decodePayload,
          canWrite: canWrite,
        );
      }

      return _handleSuccess(
        key: key,
        response: response,
        generation: generation,
        extractPayload: extractPayload,
        decodePayload: decodePayload,
        canWrite: canWrite,
      );
    } on DioException catch (error) {
      if (_isUnauthorized(error)) {
        rethrow;
      }
      final entry = existingEntry;
      if (_isTransient(error) &&
          entry != null &&
          maxStale > Duration.zero &&
          entry.isFresh(_now(), maxStale)) {
        return decodePayload(entry.payload);
      }
      rethrow;
    } on FormatException {
      await remove(key);
      rethrow;
    }
  }

  Future<T> _handleSuccess<T>({
    required StableCacheKey key,
    required Response<dynamic> response,
    required int generation,
    required Object? Function(dynamic responseData) extractPayload,
    required T Function(Object? payload) decodePayload,
    required bool Function()? canWrite,
  }) async {
    final payload = extractPayload(response.data);
    final value = decodePayload(payload);
    if (_canWrite(key, generation, canWrite)) {
      await write(
        key: key,
        payload: payload,
        etag: response.headers.value('etag'),
      );
    }
    return value;
  }

  Future<Response<dynamic>> _request({
    required Dio dio,
    required String path,
    required Map<String, Object?> queryParameters,
    required String? etag,
  }) {
    return dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: Options(
        headers: etag == null ? null : {'If-None-Match': etag},
        validateStatus: (status) {
          if (status == null) {
            return false;
          }
          return status == 304 || (status >= 200 && status < 300);
        },
      ),
    );
  }

  bool _canWrite(
    StableCacheKey key,
    int generation,
    bool Function()? canWrite,
  ) {
    return _writeGeneration[key.storageKey] == generation &&
        (canWrite == null || canWrite());
  }

  Future<void> _remember(StableCacheKey key) async {
    final indexKey = _indexKey(key.resource);
    final keys = _preferences.getStringList(indexKey) ?? const [];
    final next = <String>[
      key.storageKey,
      ...keys.where((item) => item != key.storageKey),
    ];
    await _preferences.setStringList(indexKey, next);
  }

  Future<void> _prune(StableResource resource) async {
    final indexKey = _indexKey(resource);
    final keys = _preferences.getStringList(indexKey) ?? const [];
    final valid = <String>[];
    for (final key in keys) {
      final raw = _preferences.getString(key);
      if (raw == null) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            decoded['schemaVersion'] == schemaVersion &&
            decoded['resource'] == resource.storageName) {
          valid.add(key);
          continue;
        }
      } catch (_) {
        // Remove malformed entries below.
      }
      await _preferences.remove(key);
    }

    for (final key in valid.skip(_maxEntriesPerResource)) {
      await _preferences.remove(key);
    }
    await _preferences.setStringList(
      indexKey,
      valid.take(_maxEntriesPerResource).toList(),
    );
  }

  bool _isUnauthorized(DioException error) {
    final status = error.response?.statusCode;
    return status == 401 || status == 403;
  }

  bool _isTransient(DioException error) {
    final status = error.response?.statusCode;
    if (status == 408 || status == 429 || (status != null && status >= 500)) {
      return true;
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    };
  }

  String _indexKey(StableResource resource) {
    return '$_keyPrefix.index.${resource.storageName}';
  }

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class StableCacheEntry {
  const StableCacheEntry({
    required this.key,
    required this.cachedAtUtc,
    required this.etag,
    required this.payload,
  });

  final StableCacheKey key;
  final DateTime cachedAtUtc;
  final String? etag;
  final Object? payload;

  bool isFresh(DateTime now, Duration ttl) {
    final current = now.toUtc();
    if (cachedAtUtc.isAfter(current)) {
      return false;
    }
    return current.difference(cachedAtUtc) <= ttl;
  }
}

class StableCacheKey {
  StableCacheKey({
    required this.resource,
    required String baseUrl,
    required String path,
    required Map<String, Object?> queryParameters,
    required this.appVersion,
    required this.locale,
    this.userId,
  }) : uri = _canonicalUri(baseUrl, path, queryParameters);

  final StableResource resource;
  final Uri uri;
  final String appVersion;
  final String locale;
  final String? userId;

  String get canonical {
    return jsonEncode({
      'resource': resource.storageName,
      'uri': uri.toString(),
      'appVersion': appVersion,
      'locale': locale,
      if (userId != null) 'userId': userId,
    });
  }

  String get storageKey {
    return '${StableResourceCache._keyPrefix}.${resource.storageName}.${base64Url.encode(utf8.encode(canonical))}';
  }

  static Uri _canonicalUri(
    String baseUrl,
    String path,
    Map<String, Object?> queryParameters,
  ) {
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    final resolved = path.startsWith('/')
        ? base.replace(path: path)
        : base.resolve(path);
    final normalized = <String, String>{};
    for (final entry in queryParameters.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      normalized[entry.key] = value.toString();
    }
    final sortedEntries = normalized.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return resolved.replace(
      queryParameters: {
        for (final entry in sortedEntries) entry.key: entry.value,
      },
    );
  }
}
