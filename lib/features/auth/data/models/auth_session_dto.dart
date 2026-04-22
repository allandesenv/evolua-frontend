import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';

class AuthSessionDto {
  const AuthSessionDto({
    required this.email,
    required this.accessToken,
    this.displayName,
    this.avatarUrl,
    this.refreshToken,
  });

  final String email;
  final String accessToken;
  final String? displayName;
  final String? avatarUrl;
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
      email: ((json['email'] ?? json['username'])?.toString().isNotEmpty ?? false)
          ? (json['email'] ?? json['username']).toString()
          : fallbackEmail,
      accessToken: accessToken,
      displayName: json['displayName']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      refreshToken: (json['refreshToken'] ?? json['refresh_token'])?.toString(),
    );
  }

  AuthSession toEntity() {
    return AuthSession.fromJson(
      {
        'email': email.isEmpty ? null : email,
        'accessToken': accessToken,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'refreshToken': refreshToken,
      },
    );
  }
}
