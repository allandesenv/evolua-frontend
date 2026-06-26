import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/l10n/locale_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SocialPageCacheResource {
  posts('posts'),
  communities('communities');

  const SocialPageCacheResource(this.storageName);

  final String storageName;
}

final socialPageCacheProvider = FutureProvider<SocialPageCache>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return SocialPageCache(preferences);
});

final socialMutationRevalidateDelayProvider = Provider<Duration>((ref) {
  return const Duration(milliseconds: 500);
});

Future<String> effectiveSocialLocale(Ref ref) async {
  final preference = await ref.read(localeControllerProvider.future);
  final locale = preference.locale ?? PlatformDispatcher.instance.locale;
  return locale.toLanguageTag();
}

class SocialPageCache {
  SocialPageCache(this._preferences);

  static const schemaVersion = 3;
  static const prefix = 'evolua.social_page_cache.v3';
  static const legacyV1Prefix = 'evolua.social_feed_cache.v1';
  static const legacyV2Prefix = 'evolua.social_feed_cache.v2';
  static const maxPayloadBytes = 256 * 1024;
  static const maxEntriesPerBucket = 12;
  static const maxPersistedPage = 2;

  static final _inFlight = <String, Future<Object?>>{};

  final SharedPreferences _preferences;

  SocialPageCacheKey key({
    required SocialPageCacheResource resource,
    required String socialBaseUrl,
    required String endpoint,
    required String userId,
    required String locale,
    required int page,
    required int size,
    required String sortBy,
    required String sortDir,
    required Map<String, Object?> filters,
  }) {
    return SocialPageCacheKey(
      resource: resource,
      socialBaseUrl: socialBaseUrl,
      endpoint: endpoint,
      userId: userId,
      locale: locale,
      page: page,
      size: size,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: filters,
    );
  }

  Future<SocialPageCacheEntry?> read({
    required SocialPageCacheKey key,
    required DateTime nowUtc,
    required Duration maxAge,
  }) async {
    if (!key.isPersistable) {
      return null;
    }
    final raw = _preferences.getString(key.storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Envelope invalido.');
      }
      if (decoded['schemaVersion'] != schemaVersion ||
          decoded['resource'] != key.resource.storageName ||
          decoded['userId'] != key.userId ||
          decoded['locale'] != key.locale ||
          decoded['requestKey'] != key.requestKey) {
        throw const FormatException('Envelope incompativel.');
      }
      final cachedAt = DateTime.tryParse(
        decoded['cachedAtUtc']?.toString() ?? '',
      )?.toUtc();
      if (cachedAt == null || cachedAt.isAfter(nowUtc)) {
        throw const FormatException('Timestamp invalido.');
      }
      if (nowUtc.difference(cachedAt) > maxAge) {
        await remove(key);
        return null;
      }
      final payload = decoded['payload'];
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Payload invalido.');
      }
      await _touch(key, decoded, nowUtc);
      return SocialPageCacheEntry(
        key: key,
        cachedAtUtc: cachedAt,
        payload: payload,
      );
    } catch (_) {
      await remove(key);
      return null;
    }
  }

  Future<void> write({
    required SocialPageCacheKey key,
    required Map<String, dynamic> payload,
    required DateTime nowUtc,
  }) async {
    if (!key.isPersistable) {
      return;
    }
    final envelope = <String, Object?>{
      'schemaVersion': schemaVersion,
      'resource': key.resource.storageName,
      'userId': key.userId,
      'locale': key.locale,
      'requestKey': key.requestKey,
      'cachedAtUtc': nowUtc.toIso8601String(),
      'lastAccessedAtUtc': nowUtc.toIso8601String(),
      'payload': payload,
    };
    final encoded = jsonEncode(envelope);
    if (utf8.encode(encoded).length > maxPayloadBytes) {
      await remove(key);
      return;
    }
    await _preferences.setString(key.storageKey, encoded);
    await _remember(key);
    await _prune(key.resource, key.userId, key.locale);
  }

  Future<void> remove(SocialPageCacheKey key) async {
    await _preferences.remove(key.storageKey);
    final indexKey = _indexKey(key.resource, key.userId, key.locale);
    final keys = _preferences.getStringList(indexKey) ?? const [];
    if (keys.contains(key.storageKey)) {
      await _preferences.setStringList(
        indexKey,
        keys.where((item) => item != key.storageKey).toList(),
      );
    }
  }

  Future<void> invalidate({
    required SocialPageCacheResource resource,
    required String userId,
  }) async {
    final allKeys = _preferences.getKeys().toList();
    for (final key in allKeys) {
      if (!key.startsWith('$prefix.${resource.storageName}.')) {
        continue;
      }
      final raw = _preferences.getString(key);
      if (raw == null) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded['userId'] == userId) {
          await _preferences.remove(key);
        }
      } catch (_) {
        await _preferences.remove(key);
      }
    }
    await _cleanupIndexes();
  }

  static Future<void> clearAllSocialCaches(
    SharedPreferences preferences,
  ) async {
    final keys = preferences.getKeys().where((key) {
      return key.startsWith(legacyV1Prefix) ||
          key.startsWith(legacyV2Prefix) ||
          key.startsWith(prefix);
    }).toList();
    for (final key in keys) {
      await preferences.remove(key);
    }
  }

  Future<T> runDeduplicated<T>(
    String requestKey,
    Future<T> Function() fetcher,
  ) async {
    final current = _inFlight[requestKey];
    if (current != null) {
      return await current as T;
    }
    final future = fetcher();
    _inFlight[requestKey] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[requestKey], future)) {
        _inFlight.remove(requestKey);
      }
    }
  }

  Future<void> _touch(
    SocialPageCacheKey key,
    Map<String, dynamic> envelope,
    DateTime nowUtc,
  ) async {
    envelope['lastAccessedAtUtc'] = nowUtc.toIso8601String();
    await _preferences.setString(key.storageKey, jsonEncode(envelope));
    await _remember(key);
  }

  Future<void> _remember(SocialPageCacheKey key) async {
    final indexKey = _indexKey(key.resource, key.userId, key.locale);
    final keys = _preferences.getStringList(indexKey) ?? const [];
    await _preferences.setStringList(indexKey, [
      key.storageKey,
      ...keys.where((item) => item != key.storageKey),
    ]);
  }

  Future<void> _prune(
    SocialPageCacheResource resource,
    String userId,
    String locale,
  ) async {
    final indexKey = _indexKey(resource, userId, locale);
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
            decoded['resource'] == resource.storageName &&
            decoded['userId'] == userId &&
            decoded['locale'] == locale) {
          valid.add(key);
          continue;
        }
      } catch (_) {
        // Remove below.
      }
      await _preferences.remove(key);
    }
    for (final key in valid.skip(maxEntriesPerBucket)) {
      await _preferences.remove(key);
    }
    await _preferences.setStringList(
      indexKey,
      valid.take(maxEntriesPerBucket).toList(),
    );
  }

  Future<void> _cleanupIndexes() async {
    final keys = _preferences
        .getKeys()
        .where((key) => key.startsWith('$prefix.index.'))
        .toList();
    for (final key in keys) {
      final values = _preferences.getStringList(key) ?? const [];
      await _preferences.setStringList(
        key,
        values.where((item) => _preferences.containsKey(item)).toList(),
      );
    }
  }

  String _indexKey(
    SocialPageCacheResource resource,
    String userId,
    String locale,
  ) {
    return '$prefix.index.${resource.storageName}.${Uri.encodeComponent(userId)}.${Uri.encodeComponent(locale)}';
  }
}

class SocialPageCacheEntry {
  const SocialPageCacheEntry({
    required this.key,
    required this.cachedAtUtc,
    required this.payload,
  });

  final SocialPageCacheKey key;
  final DateTime cachedAtUtc;
  final Map<String, dynamic> payload;

  bool isStale(DateTime nowUtc, Duration freshTtl) {
    return nowUtc.difference(cachedAtUtc) > freshTtl;
  }
}

class SocialPageCacheKey {
  SocialPageCacheKey({
    required this.resource,
    required String socialBaseUrl,
    required String endpoint,
    required this.userId,
    required this.locale,
    required this.page,
    required this.size,
    required this.sortBy,
    required this.sortDir,
    required Map<String, Object?> filters,
  }) : uri = _canonicalUri(socialBaseUrl, endpoint),
       filters = _canonicalFilters(filters);

  final SocialPageCacheResource resource;
  final Uri uri;
  final String userId;
  final String locale;
  final int page;
  final int size;
  final String sortBy;
  final String sortDir;
  final Map<String, Object?> filters;

  bool get isPersistable =>
      page >= 0 && page <= SocialPageCache.maxPersistedPage;

  String get requestKey {
    return jsonEncode({
      'resource': resource.storageName,
      'uri': uri.toString(),
      'userId': userId,
      'locale': locale,
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'sortDir': sortDir,
      'filters': filters,
    });
  }

  String get storageKey {
    return '${SocialPageCache.prefix}.${resource.storageName}.${base64Url.encode(utf8.encode(requestKey))}';
  }

  static Uri _canonicalUri(String baseUrl, String endpoint) {
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    return endpoint.startsWith('/')
        ? base.replace(path: endpoint)
        : base.resolve(endpoint);
  }

  static Map<String, Object?> _canonicalFilters(Map<String, Object?> filters) {
    final normalized = <String, Object?>{};
    for (final entry in filters.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) {
        normalized[key] = null;
      } else if (value is String) {
        final trimmed = value.trim();
        if (key == 'search' || key == 'community' || key == 'category') {
          normalized[key] = trimmed.toLowerCase();
        } else if (key == 'visibility') {
          normalized[key] = trimmed.toUpperCase();
        } else {
          normalized[key] = trimmed;
        }
      } else {
        normalized[key] = value;
      }
    }
    final sorted = normalized.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return {for (final entry in sorted) entry.key: entry.value};
  }
}
