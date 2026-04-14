import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';
import 'package:evolua_frontend/features/notification/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dio = ref.watch(
    authenticatedDioProvider(AppConfig.notificationBaseUrl),
  );
  return NotificationRepositoryImpl(dio);
});

final notificationInboxControllerProvider =
    AsyncNotifierProvider<NotificationInboxController, List<NotificationJob>>(
      NotificationInboxController.new,
    );

final unreadNotificationCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationInboxControllerProvider).asData?.value;
  if (items == null) {
    return 0;
  }
  return items.where((item) => !item.isRead).length;
});

class NotificationInboxController extends AsyncNotifier<List<NotificationJob>> {
  @override
  Future<List<NotificationJob>> build() async {
    return ref.watch(notificationRepositoryProvider).list();
  }

  Future<void> refresh({bool unreadOnly = false}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref
          .read(notificationRepositoryProvider)
          .list(unreadOnly: unreadOnly);
    });
  }

  Future<void> markAsRead(String id) async {
    final currentItems = state.asData?.value ?? const <NotificationJob>[];
    final repository = ref.read(notificationRepositoryProvider);
    final updated = await repository.markAsRead(id);

    state = AsyncData([
      for (final item in currentItems)
        if (item.id == id) updated else item,
    ]);
  }

  Future<void> markAllAsRead() async {
    final currentItems = state.asData?.value ?? const <NotificationJob>[];
    await ref.read(notificationRepositoryProvider).markAllAsRead();
    state = AsyncData([
      for (final item in currentItems)
        item.isRead ? item : item.copyWith(readAt: DateTime.now()),
    ]);
  }

  Future<void> createAdmin({
    required String targetUserId,
    required String type,
    required String title,
    required String message,
    String? actionTarget,
  }) async {
    await ref
        .read(notificationRepositoryProvider)
        .createAdmin(
          targetUserId: targetUserId,
          type: type,
          title: title,
          message: message,
          actionTarget: actionTarget,
        );
  }
}
