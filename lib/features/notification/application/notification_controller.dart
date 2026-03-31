import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';
import 'package:evolua_frontend/features/notification/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.notificationBaseUrl));
  return NotificationRepositoryImpl(dio);
});

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, List<NotificationJob>>(
  NotificationController.new,
);

class NotificationController extends AsyncNotifier<List<NotificationJob>> {
  @override
  Future<List<NotificationJob>> build() async {
    return ref.watch(notificationRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(notificationRepositoryProvider).list();
    });
  }

  Future<void> create({
    required String channel,
    required String message,
  }) async {
    final repository = ref.read(notificationRepositoryProvider);
    final currentItems = state.asData?.value ?? const <NotificationJob>[];

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final created = await repository.create(
        channel: channel,
        message: message,
      );

      return [created, ...currentItems];
    });
  }
}
