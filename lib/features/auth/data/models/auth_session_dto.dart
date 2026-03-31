import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';

class AuthSessionDto {
  const AuthSessionDto({
    required this.email,
    required this.accessToken,
    this.refreshToken,
  });

  final String email;
  final String accessToken;
  final String? refreshToken;

  factory AuthSessionDto.fromJson(
    Map<String, dynamic> json, {
    required String fallbackEmail,
  }) {
    final accessToken =
        (json['accessToken'] ?? json['token'] ?? json['jwt'] ?? json['access_token'])?.toString();

    if (accessToken == null || accessToken.isEmpty) {
      throw const FormatException('Resposta de autenticacao sem access token.');
    }

    return AuthSessionDto(
      email: (json['email'] ?? json['username'] ?? fallbackEmail).toString(),
      accessToken: accessToken,
      refreshToken: (json['refreshToken'] ?? json['refresh_token'])?.toString(),
    );
  }

  AuthSession toEntity() {
    return AuthSession.fromJson(
      {
        'email': email,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      },
    );
  }
}
