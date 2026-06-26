import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/cache/stable_resource_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('canonical key separates hosts and sorted queries', () {
    final hml = StableCacheKey(
      resource: StableResource.planCatalog,
      baseUrl: 'https://hml.evolua.test',
      path: '/v1/plans',
      queryParameters: const {'b': 2, 'a': 1},
      appVersion: '1.0.0+1',
      locale: 'pt-BR',
    );
    final prod = StableCacheKey(
      resource: StableResource.planCatalog,
      baseUrl: 'https://prod.evolua.test',
      path: '/v1/plans',
      queryParameters: const {'a': 1, 'b': 2},
      appVersion: '1.0.0+1',
      locale: 'pt-BR',
    );

    expect(hml.storageKey, isNot(prod.storageKey));
    expect(hml.canonical, contains('https://hml.evolua.test/v1/plans?a=1&b=2'));
    expect(
      prod.canonical,
      contains('https://prod.evolua.test/v1/plans?a=1&b=2'),
    );
    expect(hml.canonical, isNot(contains('Authorization')));
  });

  test('304 reuses payload, preserves etag and renews ttl', () async {
    var now = DateTime.utc(2026, 6, 26, 10);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final adapter = _QueuedAdapter([
      (options) => _jsonResponse(
        {'value': 'cached'},
        headers: {
          'etag': ['"plans-v1"'],
        },
      ),
      (options) {
        expect(options.headers['If-None-Match'], '"plans-v1"');
        return ResponseBody.fromString('', 304);
      },
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.evolua.test'))
      ..httpClientAdapter = adapter;
    final cache = StableResourceCache(preferences, now: () => now);

    final first = await _load(cache, dio);
    expect(first, 'cached');

    now = now.add(const Duration(minutes: 6));
    final second = await _load(cache, dio);
    expect(second, 'cached');
    expect(adapter.calls, 2);

    final third = await _load(cache, dio);
    expect(third, 'cached');
    expect(adapter.calls, 2);
  });

  test('200 without etag replaces payload and clears previous etag', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final seenIfNoneMatch = <Object?>[];
    final adapter = _QueuedAdapter([
      (options) => _jsonResponse(
        {'value': 'old'},
        headers: {
          'etag': ['"old-etag"'],
        },
      ),
      (options) {
        seenIfNoneMatch.add(options.headers['If-None-Match']);
        return _jsonResponse({'value': 'new'});
      },
      (options) {
        seenIfNoneMatch.add(options.headers['If-None-Match']);
        return _jsonResponse({'value': 'newer'});
      },
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.evolua.test'))
      ..httpClientAdapter = adapter;
    final cache = StableResourceCache(preferences, now: DateTime.now);

    expect(await _load(cache, dio), 'old');
    expect(await _load(cache, dio, force: true), 'new');
    expect(await _load(cache, dio, force: true), 'newer');

    expect(seenIfNoneMatch, ['"old-etag"', isNull]);
  });

  test('401 does not use stale cache', () async {
    var now = DateTime.utc(2026, 6, 26, 10);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final adapter = _QueuedAdapter([
      (options) => _jsonResponse({'value': 'cached'}),
      (options) => ResponseBody.fromString('unauthorized', 401),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.evolua.test'))
      ..httpClientAdapter = adapter;
    final cache = StableResourceCache(preferences, now: () => now);

    expect(await _load(cache, dio), 'cached');
    now = now.add(const Duration(minutes: 6));

    await expectLater(_load(cache, dio), throwsA(isA<DioException>()));
    expect(adapter.calls, 2);
  });

  test('payload above 256 KB is not persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final adapter = _QueuedAdapter([
      (options) => _jsonResponse({'value': 'x' * (260 * 1024)}),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.evolua.test'))
      ..httpClientAdapter = adapter;
    final cache = StableResourceCache(preferences, now: DateTime.now);

    await _load(cache, dio);

    final cacheKeys = preferences
        .getKeys()
        .where((key) => key.startsWith('evolua.stable-resource-cache.v1.'))
        .toList();
    expect(cacheKeys, isEmpty);
  });
}

Future<String> _load(StableResourceCache cache, Dio dio, {bool force = false}) {
  return cache.getOrFetch<String>(
    resource: StableResource.planCatalog,
    dio: dio,
    path: '/v1/plans',
    appVersion: '1.0.0+1',
    locale: 'pt-BR',
    ttl: const Duration(minutes: 5),
    maxStale: const Duration(hours: 24),
    force: force,
    extractPayload: (data) => (data as Map<String, dynamic>)['data'],
    decodePayload: (payload) =>
        (payload as Map<String, dynamic>)['value'].toString(),
  );
}

ResponseBody _jsonResponse(
  Map<String, dynamic> data, {
  Map<String, List<String>> headers = const {},
}) {
  return ResponseBody.fromString(
    jsonEncode({'data': data}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...headers,
    },
  );
}

class _QueuedAdapter implements HttpClientAdapter {
  _QueuedAdapter(this._responses);

  final List<FutureOr<ResponseBody> Function(RequestOptions options)>
  _responses;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (_responses.isEmpty) {
      return ResponseBody.fromString('unexpected', 500);
    }
    return _responses.removeAt(0)(options);
  }

  @override
  void close({bool force = false}) {}
}
