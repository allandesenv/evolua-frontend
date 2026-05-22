import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_error_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractApiErrorMessage', () {
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
        'Mensagem amigavel.',
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
