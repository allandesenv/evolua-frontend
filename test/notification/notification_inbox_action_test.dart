import 'dart:convert';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/notification/application/notification_controller.dart';
import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';
import 'package:evolua_frontend/features/notification/domain/repositories/notification_repository.dart';
import 'package:evolua_frontend/features/notification/presentation/widgets/notification_module_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('notification bell shows unread badge and active icon', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository([_notification(id: 'n-1')]);

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification-unread-badge')),
      findsOneWidget,
    );
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('notification bell caps unread badge at nine plus', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository(
      List.generate(10, (index) => _notification(id: 'n-$index')),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('notification bell hides badge when inbox has no unread items', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository([
      _notification(id: 'n-1', read: true),
    ]);

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification-unread-badge')),
      findsNothing,
    );
  });

  testWidgets('reading notification removes bell badge', (tester) async {
    final repository = _FakeNotificationRepository([_notification(id: 'n-1')]);

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notificações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notificação n-1'));
    await tester.pumpAndSettle();

    expect(repository.readIds, ['n-1']);
    expect(
      find.byKey(const ValueKey('notification-unread-badge')),
      findsNothing,
    );
  });

  testWidgets('marking all notifications as read removes bell badge', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository([
      _notification(id: 'n-1'),
      _notification(id: 'n-2'),
    ]);

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notificações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar todas como lidas'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notification-unread-badge')),
      findsNothing,
    );
  });

  testWidgets('notification tap opens prescribed ritual route', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeNotificationRepository([
      NotificationJob(
        id: 'care-prescription-rx-1',
        userId: 'user-1',
        type: NotificationInboxController.carePrescriptionType,
        title: NotificationInboxController.carePrescriptionTitle,
        message: NotificationInboxController.carePrescriptionMessage,
        actionTarget: '/daily-ritual?type=morning',
        source: 'EVOLUA_CARE',
        createdBy: null,
        createdAt: DateTime(2026, 5, 27, 9),
        readAt: null,
      ),
    ]);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: NotificationBellButton())),
        ),
        GoRoute(
          path: '/daily-ritual',
          builder: (context, state) =>
              Text('ritual-${state.uri.queryParameters['type']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(
            () => _FakeAuthController(userId: 'user-1'),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_active_rounded));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(NotificationInboxController.carePrescriptionTitle),
    );
    await tester.pumpAndSettle();

    expect(repository.readIds, isEmpty);
    expect(find.text('ritual-morning'), findsOneWidget);
  });
}

Widget _testApp(_FakeNotificationRepository repository) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(
        () => _FakeAuthController(userId: 'user-1'),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: Center(child: NotificationBellButton())),
    ),
  );
}

NotificationJob _notification({required String id, bool read = false}) {
  return NotificationJob(
    id: id,
    userId: 'user-1',
    type: 'ADMIN_MESSAGE',
    title: 'Notificação $id',
    message: 'Mensagem $id',
    actionTarget: null,
    source: 'ADMIN',
    createdBy: 'admin',
    createdAt: DateTime(2026, 6, 3, 9),
    readAt: read ? DateTime(2026, 6, 3, 9, 5) : null,
  );
}

class _FakeAuthController extends AuthController {
  _FakeAuthController({required this.userId});

  final String userId;

  @override
  Future<AuthSession?> build() async {
    return AuthSession(
      userId: userId,
      email: '$userId@evolua.test',
      roles: const ['ROLE_USER'],
      accessToken:
          'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': userId, 'email': '$userId@evolua.test'})))}.signature',
    );
  }
}

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this.items);

  final List<NotificationJob> items;
  final readIds = <String>[];

  @override
  Future<NotificationJob> createAdmin({
    required String targetUserId,
    required String type,
    required String title,
    required String message,
    String? actionTarget,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<NotificationJob>> list({bool unreadOnly = false}) async =>
      unreadOnly ? items.where((item) => !item.isRead).toList() : items;

  @override
  Future<int> markAllAsRead() async => items.length;

  @override
  Future<NotificationJob> markAsRead(String id) async {
    readIds.add(id);
    final item = items.firstWhere((item) => item.id == id);
    return item.copyWith(readAt: DateTime(2026, 5, 27, 9, 5));
  }

  @override
  Future<int> unreadCount() async => items.where((item) => !item.isRead).length;
}
