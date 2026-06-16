import 'package:dio/dio.dart';
import 'package:evolua_frontend/features/auth/data/models/auth_session_dto.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _dio.post<void>(
      '/v1/public/auth/register',
      data: {'email': email, 'password': password, 'displayName': displayName},
    );
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/public/auth/login',
      data: {'email': email, 'password': password},
    );

    final payload = _normalizePayload(response.data);
    final dto = AuthSessionDto.fromJson(payload, fallbackEmail: email);
    return dto.toEntity();
  }

  @override
  Future<AuthSession> exchangeGoogleCode({required String code}) async {
    final response = await _dio.post<dynamic>(
      '/v1/public/auth/google/exchange',
      data: {'code': code},
    );

    final payload = _normalizePayload(response.data);
    final dto = AuthSessionDto.fromJson(payload, fallbackEmail: '');
    return dto.toEntity();
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    final response = await _dio.post<dynamic>(
      '/v1/public/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    final payload = _normalizePayload(response.data);
    final dto = AuthSessionDto.fromJson(payload, fallbackEmail: '');
    return dto.toEntity();
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    await _dio.post<void>(
      '/v1/public/auth/password/forgot',
      data: {'email': email},
      options: Options(
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _dio.post<void>(
      '/v1/public/auth/password/reset',
      data: {'token': token, 'newPassword': newPassword},
    );
  }

  @override
  Future<void> resendEmailVerification({required String accessToken}) async {
    await _dio.post<void>(
      '/v1/auth/email/verification/resend',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Map<String, dynamic> _normalizePayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data['data'] as Map<String, dynamic>);
      }

      return data;
    }

    throw const FormatException('Formato de resposta inesperado.');
  }
}
