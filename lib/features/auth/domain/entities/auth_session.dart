class AuthSession {
  const AuthSession({
    required this.email,
    required this.accessToken,
    this.refreshToken,
  });

  final String email;
  final String accessToken;
  final String? refreshToken;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }
}
