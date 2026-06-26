import 'dart:convert';

import 'package:evolua_frontend/features/social/application/social_page_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SocialPageCache', () {
    test('builds isolated canonical keys without sensitive headers', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = SocialPageCache(preferences);

      final hml = cache.key(
        resource: SocialPageCacheResource.posts,
        socialBaseUrl: 'https://hml-api.evolua.test',
        endpoint: '/v1/social/posts',
        userId: 'user-a',
        locale: 'pt-BR',
        page: 0,
        size: 4,
        sortBy: 'createdAt',
        sortDir: 'desc',
        filters: const {'visibility': 'public', 'search': ' Respira '},
      );
      final production = cache.key(
        resource: SocialPageCacheResource.posts,
        socialBaseUrl: 'https://api.evolua.test',
        endpoint: '/v1/social/posts',
        userId: 'user-a',
        locale: 'pt-BR',
        page: 0,
        size: 4,
        sortBy: 'createdAt',
        sortDir: 'desc',
        filters: const {'search': 'respira', 'visibility': 'PUBLIC'},
      );
      final anotherUser = cache.key(
        resource: SocialPageCacheResource.posts,
        socialBaseUrl: 'https://hml-api.evolua.test',
        endpoint: '/v1/social/posts',
        userId: 'user-b',
        locale: 'pt-BR',
        page: 0,
        size: 4,
        sortBy: 'createdAt',
        sortDir: 'desc',
        filters: const {'search': 'respira', 'visibility': 'PUBLIC'},
      );

      expect(hml.requestKey, contains('hml-api.evolua.test'));
      expect(hml.requestKey, isNot(contains('api.evolua.test"')));
      expect(production.requestKey, contains('api.evolua.test'));
      expect(hml.storageKey, isNot(production.storageKey));
      expect(hml.storageKey, isNot(anotherUser.storageKey));
      expect(hml.requestKey, isNot(contains('Authorization')));
      expect(hml.requestKey, isNot(contains('Bearer')));
      expect(hml.filters, {'search': 'respira', 'visibility': 'PUBLIC'});
    });

    test('persists only allowed pages and payload sizes', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = SocialPageCache(preferences);
      final now = DateTime.utc(2026, 6, 26, 12);
      final key = _key(cache, page: 0);

      await cache.write(
        key: key,
        payload: const {'items': <Object>[]},
        nowUtc: now,
      );

      final entry = await cache.read(
        key: key,
        nowUtc: now.add(const Duration(minutes: 1)),
        maxAge: const Duration(minutes: 30),
      );
      expect(entry?.payload, {'items': <Object>[]});

      final unsupportedPage = _key(cache, page: 3);
      await cache.write(
        key: unsupportedPage,
        payload: const {'items': <Object>[]},
        nowUtc: now,
      );
      expect(preferences.containsKey(unsupportedPage.storageKey), isFalse);

      final hugeKey = _key(cache, page: 1);
      await cache.write(
        key: hugeKey,
        payload: {'items': 'x' * (SocialPageCache.maxPayloadBytes + 1)},
        nowUtc: now,
      );
      expect(preferences.containsKey(hugeKey.storageKey), isFalse);
    });

    test(
      'removes expired or invalid envelopes and legacy cache keys',
      () async {
        SharedPreferences.setMockInitialValues({
          'evolua.social_feed_cache.v1.old': 'legacy',
          'evolua.social_feed_cache.v2.user-a.old': 'legacy',
          'evolua.theme': 'keep',
        });
        final preferences = await SharedPreferences.getInstance();
        final cache = SocialPageCache(preferences);
        final expiredKey = _key(cache, page: 0);
        await preferences.setString(
          expiredKey.storageKey,
          jsonEncode({
            'schemaVersion': SocialPageCache.schemaVersion,
            'resource': SocialPageCacheResource.posts.storageName,
            'userId': 'user-a',
            'locale': 'pt-BR',
            'requestKey': expiredKey.requestKey,
            'cachedAtUtc': DateTime.utc(2026, 6, 26, 10).toIso8601String(),
            'lastAccessedAtUtc': DateTime.utc(
              2026,
              6,
              26,
              10,
            ).toIso8601String(),
            'payload': const {'items': <Object>[]},
          }),
        );

        final entry = await cache.read(
          key: expiredKey,
          nowUtc: DateTime.utc(2026, 6, 26, 12),
          maxAge: const Duration(minutes: 30),
        );
        expect(entry, isNull);
        expect(preferences.containsKey(expiredKey.storageKey), isFalse);

        await SocialPageCache.clearAllSocialCaches(preferences);

        expect(
          preferences.getString('evolua.social_feed_cache.v1.old'),
          isNull,
        );
        expect(
          preferences.getString('evolua.social_feed_cache.v2.user-a.old'),
          isNull,
        );
        expect(preferences.getString('evolua.theme'), 'keep');
      },
    );

    test('limits entries per resource, user and locale', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = SocialPageCache(preferences);
      final now = DateTime.utc(2026, 6, 26, 12);

      for (var page = 0; page < 3; page++) {
        for (var size = 1; size <= 5; size++) {
          await cache.write(
            key: _key(cache, page: page, size: size),
            payload: {
              'items': <Object>[size],
            },
            nowUtc: now.add(Duration(seconds: size + page * 10)),
          );
        }
      }

      final socialKeys = preferences.getKeys().where(
        (key) =>
            key.startsWith(
              '${SocialPageCache.prefix}.${SocialPageCacheResource.posts.storageName}.',
            ) &&
            !key.startsWith('${SocialPageCache.prefix}.index.'),
      );
      expect(socialKeys, hasLength(SocialPageCache.maxEntriesPerBucket));
    });
  });
}

SocialPageCacheKey _key(
  SocialPageCache cache, {
  required int page,
  int size = 4,
}) {
  return cache.key(
    resource: SocialPageCacheResource.posts,
    socialBaseUrl: 'https://hml-api.evolua.test',
    endpoint: '/v1/social/posts',
    userId: 'user-a',
    locale: 'pt-BR',
    page: page,
    size: size,
    sortBy: 'createdAt',
    sortDir: 'desc',
    filters: const {'search': null, 'visibility': null},
  );
}
