import 'dart:convert';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.roles,
    required this.accessToken,
    this.displayName,
    this.avatarUrl,
    this.refreshToken,
    this.expiresAt,
  });

  final String userId;
  final String email;
  final List<String> roles;
  final String accessToken;
  final String? displayName;
  final String? avatarUrl;
  final String? refreshToken;
  final DateTime? expiresAt;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isAdmin => roles.contains('ROLE_ADMIN');
  bool get isPremium => isAdmin || roles.contains('ROLE_PREMIUM');

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'roles': roles,
      'accessToken': accessToken,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken']?.toString() ?? '';
    final claims = _decodeJwtPayload(accessToken);
    final userId = (json['userId'] ?? claims['sub'])?.toString();
    final email = (json['email'] ?? claims['email'])?.toString();

    if (userId == null || userId.isEmpty || email == null || email.isEmpty) {
      throw const FormatException('Sessao invalida.');
    }

    final rawRoles = json['roles'] ?? claims['roles'];
    final roles = (rawRoles is List ? rawRoles : const <dynamic>[])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();

    DateTime? expiresAt;
    final rawExpiresAt = json['expiresAt']?.toString();
    if (rawExpiresAt != null && rawExpiresAt.isNotEmpty) {
      expiresAt = DateTime.tryParse(rawExpiresAt)?.toLocal();
    } else {
      final exp = claims['exp'];
      if (exp is num) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true).toLocal();
      }
    }

    return AuthSession(
      userId: userId,
      email: email,
      roles: roles,
      accessToken: accessToken,
      displayName: json['displayName']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      refreshToken: json['refreshToken']?.toString(),
      expiresAt: expiresAt,
    );
  }

  static Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      throw const FormatException('JWT invalido.');
    }

    final normalized = base64.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(decoded);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Payload JWT invalido.');
    }
    return payload;
  }
}
