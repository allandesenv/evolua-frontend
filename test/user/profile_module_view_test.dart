import 'dart:convert';
import 'dart:typed_data';

import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:evolua_frontend/features/user/presentation/widgets/profile_module_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('keeps profile hero readable on compact width', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ProfileModuleView(section: ProfileModuleSection.feedback),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Leo Respiro' &&
            widget.maxLines == 2 &&
            widget.overflow == TextOverflow.ellipsis,
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Trocar foto'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Atualizar'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> exchangeGoogleCode({required String code}) async {
    return _testSession();
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _testSession(email: email);
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<Profile?> getMe() async {
    return Profile(
      id: 1,
      userId: 'user-123',
      displayName: 'Leo Respiro',
      bio: '',
      journeyLevel: 1,
      premium: false,
      birthDate: DateTime(2000, 1, 1),
      gender: 'MALE',
      customGender: null,
      avatarUrl: null,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  }) async {
    return Profile(
      id: 1,
      userId: 'user-123',
      displayName: displayName,
      bio: bio,
      journeyLevel: journeyLevel,
      premium: false,
      birthDate: birthDate,
      gender: gender,
      customGender: customGender,
      avatarUrl: null,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return '';
  }
}

AuthSession _testSession({String email = 'leo@evolua.local'}) {
  return AuthSession(
    userId: 'user-123',
    email: email,
    roles: const ['ROLE_USER'],
    accessToken: _buildJwt(
      sub: 'user-123',
      email: email,
      roles: const ['ROLE_USER'],
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
    refreshToken: 'refresh-token',
  );
}

String _buildJwt({
  required String sub,
  required String email,
  required List<String> roles,
  required DateTime expiresAt,
}) {
  String encode(Map<String, Object> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  final header = encode({'alg': 'none', 'typ': 'JWT'});
  final payload = encode({
    'sub': sub,
    'email': email,
    'roles': roles,
    'exp': expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000,
  });

  return '$header.$payload.signature';
}
