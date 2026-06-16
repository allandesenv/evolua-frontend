import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessionStorageKey = 'evolua.auth.session';
const _localePreferenceStorageKey = 'evolua.locale_preference.v1';

void main() {
  group('AuthController refresh', () {
    test(
      'renews expired session during boot when refresh token is valid',
      () async {
        final expired = _testSession(
          accessToken: _buildJwt(
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
          refreshToken: 'old-refresh-token',
        );
        final refreshed = _testSession(
          accessToken: _buildJwt(
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
          refreshToken: 'new-refresh-token',
        );
        SharedPreferences.setMockInitialValues({
          _sessionStorageKey: jsonEncode(expired.toJson()),
        });
        final repository = _FakeAuthRepository(refreshSession: refreshed);
        final container = _container(repository);
        addTearDown(container.dispose);

        final session = await container.read(authControllerProvider.future);

        expect(session?.refreshToken, 'old-refresh-token');
        await Future<void>.delayed(Duration.zero);
        final refreshedSession = container
            .read(authControllerProvider)
            .asData
            ?.value;
        expect(refreshedSession?.refreshToken, 'new-refresh-token');
        expect(repository.refreshCalls, 1);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString(_sessionStorageKey), isNotNull);
      },
    );

    test('clears expired session when refresh token is missing', () async {
      final expired = _testSession(
        accessToken: _buildJwt(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        refreshToken: null,
      );
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(expired.toJson()),
      });
      final repository = _FakeAuthRepository(refreshSession: _testSession());
      final container = _container(repository);
      addTearDown(container.dispose);

      final session = await container.read(authControllerProvider.future);

      expect(session, isNull);
      expect(repository.refreshCalls, 0);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(_sessionStorageKey), isNull);
    });

    test('clears session when refresh token is rejected', () async {
      final expired = _testSession(
        accessToken: _buildJwt(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        refreshToken: 'old-refresh-token',
      );
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(expired.toJson()),
      });
      final repository = _FakeAuthRepository(
        refreshError: DioException(
          requestOptions: RequestOptions(path: '/v1/public/auth/refresh'),
          response: Response<void>(
            requestOptions: RequestOptions(path: '/v1/public/auth/refresh'),
            statusCode: 401,
          ),
        ),
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      final session = await container.read(authControllerProvider.future);

      expect(session?.refreshToken, 'old-refresh-token');
      await Future<void>.delayed(Duration.zero);
      final rejectedSession = container
          .read(authControllerProvider)
          .asData
          ?.value;
      expect(rejectedSession, isNull);
      expect(repository.refreshCalls, 1);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(_sessionStorageKey), isNull);
    });

    test('keeps session when refresh fails transiently', () async {
      final expired = _testSession(
        accessToken: _buildJwt(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        refreshToken: 'old-refresh-token',
      );
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(expired.toJson()),
      });
      final repository = _FakeAuthRepository(
        refreshError: DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: '/v1/public/auth/refresh'),
        ),
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      final session = await container.read(authControllerProvider.future);

      expect(session?.refreshToken, 'old-refresh-token');
      expect(repository.refreshCalls, 1);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(_sessionStorageKey), isNotNull);
    });

    test('deduplicates concurrent refresh requests', () async {
      final current = _testSession(
        accessToken: _buildJwt(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        refreshToken: 'old-refresh-token',
      );
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(current.toJson()),
      });
      final completer = Completer<AuthSession>();
      final repository = _FakeAuthRepository(refreshCompleter: completer);
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final first = container
          .read(authControllerProvider.notifier)
          .refreshSession();
      final second = container
          .read(authControllerProvider.notifier)
          .refreshSession();
      completer.complete(
        _testSession(
          accessToken: _buildJwt(
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
          refreshToken: 'new-refresh-token',
        ),
      );

      final results = await Future.wait([first, second]);
      expect(
        results.map((session) => session?.refreshToken),
        everyElement('new-refresh-token'),
      );
      expect(repository.refreshCalls, 1);
    });
  });

  group('authenticatedDioProvider', () {
    test('adds bearer token, refreshes on 401 and retries once', () async {
      final oldAccessToken = _buildJwt(
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final newAccessToken = _buildJwt(
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );
      final current = _testSession(
        accessToken: oldAccessToken,
        refreshToken: 'old-refresh-token',
      );
      final refreshed = _testSession(
        accessToken: newAccessToken,
        refreshToken: 'new-refresh-token',
      );
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(current.toJson()),
      });
      final repository = _FakeAuthRepository(refreshSession: refreshed);
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final dio = container.read(
        authenticatedDioProvider('https://api.evolua.test'),
      );
      final adapter = _QueuedAdapter([
        (_) => ResponseBody.fromString('{"message":"expired"}', 401),
        (_) => ResponseBody.fromString('{"ok":true}', 200),
      ]);
      dio.httpClientAdapter = adapter;

      final response = await dio.get<dynamic>('/v1/profiles/me');

      expect(response.statusCode, 200);
      expect(repository.refreshCalls, 1);
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests[0].headers['Authorization'],
        'Bearer $oldAccessToken',
      );
      expect(
        adapter.requests[1].headers['Authorization'],
        'Bearer $newAccessToken',
      );
    });

    test('does not refresh public auth endpoints', () async {
      final current = _testSession(
        accessToken: _buildJwt(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        refreshToken: 'old-refresh-token',
      );
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(current.toJson()),
      });
      final repository = _FakeAuthRepository(refreshSession: _testSession());
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final dio = container.read(
        authenticatedDioProvider('https://api.evolua.test'),
      );
      dio.httpClientAdapter = _QueuedAdapter([
        (_) => ResponseBody.fromString('{"message":"invalid"}', 401),
      ]);

      await expectLater(
        dio.get<dynamic>('/v1/public/auth/login'),
        throwsA(isA<DioException>()),
      );
      expect(repository.refreshCalls, 0);
    });

    test('refreshes on 403 with bearer and retries with new token', () async {
      final oldAccessToken = _buildJwt(
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final newAccessToken = _buildJwt(
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );
      final current = _testSession(
        accessToken: oldAccessToken,
        refreshToken: 'old-refresh-token',
      );
      final refreshed = _testSession(
        accessToken: newAccessToken,
        refreshToken: 'new-refresh-token',
      );
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(current.toJson()),
      });
      final repository = _FakeAuthRepository(refreshSession: refreshed);
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final dio = container.read(
        authenticatedDioProvider('https://api.evolua.test'),
      );
      final adapter = _QueuedAdapter([
        (_) => ResponseBody.fromString('{"message":"forbidden"}', 403),
        (_) => ResponseBody.fromString('{"ok":true}', 200),
      ]);
      dio.httpClientAdapter = adapter;

      final response = await dio.get<dynamic>('/v1/profiles/me');

      expect(response.statusCode, 200);
      expect(repository.refreshCalls, 1);
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests[1].headers['Authorization'],
        'Bearer $newAccessToken',
      );
    });

    test('does not retry when refresh failure is transient', () async {
      final oldAccessToken = _buildJwt(
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final current = _testSession(
        accessToken: oldAccessToken,
        refreshToken: 'old-refresh-token',
      );
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(current.toJson()),
      });
      final repository = _FakeAuthRepository(
        refreshError: DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: '/v1/public/auth/refresh'),
        ),
      );
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final dio = container.read(
        authenticatedDioProvider('https://api.evolua.test'),
      );
      final adapter = _QueuedAdapter([
        (_) => ResponseBody.fromString('{"message":"expired"}', 401),
      ]);
      dio.httpClientAdapter = adapter;

      await expectLater(
        dio.get<dynamic>('/v1/profiles/me'),
        throwsA(isA<DioException>()),
      );

      expect(repository.refreshCalls, 1);
      expect(adapter.requests, hasLength(1));
      expect(
        container.read(authControllerProvider).asData?.value?.refreshToken,
        'old-refresh-token',
      );
    });

    test(
      'sends locale and utf8 headers and preserves accented response',
      () async {
        final current = _testSession(
          accessToken: _buildJwt(
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
          refreshToken: 'refresh-token',
        );
        SharedPreferences.setMockInitialValues({
          _sessionStorageKey: jsonEncode(current.toJson()),
          _localePreferenceStorageKey: 'en-US',
        });
        final repository = _FakeAuthRepository();
        final container = _container(repository);
        addTearDown(container.dispose);
        await container.read(authControllerProvider.future);
        await container.read(sharedPreferencesProvider.future);

        final dio = container.read(
          authenticatedDioProvider('https://api.evolua.test'),
        );
        final adapter = _QueuedAdapter([
          (_) => ResponseBody.fromBytes(
            utf8.encode('{"text":"estável versão ação"}'),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json; charset=utf-8'],
            },
          ),
        ]);
        dio.httpClientAdapter = adapter;

        final response = await dio.get<dynamic>('/v1/check-ins');

        expect(adapter.requests.single.headers['Accept-Charset'], 'utf-8');
        expect(adapter.requests.single.headers['Accept-Language'], 'en-US');
        expect(response.data, {'text': 'estável versão ação'});
      },
    );
    test('keeps old stored sessions verified by default', () {
      final session = AuthSession.fromJson({
        'userId': 'user-123',
        'email': 'user@evolua.app',
        'roles': const ['ROLE_USER'],
        'accessToken': _buildJwt(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      });

      expect(session.emailVerified, isTrue);
    });

    test('parses and persists email verification status', () {
      final session = AuthSession.fromJson({
        'userId': 'user-123',
        'email': 'user@evolua.app',
        'roles': const ['ROLE_USER'],
        'accessToken': _buildJwt(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          emailVerified: false,
        ),
        'emailVerified': false,
      });

      expect(session.emailVerified, isFalse);
      expect(AuthSession.fromJson(session.toJson()).emailVerified, isFalse);
    });

    test('resend email verification uses current access token', () async {
      final current = _testSession(
        accessToken: _buildJwt(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(current.toJson()),
      });
      final repository = _FakeAuthRepository(refreshSession: current);
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .resendEmailVerification();

      expect(repository.resendEmailVerificationCalls, 1);
      expect(
        repository.lastResendEmailVerificationAccessToken,
        current.accessToken,
      );
    });
  });
}

ProviderContainer _container(_FakeAuthRepository repository) {
  return ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.refreshSession,
    this.refreshCompleter,
    this.refreshError,
  });

  final AuthSession? refreshSession;
  final Completer<AuthSession>? refreshCompleter;
  final Object? refreshError;
  int refreshCalls = 0;
  int resendEmailVerificationCalls = 0;
  String? lastResendEmailVerificationAccessToken;

  @override
  Future<AuthSession> exchangeGoogleCode({required String code}) async {
    return _testSession();
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _testSession();
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {}

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    refreshCalls += 1;
    final error = refreshError;
    if (error != null) {
      throw error;
    }
    final completer = refreshCompleter;
    if (completer != null) {
      return completer.future;
    }
    return refreshSession ?? _testSession();
  }

  @override
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {}

  @override
  Future<void> resendEmailVerification({required String accessToken}) async {
    resendEmailVerificationCalls += 1;
    lastResendEmailVerificationAccessToken = accessToken;
  }
}

class _QueuedAdapter implements HttpClientAdapter {
  _QueuedAdapter(this._responses);

  final List<ResponseBody Function(RequestOptions options)> _responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_responses.isEmpty) {
      return ResponseBody.fromString('{"message":"unexpected"}', 500);
    }
    return _responses.removeAt(0)(options);
  }

  @override
  void close({bool force = false}) {}
}

AuthSession _testSession({
  String? accessToken,
  String? refreshToken = 'refresh-token',
}) {
  return AuthSession(
    userId: 'user-123',
    email: 'user@evolua.app',
    roles: const ['ROLE_USER'],
    accessToken:
        accessToken ??
        _buildJwt(expiresAt: DateTime.now().add(const Duration(hours: 1))),
    refreshToken: refreshToken,
  );
}

String _buildJwt({required DateTime expiresAt, bool emailVerified = true}) {
  String encode(Map<String, Object> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  final header = encode({'alg': 'none', 'typ': 'JWT'});
  final payload = encode({
    'sub': 'user-123',
    'email': 'user@evolua.app',
    'roles': const ['ROLE_USER'],
    'emailVerified': emailVerified,
    'exp': expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000,
  });

  return '$header.$payload.signature';
}
