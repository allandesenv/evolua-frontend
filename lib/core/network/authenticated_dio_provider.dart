import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/http_instrumentation.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _localePreferenceStorageKey = 'evolua.locale_preference.v1';

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
        'Accept-Charset': 'utf-8',
        'Accept-Language': 'pt-BR',
      },
      responseDecoder: _utf8ResponseDecoder,
    ),
  );

  attachHttpInstrumentation(
    dio,
    recorder: ref.read(httpInstrumentationRecorderProvider),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!ref.mounted) {
          handler.next(options);
          return;
        }
        final preferences = await ref.read(sharedPreferencesProvider.future);
        if (!ref.mounted) {
          handler.next(options);
          return;
        }
        options.headers['Accept-Language'] = _aiLanguageTag(
          preferences.getString(_localePreferenceStorageKey),
        );
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

        final original = error.requestOptions;
        final originalAuthorization = _authorizationHeader(original);
        if (!ref.mounted) {
          handler.next(error);
          return;
        }
        final refreshed = await ref
            .read(authControllerProvider.notifier)
            .refreshSession();
        if (!ref.mounted) {
          handler.next(error);
          return;
        }
        final refreshedAuthorization = refreshed?.accessToken == null
            ? null
            : 'Bearer ${refreshed!.accessToken}';
        if (refreshedAuthorization == null ||
            refreshedAuthorization == originalAuthorization) {
          handler.next(error);
          return;
        }

        final retryOptions = original.copyWith(
          headers: {
            ...original.headers,
            'Authorization': refreshedAuthorization,
          },
          extra: {...original.extra, httpInstrumentationRetryExtraKey: true},
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

String _aiLanguageTag(String? preference) {
  return switch (preference) {
    'en-US' => 'en-US',
    'pt-BR' => 'pt-BR',
    _ => 'pt-BR',
  };
}

String _utf8ResponseDecoder(
  List<int> responseBytes,
  RequestOptions options,
  ResponseBody responseBody,
) {
  return utf8.decode(responseBytes, allowMalformed: false);
}

bool _shouldRefresh(DioException error) {
  final response = error.response;
  if (response?.statusCode != 401 && response?.statusCode != 403) {
    return false;
  }

  final request = error.requestOptions;
  if (request.extra[httpInstrumentationRetryExtraKey] == true) {
    return false;
  }

  return !_isPublicAuthPath(request.path) &&
      _authorizationHeader(request) != null;
}

bool _isPublicAuthPath(String path) {
  return path.contains('/v1/public/auth/') ||
      path.endsWith('/auth/google/callback');
}

String? _authorizationHeader(RequestOptions request) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == 'authorization') {
      final value = entry.value?.toString();
      if (value != null && value.trim().isNotEmpty) {
        return value;
      }
    }
  }
  return null;
}
