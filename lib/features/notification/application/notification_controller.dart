import 'dart:convert';
import 'dart:math' as math;

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';
import 'package:evolua_frontend/features/notification/domain/repositories/notification_repository.dart';
import 'package:flutter/foundation.dart';
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

final localCareNotificationServiceProvider =
    Provider<LocalCareNotificationService>((ref) {
      return LocalCareNotificationService(ref);
    });

final notificationUnreadCountControllerProvider =
    NotifierProvider<
      NotificationUnreadCountController,
      NotificationUnreadCountState
    >(NotificationUnreadCountController.new);

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationUnreadCountControllerProvider).total;
});

enum NotificationUnreadCountError { remote, localStorage, both }

class NotificationUnreadCountState {
  const NotificationUnreadCountState({
    this.remoteUnreadCount = 0,
    this.localCareUnreadCount = 0,
    this.hasLoaded = false,
    this.isRefreshing = false,
    this.error,
  }) : assert(remoteUnreadCount >= 0),
       assert(localCareUnreadCount >= 0);

  final int remoteUnreadCount;
  final int localCareUnreadCount;
  final bool hasLoaded;
  final bool isRefreshing;
  final NotificationUnreadCountError? error;

  int get total => remoteUnreadCount + localCareUnreadCount;

  NotificationUnreadCountState copyWith({
    int? remoteUnreadCount,
    int? localCareUnreadCount,
    bool? hasLoaded,
    bool? isRefreshing,
    NotificationUnreadCountError? error,
    bool clearError = false,
  }) {
    return NotificationUnreadCountState(
      remoteUnreadCount: math.max(
        0,
        remoteUnreadCount ?? this.remoteUnreadCount,
      ),
      localCareUnreadCount: math.max(
        0,
        localCareUnreadCount ?? this.localCareUnreadCount,
      ),
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class LocalCareMutationResult {
  const LocalCareMutationResult({
    required this.changed,
    required this.unreadDelta,
  });

  final bool changed;
  final int unreadDelta;

  static const unchanged = LocalCareMutationResult(
    changed: false,
    unreadDelta: 0,
  );
}

class LocalCareNotificationService {
  const LocalCareNotificationService(this._ref);

  static const localCareNotificationsKey =
      'evolua.notifications.local_care_prescriptions';
  static const _limit = 20;

  final Ref _ref;

  Future<List<NotificationJob>> load(String userId) async {
    final preferences = await _ref.read(sharedPreferencesProvider.future);
    final raw = preferences.getString(_keyFor(userId));
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
          .where((item) => item.userId == userId)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<int> unreadCount(String userId) async {
    final items = await load(userId);
    return items.where((item) => !item.isRead).length;
  }

  Future<LocalCareMutationResult> addPrescription({
    required String userId,
    required String prescriptionId,
    required String ritualType,
  }) async {
    final currentItems = await load(userId);
    final id = 'care-prescription-$prescriptionId';
    if (currentItems.any((item) => item.id == id)) {
      return LocalCareMutationResult.unchanged;
    }
    final normalizedType = ritualType.toUpperCase() == 'EVENING'
        ? 'evening'
        : 'morning';
    final notification = NotificationJob(
      id: id,
      userId: userId,
      type: NotificationInboxController.carePrescriptionType,
      title: NotificationInboxController.carePrescriptionTitle,
      message: NotificationInboxController.carePrescriptionMessage,
      actionTarget: '/daily-ritual?type=$normalizedType',
      source: 'EVOLUA_CARE',
      createdBy: null,
      createdAt: DateTime.now(),
      readAt: null,
    );
    await save(userId, [notification, ...currentItems]);
    return const LocalCareMutationResult(changed: true, unreadDelta: 1);
  }

  Future<LocalCareMutationResult> markAsRead({
    required String userId,
    required String id,
  }) async {
    final currentItems = await load(userId);
    var changed = false;
    final now = DateTime.now();
    final updatedItems = [
      for (final item in currentItems)
        if (item.id == id && !item.isRead)
          () {
            changed = true;
            return item.copyWith(readAt: now);
          }()
        else
          item,
    ];
    if (!changed) {
      return LocalCareMutationResult.unchanged;
    }
    await save(userId, updatedItems);
    return const LocalCareMutationResult(changed: true, unreadDelta: -1);
  }

  Future<LocalCareMutationResult> markAllAsRead(String userId) async {
    final currentItems = await load(userId);
    final unreadCount = currentItems.where((item) => !item.isRead).length;
    if (unreadCount == 0) {
      return LocalCareMutationResult.unchanged;
    }
    final now = DateTime.now();
    await save(userId, [
      for (final item in currentItems)
        item.isRead ? item : item.copyWith(readAt: now),
    ]);
    return LocalCareMutationResult(changed: true, unreadDelta: -unreadCount);
  }

  Future<void> save(String userId, List<NotificationJob> items) async {
    final preferences = await _ref.read(sharedPreferencesProvider.future);
    final trimmed = items
        .where((item) => _isLocalCareNotification(item.id))
        .where((item) => item.userId == userId)
        .take(_limit)
        .map(_notificationToJson)
        .toList();
    await preferences.setString(_keyFor(userId), jsonEncode(trimmed));
    await preferences.remove(localCareNotificationsKey);
  }

  String _keyFor(String userId) => '$localCareNotificationsKey.$userId';

  static bool _isLocalCareNotification(String id) {
    return id.startsWith('care-prescription-');
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
      type:
          json['type']?.toString() ??
          NotificationInboxController.carePrescriptionType,
      title:
          json['title']?.toString() ??
          NotificationInboxController.carePrescriptionTitle,
      message:
          json['message']?.toString() ??
          NotificationInboxController.carePrescriptionMessage,
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

class NotificationUnreadCountController
    extends Notifier<NotificationUnreadCountState> {
  var _loadGeneration = 0;
  var _remoteRevision = 0;
  var _localRevision = 0;

  @override
  NotificationUnreadCountState build() {
    ref.watch(authControllerProvider);
    _loadGeneration++;
    _remoteRevision = 0;
    _localRevision = 0;
    Future.microtask(() => _load(isRefresh: false));
    return const NotificationUnreadCountState();
  }

  Future<void> refresh() => _load(isRefresh: true);

  void applyRemoteDelta(String userId, int delta) {
    if (!_isCurrentUser(userId)) {
      return;
    }
    _remoteRevision++;
    state = state.copyWith(
      remoteUnreadCount: state.remoteUnreadCount + delta,
      hasLoaded: true,
    );
  }

  void applyLocalCareDelta(String userId, int delta) {
    if (!_isCurrentUser(userId)) {
      return;
    }
    _localRevision++;
    state = state.copyWith(
      localCareUnreadCount: state.localCareUnreadCount + delta,
      hasLoaded: true,
    );
  }

  void clearRemote(String userId) {
    if (!_isCurrentUser(userId)) {
      return;
    }
    _remoteRevision++;
    state = state.copyWith(remoteUnreadCount: 0, hasLoaded: true);
  }

  void clearLocalCare(String userId) {
    if (!_isCurrentUser(userId)) {
      return;
    }
    _localRevision++;
    state = state.copyWith(localCareUnreadCount: 0, hasLoaded: true);
  }

  Future<void> _load({required bool isRefresh}) async {
    final userId = _currentUserId;
    final generation = ++_loadGeneration;
    final remoteRevision = _remoteRevision;
    final localRevision = _localRevision;
    if (userId == null) {
      state = const NotificationUnreadCountState(hasLoaded: true);
      return;
    }
    if (isRefresh && state.hasLoaded) {
      state = state.copyWith(isRefreshing: true, clearError: true);
    }

    final remoteFuture = _loadRemoteCount();
    final localFuture = _loadLocalCareCount(userId);
    final results = await Future.wait([remoteFuture, localFuture]);
    if (!ref.mounted ||
        generation != _loadGeneration ||
        !_isCurrentUser(userId)) {
      return;
    }

    final remote = results[0];
    final local = results[1];
    state = state.copyWith(
      remoteUnreadCount: remote.success && remoteRevision == _remoteRevision
          ? remote.count
          : state.remoteUnreadCount,
      localCareUnreadCount: local.success && localRevision == _localRevision
          ? local.count
          : state.localCareUnreadCount,
      hasLoaded: true,
      isRefreshing: false,
      error: _errorFor(
        remoteSuccess: remote.success,
        localSuccess: local.success,
      ),
      clearError: remote.success && local.success,
    );
  }

  Future<_UnreadCountLoadResult> _loadRemoteCount() async {
    try {
      final count = await ref
          .read(notificationRepositoryProvider)
          .unreadCount();
      return _UnreadCountLoadResult.success(count);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Notification unread count remote failed: ${error.runtimeType}.',
        );
      }
      return const _UnreadCountLoadResult.failure();
    }
  }

  Future<_UnreadCountLoadResult> _loadLocalCareCount(String userId) async {
    try {
      final count = await ref
          .read(localCareNotificationServiceProvider)
          .unreadCount(userId);
      return _UnreadCountLoadResult.success(count);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Notification unread count local storage failed: ${error.runtimeType}.',
        );
      }
      return const _UnreadCountLoadResult.failure();
    }
  }

  NotificationUnreadCountError? _errorFor({
    required bool remoteSuccess,
    required bool localSuccess,
  }) {
    if (remoteSuccess && localSuccess) {
      return null;
    }
    if (!remoteSuccess && !localSuccess) {
      return NotificationUnreadCountError.both;
    }
    if (!remoteSuccess) {
      return NotificationUnreadCountError.remote;
    }
    return NotificationUnreadCountError.localStorage;
  }

  bool _isCurrentUser(String userId) => _currentUserId == userId;

  String? get _currentUserId {
    final userId = ref.read(authControllerProvider).asData?.value?.userId;
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return userId;
  }
}

class _UnreadCountLoadResult {
  const _UnreadCountLoadResult._({required this.success, required this.count});

  const _UnreadCountLoadResult.failure() : this._(success: false, count: 0);

  factory _UnreadCountLoadResult.success(int count) {
    return _UnreadCountLoadResult._(success: true, count: math.max(0, count));
  }

  final bool success;
  final int count;
}

class NotificationInboxController extends AsyncNotifier<List<NotificationJob>> {
  static const carePrescriptionType = 'CARE_PRESCRIPTION';
  static const carePrescriptionTitle = 'Novo ritual do terapeuta';
  static const carePrescriptionMessage =
      'Seu terapeuta enviou um ritual personalizado para você.';

  @override
  Future<List<NotificationJob>> build() async {
    final remote = await ref.watch(notificationRepositoryProvider).list();
    final userId = await _resolveCurrentUserId();
    final local = userId == null
        ? const <NotificationJob>[]
        : await ref.read(localCareNotificationServiceProvider).load(userId);
    return _mergeNotifications(remote: remote, local: local);
  }

  Future<void> refresh({bool unreadOnly = false}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final remote = await ref
          .read(notificationRepositoryProvider)
          .list(unreadOnly: unreadOnly);
      final userId = await _resolveCurrentUserId();
      final local = userId == null
          ? const <NotificationJob>[]
          : await ref.read(localCareNotificationServiceProvider).load(userId);
      final merged = _mergeNotifications(remote: remote, local: local);
      return unreadOnly
          ? merged.where((item) => !item.isRead).toList()
          : merged;
    });
  }

  Future<void> markAsRead(String id) async {
    final currentItems = state.asData?.value ?? const <NotificationJob>[];
    final item = currentItems.where((item) => item.id == id).firstOrNull;
    if (item == null || item.isRead) {
      return;
    }
    final userId = await _resolveCurrentUserId();
    if (userId == null) {
      return;
    }
    if (_isLocalCareNotification(id)) {
      final result = await ref
          .read(localCareNotificationServiceProvider)
          .markAsRead(userId: userId, id: id);
      if (!_isCurrentUser(userId)) {
        return;
      }
      if (!result.changed) {
        return;
      }
      final updatedItems = [
        for (final item in currentItems)
          if (item.id == id) item.copyWith(readAt: DateTime.now()) else item,
      ];
      state = AsyncData(updatedItems);
      ref
          .read(notificationUnreadCountControllerProvider.notifier)
          .applyLocalCareDelta(userId, result.unreadDelta);
      return;
    }
    final repository = ref.read(notificationRepositoryProvider);
    final updated = await repository.markAsRead(id);
    if (!_isCurrentUser(userId)) {
      return;
    }

    state = AsyncData([
      for (final item in currentItems)
        if (item.id == id) updated else item,
    ]);
    ref
        .read(notificationUnreadCountControllerProvider.notifier)
        .applyRemoteDelta(userId, -1);
  }

  Future<void> markAllAsRead() async {
    final currentItems = state.asData?.value ?? const <NotificationJob>[];
    final userId = await _resolveCurrentUserId();
    if (userId == null) {
      return;
    }
    Object? remoteError;
    Object? localError;
    var remoteSucceeded = false;
    LocalCareMutationResult localResult = LocalCareMutationResult.unchanged;

    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead();
      remoteSucceeded = true;
    } catch (error) {
      remoteError = error;
    }

    try {
      localResult = await ref
          .read(localCareNotificationServiceProvider)
          .markAllAsRead(userId);
    } catch (error) {
      localError = error;
    }

    if (!_isCurrentUser(userId)) {
      return;
    }

    final now = DateTime.now();
    state = AsyncData([
      for (final item in currentItems)
        if (!item.isRead &&
            ((remoteSucceeded && !_isLocalCareNotification(item.id)) ||
                (localResult.changed && _isLocalCareNotification(item.id))))
          item.copyWith(readAt: now)
        else
          item,
    ]);
    final unreadCount = ref.read(
      notificationUnreadCountControllerProvider.notifier,
    );
    if (remoteSucceeded) {
      unreadCount.clearRemote(userId);
    }
    if (localResult.changed) {
      unreadCount.applyLocalCareDelta(userId, localResult.unreadDelta);
    }
    if (remoteError != null || localError != null) {
      throw const NotificationMarkAllAsReadException();
    }
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
    final userId = await _resolveCurrentUserId();
    if (userId == null) {
      return;
    }
    final result = await ref
        .read(localCareNotificationServiceProvider)
        .addPrescription(
          userId: userId,
          prescriptionId: prescriptionId,
          ritualType: ritualType,
        );
    if (!_isCurrentUser(userId)) {
      return;
    }
    if (result.changed) {
      ref
          .read(notificationUnreadCountControllerProvider.notifier)
          .applyLocalCareDelta(userId, result.unreadDelta);
    }
    ref.invalidateSelf();
  }

  Future<String?> _resolveCurrentUserId() async {
    final current = _currentUserId;
    if (current != null) {
      return current;
    }
    return (await ref.read(authControllerProvider.future))?.userId;
  }

  String? get _currentUserId {
    final userId = ref.read(authControllerProvider).asData?.value?.userId;
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return userId;
  }

  bool _isLocalCareNotification(String id) {
    return id.startsWith('care-prescription-');
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

  bool _isCurrentUser(String userId) {
    return _currentUserId == userId;
  }
}

class NotificationMarkAllAsReadException implements Exception {
  const NotificationMarkAllAsReadException();
}
