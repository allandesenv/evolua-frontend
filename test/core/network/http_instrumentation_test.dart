import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/http_instrumentation.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HTTP metric route normalization', () {
    test('preserves v1 and masks numeric id without query values', () {
      expect(
        normalizeHttpMetricPath('/v1/check-ins/123?source=home&token=secret'),
        '/v1/check-ins/{id}',
      );
    });

    test('masks UUIDs and known opaque checkout identifiers', () {
      expect(
        normalizeHttpMetricPath(
          '/v1/items/550e8400-e29b-41d4-a716-446655440000',
        ),
        '/v1/items/{uuid}',
      );
      expect(
        normalizeHttpMetricPath('/v1/checkouts/abc123XYZ/status'),
        '/v1/checkouts/{checkoutId}/status',
      );
      expect(
        normalizeHttpMetricPath('/v1/ads/reward-session/sessionABC/test-grant'),
        '/v1/ads/reward-session/{rewardSessionId}/test-grant',
      );
    });

    test('does not mask ordinary alphanumeric slugs', () {
      expect(
        normalizeHttpMetricPath('/v1/communities/autoconhecimento'),
        '/v1/communities/autoconhecimento',
      );
    });

    test('uses sanitized route template when supplied', () {
      final request = RequestOptions(
        path: '/v1/checkouts/abc123XYZ/status?x=1',
        extra: const {
          httpInstrumentationRouteTemplateExtraKey:
              '/v1/checkouts/{checkoutId}/status',
        },
      );

      expect(
        normalizeHttpMetricRoute(request),
        '/v1/checkouts/{checkoutId}/status',
      );
    });
  });

  group('HTTP instrumentation interceptor', () {
    test(
      'does not record headers, authorization, body, or sensitive values',
      () async {
        final recorder = LimitedHttpInstrumentationRecorder(
          keepDetailedEvents: true,
        );
        final dio = _instrumentedDio(recorder);
        dio.httpClientAdapter = _QueuedAdapter([
          (_) => ResponseBody.fromString(
            '{"ok":true}',
            200,
            headers: {
              Headers.contentLengthHeader: ['11'],
            },
          ),
        ]);

        final response = await dio.post<dynamic>(
          '/v1/check-ins/123?reflection=segredo&token=secret-token',
          data: {
            'email': 'user@evolua.test',
            'reflection': 'texto emocional privado',
            'mood': 'ansioso',
          },
          options: Options(
            headers: {'Authorization': 'Bearer private-token'},
            extra: const {httpInstrumentationOriginExtraKey: 'unknown-user'},
          ),
        );

        expect(response.statusCode, 200);
        final snapshot = recorder.snapshot();
        expect(snapshot.logicalRequests, 1);
        expect(snapshot.httpAttempts, 1);
        final event = snapshot.recentEvents.single;
        expect(event.normalizedRoute, '/v1/check-ins/{id}');
        expect(event.origin, 'unspecified');
        final publicMetricText =
            '${event.method} ${event.normalizedRoute} ${event.statusCode}';
        expect(publicMetricText, isNot(contains('private-token')));
        expect(publicMetricText, isNot(contains('Authorization')));
        expect(publicMetricText, isNot(contains('texto emocional privado')));
        expect(publicMetricText, isNot(contains('ansioso')));
        expect(publicMetricText, isNot(contains('user@evolua.test')));
        expect(publicMetricText, isNot(contains('secret-token')));
      },
    );

    test('counts repeated calls and preserves the original response', () async {
      final recorder = LimitedHttpInstrumentationRecorder(
        keepDetailedEvents: true,
      );
      final dio = _instrumentedDio(recorder);
      dio.httpClientAdapter = _QueuedAdapter([
        (_) => _jsonBody('{"ok":1}'),
        (_) => _jsonBody('{"ok":2}'),
      ]);

      final first = await dio.get<dynamic>('/v1/profiles/me');
      final second = await dio.get<dynamic>('/v1/profiles/me');

      expect(first.data, {'ok': 1});
      expect(second.data, {'ok': 2});
      final snapshot = recorder.snapshot();
      expect(snapshot.logicalRequests, 2);
      expect(snapshot.httpAttempts, 2);
      expect(snapshot.routes['GET /v1/profiles/me']?.attempts, 2);
    });

    test(
      'marks retry attempts and keeps independent attempt durations',
      () async {
        final recorder = LimitedHttpInstrumentationRecorder(
          keepDetailedEvents: true,
        );
        final dio = _instrumentedDio(recorder);
        dio.httpClientAdapter = _QueuedAdapter([
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return ResponseBody.fromString('{"ok":true}', 200);
          },
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
            return ResponseBody.fromString('{"ok":true}', 200);
          },
        ]);

        await dio.get<dynamic>('/v1/profiles/me');
        await dio.get<dynamic>(
          '/v1/profiles/me',
          options: Options(
            extra: const {httpInstrumentationRetryExtraKey: true},
          ),
        );

        final snapshot = recorder.snapshot();
        expect(snapshot.logicalRequests, 1);
        expect(snapshot.httpAttempts, 2);
        expect(snapshot.retries, 1);
        expect(snapshot.recentEvents, hasLength(2));
        expect(
          snapshot.recentEvents[0].duration,
          greaterThanOrEqualTo(Duration.zero),
        );
        expect(
          snapshot.recentEvents[1].duration,
          greaterThanOrEqualTo(Duration.zero),
        );
      },
    );

    test('counts refresh requests separately from logical requests', () async {
      final recorder = LimitedHttpInstrumentationRecorder(
        keepDetailedEvents: true,
      );
      final dio = _instrumentedDio(recorder);
      dio.httpClientAdapter = _QueuedAdapter([
        (_) => ResponseBody.fromString('{"ok":true}', 200),
      ]);

      await dio.post<dynamic>('/v1/public/auth/refresh');

      final snapshot = recorder.snapshot();
      expect(snapshot.logicalRequests, 0);
      expect(snapshot.refreshRequests, 1);
      expect(snapshot.httpAttempts, 1);
    });

    test('records cancellation, timeout, and error without response', () async {
      final recorder = LimitedHttpInstrumentationRecorder(
        keepDetailedEvents: true,
      );
      final dio = _instrumentedDio(recorder);
      dio.httpClientAdapter = _QueuedAdapter([
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        ),
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('socket closed'),
        ),
      ]);

      await expectLater(
        dio.get<dynamic>('/v1/a'),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        dio.get<dynamic>('/v1/b'),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        dio.get<dynamic>('/v1/c'),
        throwsA(isA<DioException>()),
      );

      final snapshot = recorder.snapshot();
      expect(snapshot.httpAttempts, 3);
      expect(snapshot.cancellations, 1);
      expect(snapshot.timeouts, 1);
      expect(snapshot.errors, 1);
    });

    test('does not attach the interceptor twice', () {
      final recorder = LimitedHttpInstrumentationRecorder(
        keepDetailedEvents: true,
      );
      final dio = Dio();

      attachHttpInstrumentation(dio, recorder: recorder);
      attachHttpInstrumentation(dio, recorder: recorder);

      expect(
        dio.interceptors.whereType<HttpInstrumentationInterceptor>(),
        hasLength(1),
      );
    });

    test('attaches instrumentation when BaseOptions.extra is immutable', () {
      final recorder = LimitedHttpInstrumentationRecorder(
        keepDetailedEvents: true,
      );

      final dio = Dio(
        BaseOptions(extra: const {httpInstrumentationOriginExtraKey: 'auth'}),
      );

      expect(
        () => attachHttpInstrumentation(dio, recorder: recorder),
        returnsNormally,
      );
      expect(dio.options.extra[httpInstrumentationOriginExtraKey], 'auth');
      expect(
        dio.interceptors.whereType<HttpInstrumentationInterceptor>(),
        hasLength(1),
      );

      attachHttpInstrumentation(dio, recorder: recorder);

      expect(
        dio.interceptors.whereType<HttpInstrumentationInterceptor>(),
        hasLength(1),
      );
    });

    test('authRepositoryProvider builds without ProviderException', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(() => container.read(authRepositoryProvider), returnsNormally);
    });

    test('release default is noop and release flag keeps aggregate only', () {
      final noop = defaultHttpInstrumentationRecorder(releaseMode: true);
      final aggregate = defaultHttpInstrumentationRecorder(
        releaseMode: true,
        releaseEnabled: true,
      );

      expect(noop, isA<NoOpHttpInstrumentationRecorder>());
      expect(aggregate, isA<LimitedHttpInstrumentationRecorder>());
      aggregate.recordAttempt(
        const HttpInstrumentationEvent(
          method: 'GET',
          normalizedRoute: '/v1/test',
          statusCode: 200,
          duration: Duration.zero,
          responseBytes: null,
          isRetry: false,
          origin: 'unspecified',
        ),
      );
      expect(aggregate.snapshot().recentEvents, isEmpty);
    });

    test('propagates the original exception object', () async {
      final recorder = LimitedHttpInstrumentationRecorder(
        keepDetailedEvents: true,
      );
      final dio = _instrumentedDio(recorder);
      late final DioException original;
      dio.httpClientAdapter = _QueuedAdapter([
        (options) {
          original = DioException(
            requestOptions: options,
            type: DioExceptionType.unknown,
            error: StateError('boom'),
          );
          throw original;
        },
      ]);

      try {
        await dio.get<dynamic>('/v1/error');
        fail('Expected DioException');
      } on DioException catch (error) {
        expect(identical(error, original), isTrue);
      }
    });
  });
}

ResponseBody _jsonBody(String value, {int statusCode = 200}) {
  return ResponseBody.fromString(
    value,
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

Dio _instrumentedDio(LimitedHttpInstrumentationRecorder recorder) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.evolua.test',
      responseType: ResponseType.json,
    ),
  );
  attachHttpInstrumentation(dio, recorder: recorder);
  return dio;
}

class _QueuedAdapter implements HttpClientAdapter {
  _QueuedAdapter(this._responses);

  final List<FutureOr<ResponseBody> Function(RequestOptions options)>
  _responses;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_responses.isEmpty) {
      return ResponseBody.fromString('{"error":"unexpected"}', 500);
    }
    return _responses.removeAt(0)(options);
  }

  @override
  void close({bool force = false}) {}
}
