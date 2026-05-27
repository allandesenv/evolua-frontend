import 'dart:convert';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
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
  static const _localCareNotificationsKey =
      'evolua.notifications.local_care_prescriptions';
  static const carePrescriptionType = 'CARE_PRESCRIPTION';
  static const carePrescriptionTitle = 'Novo ritual do terapeuta';
  static const carePrescriptionMessage =
      'Seu terapeuta enviou um ritual personalizado para você.';

  @override
  Future<List<NotificationJob>> build() async {
    final remote = await ref.watch(notificationRepositoryProvider).list();
    final local = await _loadLocalCareNotifications();
    return _mergeNotifications(remote: remote, local: local);
  }

  Future<void> refresh({bool unreadOnly = false}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final remote = await ref
          .read(notificationRepositoryProvider)
          .list(unreadOnly: unreadOnly);
      final local = await _loadLocalCareNotifications();
      final merged = _mergeNotifications(remote: remote, local: local);
      return unreadOnly
          ? merged.where((item) => !item.isRead).toList()
          : merged;
    });
  }

  Future<void> markAsRead(String id) async {
    final currentItems = state.asData?.value ?? const <NotificationJob>[];
    if (_isLocalCareNotification(id)) {
      final updatedItems = [
        for (final item in currentItems)
          if (item.id == id) item.copyWith(readAt: DateTime.now()) else item,
      ];
      state = AsyncData(updatedItems);
      await _saveLocalCareNotifications(_localOnly(updatedItems));
      return;
    }
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
    final updatedItems = [
      for (final item in currentItems)
        item.isRead ? item : item.copyWith(readAt: DateTime.now()),
    ];
    state = AsyncData(updatedItems);
    await _saveLocalCareNotifications(_localOnly(updatedItems));
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

  Future<void> addCarePrescriptionNotification({
    required String prescriptionId,
    required String ritualType,
  }) async {
    final currentItems = state.asData?.value ?? const <NotificationJob>[];
    final id = 'care-prescription-$prescriptionId';
    if (currentItems.any((item) => item.id == id)) {
      return;
    }
    final normalizedType = ritualType.toUpperCase() == 'EVENING'
        ? 'evening'
        : 'morning';
    final notification = NotificationJob(
      id: id,
      userId: 'local',
      type: carePrescriptionType,
      title: carePrescriptionTitle,
      message: carePrescriptionMessage,
      actionTarget: '/daily-ritual?type=$normalizedType',
      source: 'EVOLUA_CARE',
      createdBy: null,
      createdAt: DateTime.now(),
      readAt: null,
    );
    final updatedItems = [notification, ...currentItems];
    state = AsyncData(updatedItems);
    await _saveLocalCareNotifications(_localOnly(updatedItems));
  }

  bool _isLocalCareNotification(String id) {
    return id.startsWith('care-prescription-');
  }

  List<NotificationJob> _localOnly(List<NotificationJob> items) {
    return items.where((item) => _isLocalCareNotification(item.id)).toList();
  }

  List<NotificationJob> _mergeNotifications({
    required List<NotificationJob> remote,
    required List<NotificationJob> local,
  }) {
    final seen = <String>{};
    final merged = <NotificationJob>[];
    for (final item in [...local, ...remote]) {
      if (seen.add(item.id)) {
        merged.add(item);
      }
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<List<NotificationJob>> _loadLocalCareNotifications() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final raw = preferences.getString(_localCareNotificationsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((item) => _notificationFromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveLocalCareNotifications(List<NotificationJob> items) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final trimmed = items.take(20).map(_notificationToJson).toList();
    await preferences.setString(
      _localCareNotificationsKey,
      jsonEncode(trimmed),
    );
  }

  Map<String, dynamic> _notificationToJson(NotificationJob item) {
    return {
      'id': item.id,
      'userId': item.userId,
      'type': item.type,
      'title': item.title,
      'message': item.message,
      'actionTarget': item.actionTarget,
      'source': item.source,
      'createdBy': item.createdBy,
      'createdAt': item.createdAt.toIso8601String(),
      'readAt': item.readAt?.toIso8601String(),
    };
  }

  NotificationJob _notificationFromJson(Map<String, dynamic> json) {
    return NotificationJob(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? 'local',
      type: json['type']?.toString() ?? carePrescriptionType,
      title: json['title']?.toString() ?? carePrescriptionTitle,
      message: json['message']?.toString() ?? carePrescriptionMessage,
      actionTarget: json['actionTarget']?.toString(),
      source: json['source']?.toString() ?? 'EVOLUA_CARE',
      createdBy: json['createdBy']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
    );
  }
}
