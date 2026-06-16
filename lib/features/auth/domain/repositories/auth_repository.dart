import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';

abstract class AuthRepository {
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> exchangeGoogleCode({required String code});

  Future<AuthSession> refresh({required String refreshToken});

  Future<void> forgotPassword({required String email});

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<void> resendEmailVerification({required String accessToken});
}
