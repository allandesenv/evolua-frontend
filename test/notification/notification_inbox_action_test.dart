import 'dart:async';
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
  testWidgets('notification bell calls unread count without loading inbox', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository([_notification(id: 'n-1')]);

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(repository.unreadCountCalls, greaterThanOrEqualTo(1));
    expect(repository.listCalls, 0);
    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
  });

  testWidgets('opening notification inbox loads list once', (tester) async {
    final repository = _FakeNotificationRepository([_notification(id: 'n-1')]);

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    expect(repository.listCalls, 0);

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(repository.unreadCountCalls, greaterThanOrEqualTo(1));
  });

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
    expect(repository.listCalls, 0);
    expect(repository.unreadCountCalls, greaterThanOrEqualTo(1));
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
    expect(repository.listCalls, 1);
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

    expect(repository.listCalls, 1);
    expect(repository.markAllAsReadCalls, 1);
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

  testWidgets('check-in notification tap opens home instead of check-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeNotificationRepository([
      NotificationJob(
        id: 'check-in-reminder-1',
        userId: 'user-1',
        type: 'CHECKIN_REMINDER',
        title: 'Hora do check-in',
        message: 'Registre seu momento no Evolua.',
        actionTarget: '/check-in',
        source: 'SYSTEM',
        createdBy: null,
        createdAt: DateTime(2026, 6, 15, 8),
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
          path: '/home',
          builder: (context, state) => const Text('home-opened'),
        ),
        GoRoute(
          path: '/check-in',
          builder: (context, state) => const Text('check-in-opened'),
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
    await tester.tap(find.text('Hora do check-in'));
    await tester.pumpAndSettle();

    expect(repository.readIds, ['check-in-reminder-1']);
    expect(find.text('home-opened'), findsOneWidget);
    expect(find.text('check-in-opened'), findsNothing);
  });

  testWidgets('care notification can update badge without opening inbox', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeNotificationRepository(const []);
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(
            () => _FakeAuthController(userId: 'user-1'),
          ),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              home: Scaffold(body: Center(child: NotificationBellButton())),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.listCalls, 0);
    expect(
      find.byKey(const ValueKey('notification-unread-badge')),
      findsNothing,
    );

    const userId = 'user-1';
    final result = await container
        .read(localCareNotificationServiceProvider)
        .addPrescription(
          userId: userId,
          prescriptionId: 'rx-1',
          ritualType: 'MORNING',
        );
    expect(result.changed, isTrue);
    expect(result.unreadDelta, 1);
    container
        .read(notificationUnreadCountControllerProvider.notifier)
        .applyLocalCareDelta(userId, result.unreadDelta);
    await tester.pumpAndSettle();

    expect(repository.listCalls, 0);
    expect(find.text('1'), findsOneWidget);
    final persisted = await container
        .read(localCareNotificationServiceProvider)
        .load(userId);
    expect(persisted.single.id, 'care-prescription-rx-1');
  });

  test('local care service reports deltas only when storage changes', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _FakeAuthController(userId: 'user-1'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final service = container.read(localCareNotificationServiceProvider);

    final inserted = await service.addPrescription(
      userId: 'user-1',
      prescriptionId: 'rx-1',
      ritualType: 'MORNING',
    );
    final duplicate = await service.addPrescription(
      userId: 'user-1',
      prescriptionId: 'rx-1',
      ritualType: 'MORNING',
    );
    final read = await service.markAsRead(
      userId: 'user-1',
      id: 'care-prescription-rx-1',
    );
    final repeatedRead = await service.markAsRead(
      userId: 'user-1',
      id: 'care-prescription-rx-1',
    );

    expect(inserted.changed, isTrue);
    expect(inserted.unreadDelta, 1);
    expect(duplicate.changed, isFalse);
    expect(duplicate.unreadDelta, 0);
    expect(read.changed, isTrue);
    expect(read.unreadDelta, -1);
    expect(repeatedRead.changed, isFalse);
    expect(repeatedRead.unreadDelta, 0);
  });

  test('local care counts are isolated by user', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(localCareNotificationServiceProvider);

    await service.addPrescription(
      userId: 'user-a',
      prescriptionId: 'rx-1',
      ritualType: 'MORNING',
    );

    expect(await service.unreadCount('user-a'), 1);
    expect(await service.unreadCount('user-b'), 0);
  });

  test('initial load result does not overwrite care delta', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeNotificationRepository(const []);
    final localCountGate = Completer<int>();
    late _GatedLocalCareNotificationService service;
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(userId: 'user-1'),
        ),
        localCareNotificationServiceProvider.overrideWith((ref) {
          service = _GatedLocalCareNotificationService(
            ref,
            unreadCountGate: localCountGate,
          );
          return service;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    container.read(notificationUnreadCountControllerProvider);
    await _flushMicrotasks();
    final result = await service.addPrescription(
      userId: 'user-1',
      prescriptionId: 'rx-1',
      ritualType: 'MORNING',
    );
    container
        .read(notificationUnreadCountControllerProvider.notifier)
        .applyLocalCareDelta('user-1', result.unreadDelta);
    localCountGate.complete(0);
    await _flushMicrotasks();

    final state = container.read(notificationUnreadCountControllerProvider);
    expect(state.localCareUnreadCount, 1);
    expect(state.total, 1);
  });

  test('refresh result does not undo remote read delta', () async {
    SharedPreferences.setMockInitialValues({});
    final refreshGate = Completer<int>();
    final repository = _FakeNotificationRepository(
      [_notification(id: 'n-1'), _notification(id: 'n-2')],
      queuedUnreadCounts: [2, refreshGate.future],
    );
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(userId: 'user-1'),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(notificationUnreadCountControllerProvider);
    await _flushMicrotasks();
    expect(container.read(notificationUnreadCountControllerProvider).total, 2);

    final refresh = container
        .read(notificationUnreadCountControllerProvider.notifier)
        .refresh();
    await _flushMicrotasks();
    container
        .read(notificationUnreadCountControllerProvider.notifier)
        .applyRemoteDelta('user-1', -1);
    refreshGate.complete(2);
    await refresh;

    final state = container.read(notificationUnreadCountControllerProvider);
    expect(state.remoteUnreadCount, 1);
    expect(state.total, 1);
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
  _FakeNotificationRepository(this.items, {List<Object>? queuedUnreadCounts})
    : _queuedUnreadCounts = queuedUnreadCounts ?? [];

  final List<NotificationJob> items;
  final List<Object> _queuedUnreadCounts;
  final readIds = <String>[];
  var listCalls = 0;
  var unreadCountCalls = 0;
  var markAllAsReadCalls = 0;

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
  Future<List<NotificationJob>> list({bool unreadOnly = false}) async {
    listCalls++;
    return unreadOnly ? items.where((item) => !item.isRead).toList() : items;
  }

  @override
  Future<int> markAllAsRead() async {
    markAllAsReadCalls++;
    return items.length;
  }

  @override
  Future<NotificationJob> markAsRead(String id) async {
    readIds.add(id);
    final item = items.firstWhere((item) => item.id == id);
    return item.copyWith(readAt: DateTime(2026, 5, 27, 9, 5));
  }

  @override
  Future<int> unreadCount() async {
    unreadCountCalls++;
    if (_queuedUnreadCounts.isNotEmpty) {
      final next = _queuedUnreadCounts.removeAt(0);
      if (next is Future<int>) {
        return next;
      }
      if (next is int) {
        return next;
      }
      throw next;
    }
    return items.where((item) => !item.isRead).length;
  }
}

class _GatedLocalCareNotificationService extends LocalCareNotificationService {
  const _GatedLocalCareNotificationService(
    super.ref, {
    required this.unreadCountGate,
  });

  final Completer<int> unreadCountGate;

  @override
  Future<int> unreadCount(String userId) {
    return unreadCountGate.future;
  }
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
