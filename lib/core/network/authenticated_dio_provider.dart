import 'package:dio/dio.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _authRetryExtraKey = 'evolua.auth.retry';

final authenticatedDioProvider = Provider.family<Dio, String>((ref, baseUrl) {
  final session = ref.watch(authControllerProvider).asData?.value;

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final currentSession =
            ref.read(authControllerProvider).asData?.value ?? session;
        final token = currentSession?.accessToken;

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        if (!_shouldRefresh(error)) {
          handler.next(error);
          return;
        }

        final refreshed = await ref
            .read(authControllerProvider.notifier)
            .refreshSession();
        if (refreshed == null) {
          await ref.read(authControllerProvider.notifier).logout();
          handler.next(error);
          return;
        }

        final original = error.requestOptions;
        final retryOptions = original.copyWith(
          headers: {
            ...original.headers,
            'Authorization': 'Bearer ${refreshed.accessToken}',
          },
          extra: {...original.extra, _authRetryExtraKey: true},
        );

        try {
          final response = await dio.fetch<dynamic>(retryOptions);
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    ),
  );

  return dio;
});

bool _shouldRefresh(DioException error) {
  final response = error.response;
  if (response?.statusCode != 401) {
    return false;
  }

  final request = error.requestOptions;
  if (request.extra[_authRetryExtraKey] == true) {
    return false;
  }

  return !_isPublicAuthPath(request.path);
}

bool _isPublicAuthPath(String path) {
  return path.contains('/v1/public/auth/') ||
      path.endsWith('/auth/google/callback');
}
