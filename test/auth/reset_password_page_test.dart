import 'dart:convert';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/auth/presentation/pages/reset_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders reset password route and validates matching passwords', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(_FakeAuthRepository()));

    expect(find.text('Criar nova senha'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nova senha'),
      '123456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar nova senha'),
      '654321',
    );
    await tester.tap(find.text('Redefinir senha'));
    await tester.pump();

    expect(find.text('As senhas não conferem.'), findsOneWidget);
  });

  testWidgets('submits reset password token and shows success state', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_testApp(repository));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nova senha'),
      '123456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar nova senha'),
      '123456',
    );
    await tester.tap(find.text('Redefinir senha'));
    await tester.pumpAndSettle();

    expect(repository.lastResetToken, 'token-123');
    expect(repository.lastResetPassword, '123456');
    expect(find.text('Senha redefinida'), findsOneWidget);
  });
}

Widget _testApp(_FakeAuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: ResetPasswordPage(token: 'token-123')),
  );
}

class _FakeAuthRepository implements AuthRepository {
  String? lastResetToken;
  String? lastResetPassword;

  @override
  Future<AuthSession> exchangeGoogleCode({required String code}) async =>
      _session();

  @override
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => _session();

  @override
  Future<AuthSession> refresh({required String refreshToken}) async =>
      _session();

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    lastResetToken = token;
    lastResetPassword = newPassword;
  }

  @override
  Future<void> resendEmailVerification({required String accessToken}) async {}
}

AuthSession _session() {
  return AuthSession(
    userId: 'user-123',
    email: 'user@evolua.app',
    roles: const ['ROLE_USER'],
    accessToken: _jwt(),
  );
}

String _jwt() {
  String encode(Map<String, Object> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  final header = encode({'alg': 'none', 'typ': 'JWT'});
  final payload = encode({
    'sub': 'user-123',
    'email': 'user@evolua.app',
    'roles': const ['ROLE_USER'],
    'exp':
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000,
  });
  return '$header.$payload.signature';
}
