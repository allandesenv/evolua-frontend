import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';

abstract class AuthRepository {
  Future<void> register({
    required String email,
    required String password,
  });

  Future<AuthSession> login({
    required String email,
    required String password,
  });

  Future<AuthSession> exchangeGoogleCode({
    required String code,
  });
}
