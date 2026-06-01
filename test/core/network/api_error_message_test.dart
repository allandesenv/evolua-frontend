import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_error_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractApiErrorMessage', () {
    test('classifies no internet errors with friendly message', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/v1/check-ins'),
        type: DioExceptionType.connectionError,
        error: 'SocketException: failed host lookup',
      );

      expect(classifyApiError(error), FriendlyApiErrorType.noInternet);
      expect(
        extractApiErrorMessage(error),
        'Não conseguimos conectar agora. Verifique sua internet e tente novamente.',
      );
    });

    test('classifies timeout errors with friendly message', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/v1/check-ins'),
        type: DioExceptionType.receiveTimeout,
      );

      expect(classifyApiError(error), FriendlyApiErrorType.timeout);
      expect(
        extractApiErrorMessage(error),
        'A resposta demorou mais que o esperado. Tente novamente em instantes.',
      );
    });

    test('sanitizes forbidden and unauthorized responses', () {
      final forbidden = DioException(
        requestOptions: RequestOptions(path: '/v1/profiles/me'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/profiles/me'),
          statusCode: 403,
          data: const {'message': 'Forbidden'},
        ),
      );

      expect(
        extractApiErrorMessage(forbidden, fallback: 'Mensagem amigavel.'),
        'Sua sessão expirou. Entre novamente para continuar.',
      );
    });

    test('keeps safe quota message for payment required', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/v1/check-ins'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/check-ins'),
          statusCode: 402,
          data: const {
            'message':
                'Você já fez o check-in gratuito de hoje. Assista a um anúncio.',
          },
        ),
      );

      expect(classifyApiError(error), FriendlyApiErrorType.paymentRequired);
      expect(
        extractApiErrorMessage(error),
        'Você já fez o check-in gratuito de hoje. Assista a um anúncio.',
      );
    });

    test('classifies server errors without exposing backend details', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/v1/check-ins'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/check-ins'),
          statusCode: 503,
          data: const {'message': 'org.springframework stacktrace'},
        ),
      );

      expect(classifyApiError(error), FriendlyApiErrorType.serverUnavailable);
      expect(
        extractApiErrorMessage(error),
        'O Evolua está temporariamente indisponível. Tente novamente em alguns instantes.',
      );
    });

    test('does not expose technical exception messages', () {
      final error = StateError('DioException: 403 Forbidden stacktrace');

      expect(
        extractApiErrorMessage(error, fallback: 'Nao foi possivel continuar.'),
        'Nao foi possivel continuar.',
      );
    });

    test('keeps safe api messages', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/v1/public/auth/login'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/public/auth/login'),
          statusCode: 400,
          data: const {'message': 'Credenciais invalidas.'},
        ),
      );

      expect(
        extractApiErrorMessage(error, fallback: 'Falha.'),
        'Credenciais invalidas.',
      );
    });
  });
}
