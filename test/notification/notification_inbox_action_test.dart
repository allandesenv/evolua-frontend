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
