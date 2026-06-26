import 'dart:async';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/emotional/data/repositories/check_in_repository_impl.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.emotionalBaseUrl));
  return CheckInRepositoryImpl(dio);
});

final checkInControllerProvider =
    AsyncNotifierProvider<CheckInController, CheckInHistoryState>(
      CheckInController.new,
    );

final checkInInsightPollingConfigProvider =
    Provider<CheckInInsightPollingConfig>(
      (ref) => const CheckInInsightPollingConfig(
        delays: [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 3),
          Duration(seconds: 4),
          Duration(seconds: 6),
        ],
      ),
    );

class CheckInInsightPollingConfig {
  const CheckInInsightPollingConfig({required this.delays});

  final List<Duration> delays;
}

class CheckInHistoryState {
  const CheckInHistoryState({
    required this.result,
    required this.selectedGrouping,
    this.ownerUserId,
    this.latestCreatedCheckIn,
    this.pendingInsightCheckInId,
    this.unavailableInsightCheckInId,
    this.search,
    this.mood,
    this.energyRange,
    this.from,
    this.to,
    this.isCreatingCheckIn = false,
  });

  final PaginatedResponse<CheckIn> result;
  final String selectedGrouping;
  final String? ownerUserId;
  final CheckIn? latestCreatedCheckIn;
  final int? pendingInsightCheckInId;
  final int? unavailableInsightCheckInId;
  final String? search;
  final String? mood;
  final String? energyRange;
  final DateTime? from;
  final DateTime? to;
  final bool isCreatingCheckIn;

  bool get isLatestInsightPending =>
      latestCreatedCheckIn != null &&
      latestCreatedCheckIn!.id == pendingInsightCheckInId &&
      latestCreatedCheckIn!.aiInsight == null;

  bool get isLatestInsightUnavailable =>
      latestCreatedCheckIn != null &&
      latestCreatedCheckIn!.id == unavailableInsightCheckInId &&
      latestCreatedCheckIn!.aiInsight == null;

  bool belongsToUser(String? userId) =>
      ownerUserId == null || (userId != null && ownerUserId == userId);
}

class CheckInController extends AsyncNotifier<CheckInHistoryState> {
  static const _pageSize = 6;

  String? _search;
  String? _mood;
  String? _energyRange;
  DateTime? _from;
  DateTime? _to;
  String _selectedGrouping = 'monthly';
  CheckIn? _latestKnownCheckIn;
  int? _activeInsightPollId;
  int _pollGeneration = 0;
  Future<void>? _activeInsightPollFuture;
  Timer? _pollDelayTimer;
  Completer<void>? _pollDelayCompleter;
  Completer<void>? _resumeCompleter;
  AppLifecycleListener? _lifecycleListener;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  Future<void>? _createInFlight;
  bool _disposeRegistered = false;
  bool _disposed = false;

  @override
  Future<CheckInHistoryState> build() async {
    _registerDisposeHandler();
    final result = await _fetch(page: 0);
    final nextState = _stateFromResult(
      result,
      latestCreatedCheckIn: _canonicalLatestCheckIn(
        result,
        _latestKnownCheckIn ?? result.items.firstOrNull,
      ),
    );
    scheduleMicrotask(() => _ensureInsightPolling(nextState));
    return nextState;
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _fetch(page: current?.result.page ?? 0);
      return _stateFromResult(
        result,
        latestCreatedCheckIn: _canonicalLatestCheckIn(
          result,
          current?.latestCreatedCheckIn,
        ),
      );
    });
    _resumeInsightPollingFromState();
  }

  Future<void> applyFilters({
    String? search,
    String? mood,
    String? energyRange,
    DateTime? from,
    DateTime? to,
  }) async {
    _search = _normalizeText(search);
    _mood = _normalizeText(mood);
    _energyRange = _normalizeText(energyRange);
    _from = _normalizeDate(from);
    _to = _normalizeDate(to);

    final latestCreatedCheckIn = state.asData?.value.latestCreatedCheckIn;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _fetch(page: 0);
      return _stateFromResult(
        result,
        latestCreatedCheckIn: _canonicalLatestCheckIn(
          result,
          latestCreatedCheckIn,
        ),
      );
    });
    _resumeInsightPollingFromState();
  }

  Future<void> clearFilters() async {
    _search = null;
    _mood = null;
    _energyRange = null;
    _from = null;
    _to = null;

    final latestCreatedCheckIn = state.asData?.value.latestCreatedCheckIn;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _fetch(page: 0);
      return _stateFromResult(
        result,
        latestCreatedCheckIn: _canonicalLatestCheckIn(
          result,
          latestCreatedCheckIn,
        ),
      );
    });
    _resumeInsightPollingFromState();
  }

  Future<void> goToPage(int page) async {
    final latestCreatedCheckIn = state.asData?.value.latestCreatedCheckIn;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _fetch(page: page);
      return _stateFromResult(
        result,
        latestCreatedCheckIn: _canonicalLatestCheckIn(
          result,
          latestCreatedCheckIn,
        ),
      );
    });
    _resumeInsightPollingFromState();
  }

  void setGrouping(String grouping) {
    _selectedGrouping = grouping;
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    state = AsyncData(
      CheckInHistoryState(
        result: current.result,
        selectedGrouping: grouping,
        ownerUserId: current.ownerUserId,
        latestCreatedCheckIn: current.latestCreatedCheckIn,
        pendingInsightCheckInId: current.pendingInsightCheckInId,
        unavailableInsightCheckInId: current.unavailableInsightCheckInId,
        search: current.search,
        mood: current.mood,
        energyRange: current.energyRange,
        from: current.from,
        to: current.to,
        isCreatingCheckIn: current.isCreatingCheckIn,
      ),
    );
  }

  Future<void> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) async {
    final activeCreate = _createInFlight;
    if (activeCreate != null) {
      return activeCreate;
    }

    late final Future<void> operation;
    operation = _create(
      mood: mood,
      reflection: reflection,
      energyLevel: energyLevel,
    );
    _createInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_createInFlight, operation)) {
        _createInFlight = null;
      }
    }
  }

  Future<void> _create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) async {
    final repository = ref.read(checkInRepositoryProvider);
    final previous = state.asData?.value;
    int? pendingInsightId;
    if (previous != null) {
      state = AsyncData(_copyState(previous, isCreatingCheckIn: true));
    }
    try {
      final created = await repository.create(
        mood: mood,
        reflection: reflection,
        energyLevel: energyLevel,
      );
      _latestKnownCheckIn = created;

      ref.invalidate(currentJourneyTrailProvider);
      ref.invalidate(trailControllerProvider);

      late final PaginatedResponse<CheckIn> result;
      try {
        result = await _fetch(page: 0);
      } catch (_) {
        result = _resultWithCreatedCheckIn(previous?.result, created);
      }
      final latest = _canonicalLatestCheckIn(result, created);
      pendingInsightId = latest?.aiInsight == null ? latest?.id : null;
      state = AsyncData(
        _stateFromResult(
          result,
          latestCreatedCheckIn: latest,
          pendingInsightCheckInId: pendingInsightId,
          unavailableInsightCheckInId: null,
          isCreatingCheckIn: false,
        ),
      );
      _resumeInsightPollingFromState();
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(_copyState(previous, isCreatingCheckIn: false));
      } else {
        state = AsyncError(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  PaginatedResponse<CheckIn> _resultWithCreatedCheckIn(
    PaginatedResponse<CheckIn>? previous,
    CheckIn created,
  ) {
    final previousItems = previous?.items ?? const <CheckIn>[];
    final items = [
      created,
      ...previousItems.where((item) => item.id != created.id),
    ];
    return PaginatedResponse(
      items: items,
      page: previous?.page ?? 0,
      size: previous?.size ?? _pageSize,
      totalItems: previous == null
          ? items.length
          : (previous.totalItems +
                (previousItems.any((item) => item.id == created.id) ? 0 : 1)),
      totalPages: previous?.totalPages ?? 1,
      hasNext: previous?.hasNext ?? false,
      hasPrevious: previous?.hasPrevious ?? false,
      sortBy: previous?.sortBy ?? 'createdAt',
      sortDir: previous?.sortDir ?? 'desc',
      filters: previous?.filters ?? const {},
    );
  }

  CheckInHistoryState _copyState(
    CheckInHistoryState source, {
    bool? isCreatingCheckIn,
  }) {
    return CheckInHistoryState(
      result: source.result,
      selectedGrouping: source.selectedGrouping,
      ownerUserId: source.ownerUserId,
      latestCreatedCheckIn: source.latestCreatedCheckIn,
      pendingInsightCheckInId: source.pendingInsightCheckInId,
      unavailableInsightCheckInId: source.unavailableInsightCheckInId,
      search: source.search,
      mood: source.mood,
      energyRange: source.energyRange,
      from: source.from,
      to: source.to,
      isCreatingCheckIn: isCreatingCheckIn ?? source.isCreatingCheckIn,
    );
  }

  Future<CheckIn?> generateDeepReadingForLatest({String style = 'deep'}) async {
    final current = state.asData?.value;
    if (current == null) {
      return null;
    }
    final currentState = current;
    final latest = currentState.latestCreatedCheckIn;
    if (latest == null) {
      return null;
    }

    final repository = ref.read(checkInRepositoryProvider);
    CheckIn? refreshed;
    try {
      refreshed = await repository.generateDeepReading(latest.id, style: style);
      ref.invalidate(currentJourneyTrailProvider);
      ref.invalidate(trailControllerProvider);
      final result = await _fetch(page: currentState.result.page);
      state = AsyncData(
        _stateFromResult(
          result,
          latestCreatedCheckIn: _canonicalLatestCheckIn(result, refreshed),
        ),
      );
      _resumeInsightPollingFromState();
      return refreshed;
    } catch (error, stackTrace) {
      state = AsyncData(currentState);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<CheckIn?> saveReading(int checkInId) async {
    final current = state.asData?.value;
    if (current == null) {
      return null;
    }

    final repository = ref.read(checkInRepositoryProvider);
    CheckIn? refreshed;
    state = await AsyncValue.guard(() async {
      refreshed = await repository.saveReading(checkInId);
      final result = await _fetch(page: current.result.page);
      return _stateFromResult(
        result,
        latestCreatedCheckIn: _canonicalLatestCheckIn(result, refreshed),
      );
    });
    _resumeInsightPollingFromState();
    return refreshed;
  }

  Future<void> createRitualFromReading(
    int checkInId, {
    DateTime? localDate,
    String type = 'MORNING',
  }) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final repository = ref.read(checkInRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repository.createRitualFromReading(
        checkInId,
        localDate: localDate ?? DateTime.now(),
        type: type,
      );
      ref.invalidate(dailyRitualControllerProvider);
      final result = await _fetch(page: current.result.page);
      return _stateFromResult(
        result,
        latestCreatedCheckIn: current.latestCreatedCheckIn,
      );
    });
    _resumeInsightPollingFromState();
  }

  Future<PaginatedResponse<CheckIn>> _fetch({required int page}) {
    return ref
        .read(checkInRepositoryProvider)
        .list(
          page: page,
          size: _pageSize,
          search: _search,
          mood: _mood,
          energyRange: _energyRange,
          from: _from,
          to: _to,
        );
  }

  CheckInHistoryState _stateFromResult(
    PaginatedResponse<CheckIn> result, {
    CheckIn? latestCreatedCheckIn,
    int? pendingInsightCheckInId,
    int? unavailableInsightCheckInId,
    bool isCreatingCheckIn = false,
  }) {
    final latest =
        _canonicalLatestCheckIn(
          result,
          latestCreatedCheckIn ??
              state.asData?.value.latestCreatedCheckIn ??
              _latestKnownCheckIn,
        ) ??
        result.items.firstOrNull;
    final hasInsight = latest?.aiInsight != null;
    if (latest != null) {
      _latestKnownCheckIn = latest;
    }
    final nextUnavailableInsightCheckInId = hasInsight
        ? null
        : unavailableInsightCheckInId ??
              state.asData?.value.unavailableInsightCheckInId;
    final currentPendingInsightCheckInId =
        state.asData?.value.pendingInsightCheckInId;
    final shouldTrackPending =
        latest != null &&
        !hasInsight &&
        nextUnavailableInsightCheckInId != latest.id;
    return CheckInHistoryState(
      result: result,
      selectedGrouping: _selectedGrouping,
      ownerUserId: ref.read(authControllerProvider).asData?.value?.userId,
      latestCreatedCheckIn: latest,
      pendingInsightCheckInId: hasInsight
          ? null
          : pendingInsightCheckInId ??
                (currentPendingInsightCheckInId == latest?.id
                    ? currentPendingInsightCheckInId
                    : null) ??
                (shouldTrackPending ? latest.id : null),
      unavailableInsightCheckInId: hasInsight
          ? null
          : nextUnavailableInsightCheckInId,
      search: _search,
      mood: _mood,
      energyRange: _energyRange,
      from: _from,
      to: _to,
      isCreatingCheckIn: isCreatingCheckIn,
    );
  }

  CheckIn? _canonicalLatestCheckIn(
    PaginatedResponse<CheckIn> result,
    CheckIn? fallback,
  ) {
    final currentUserId = ref
        .read(authControllerProvider)
        .asData
        ?.value
        ?.userId;
    if (fallback != null) {
      if (currentUserId != null && fallback.userId != currentUserId) {
        return result.items.firstOrNull;
      }

      final listed = result.items
          .where((item) => item.id == fallback.id)
          .firstOrNull;
      if (listed != null) {
        return _preferMoreCompleteCheckIn(listed, fallback);
      }
    }

    return fallback ?? result.items.firstOrNull;
  }

  CheckIn _preferMoreCompleteCheckIn(CheckIn listed, CheckIn fallback) {
    if (listed.aiInsight != null && fallback.aiInsight == null) {
      return listed;
    }

    if (fallback.aiInsight != null && listed.aiInsight == null) {
      return fallback;
    }

    if (listed.recommendedPractice.trim().isNotEmpty &&
        fallback.recommendedPractice.trim().isEmpty) {
      return listed;
    }

    return listed.createdAt.isAfter(fallback.createdAt) ? listed : fallback;
  }

  void _resumeInsightPollingFromState() {
    final current = state.asData?.value;
    if (current != null) {
      _ensureInsightPolling(current);
    }
  }

  void _ensureInsightPolling(CheckInHistoryState current) {
    final latest = current.latestCreatedCheckIn;
    if (latest == null ||
        latest.aiInsight != null ||
        current.unavailableInsightCheckInId == latest.id) {
      return;
    }
    if (_activeInsightPollId == latest.id && _activeInsightPollFuture != null) {
      return;
    }

    final authState = ref.read(authControllerProvider);
    final userId = authState.asData?.value?.userId ?? current.ownerUserId;
    if (userId == null || latest.userId != userId) {
      return;
    }

    _pollGeneration++;
    _activeInsightPollId = latest.id;
    final context = _InsightPollContext(
      checkInId: latest.id,
      userId: userId,
      authSessionGeneration: ref.read(authSessionGenerationProvider),
      pollGeneration: _pollGeneration,
    );
    final future = _pollForInsight(context);
    _activeInsightPollFuture = future;
    unawaited(
      future.whenComplete(() {
        if (_isActivePollIdentity(context) &&
            identical(_activeInsightPollFuture, future)) {
          _activeInsightPollId = null;
          _activeInsightPollFuture = null;
        }
      }),
    );
  }

  Future<void> _pollForInsight(_InsightPollContext context) async {
    final pollingConfig = ref.read(checkInInsightPollingConfigProvider);
    final repository = ref.read(checkInRepositoryProvider);
    for (final delay in pollingConfig.delays) {
      final canAttempt = await _waitForResumedDelay(delay, context);
      if (!canAttempt || !_isCurrentPollContext(context)) {
        return;
      }
      try {
        final checkIn = await repository.getById(context.checkInId);
        if (!_isCurrentPollContext(context)) {
          return;
        }
        if (checkIn.aiInsight != null) {
          state = AsyncData(
            _stateWithUpdatedCheckIn(
              state.asData!.value,
              checkIn,
              pendingInsightCheckInId: null,
              unavailableInsightCheckInId: null,
            ),
          );
          ref.invalidate(currentJourneyTrailProvider);
          ref.invalidate(trailControllerProvider);
          return;
        }
      } catch (error) {
        if (!_isCurrentPollContext(context)) {
          return;
        }
        if (_isTerminalPollingError(error)) {
          _markInsightUnavailable(context);
          return;
        }
        // Keep the current state visible while the backend finishes processing.
      }
    }

    if (_isCurrentPollContext(context)) {
      _markInsightUnavailable(context);
    }
  }

  void _markInsightUnavailable(_InsightPollContext context) {
    final current = state.asData?.value;
    if (current == null || !_isCurrentPollContext(context)) {
      return;
    }
    state = AsyncData(
      CheckInHistoryState(
        result: current.result,
        selectedGrouping: current.selectedGrouping,
        ownerUserId: current.ownerUserId,
        latestCreatedCheckIn: current.latestCreatedCheckIn,
        pendingInsightCheckInId: null,
        unavailableInsightCheckInId: context.checkInId,
        search: current.search,
        mood: current.mood,
        energyRange: current.energyRange,
        from: current.from,
        to: current.to,
        isCreatingCheckIn: false,
      ),
    );
  }

  CheckInHistoryState _stateWithUpdatedCheckIn(
    CheckInHistoryState current,
    CheckIn updated, {
    int? pendingInsightCheckInId,
    int? unavailableInsightCheckInId,
  }) {
    final items = current.result.items
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);
    final result = current.result.copyWith(items: items);
    _latestKnownCheckIn = updated;
    return CheckInHistoryState(
      result: result,
      selectedGrouping: current.selectedGrouping,
      ownerUserId: current.ownerUserId,
      latestCreatedCheckIn: updated,
      pendingInsightCheckInId: pendingInsightCheckInId,
      unavailableInsightCheckInId: unavailableInsightCheckInId,
      search: current.search,
      mood: current.mood,
      energyRange: current.energyRange,
      from: current.from,
      to: current.to,
      isCreatingCheckIn: current.isCreatingCheckIn,
    );
  }

  bool _isTerminalPollingError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == null) {
        return false;
      }
      if (statusCode == 408 || statusCode == 429 || statusCode >= 500) {
        return false;
      }
      return statusCode == 404 ||
          statusCode == 410 ||
          (statusCode >= 400 && statusCode < 500);
    }
    return true;
  }

  String? _normalizeText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value.trim();
  }

  DateTime? _normalizeDate(DateTime? value) {
    if (value == null) {
      return null;
    }

    return DateTime(value.year, value.month, value.day);
  }

  void _registerDisposeHandler() {
    if (_disposeRegistered) {
      return;
    }
    _disposeRegistered = true;
    _ensureLifecycleListener();
    ref.onDispose(() {
      _disposed = true;
      _pollGeneration++;
      _activeInsightPollId = null;
      _activeInsightPollFuture = null;
      _pollDelayTimer?.cancel();
      final completer = _pollDelayCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      final resumeCompleter = _resumeCompleter;
      if (resumeCompleter != null && !resumeCompleter.isCompleted) {
        resumeCompleter.complete();
      }
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
    });
  }

  void _ensureLifecycleListener() {
    if (_lifecycleListener != null) {
      return;
    }
    final WidgetsBinding binding;
    try {
      binding = WidgetsBinding.instance;
    } catch (_) {
      _lifecycleState = AppLifecycleState.resumed;
      return;
    }
    _lifecycleState = binding.lifecycleState ?? AppLifecycleState.resumed;
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        _lifecycleState = state;
        if (state == AppLifecycleState.resumed) {
          final completer = _resumeCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
        }
      },
    );
  }

  Future<bool> _waitForResumedDelay(
    Duration delay,
    _InsightPollContext context,
  ) async {
    while (_isCurrentPollContext(context)) {
      if (!_isResumed) {
        await _waitForResume();
        continue;
      }
      await _waitForPollDelay(delay);
      if (!_isCurrentPollContext(context)) {
        return false;
      }
      if (_isResumed) {
        return true;
      }
    }
    return false;
  }

  bool get _isResumed => _lifecycleState == AppLifecycleState.resumed;

  Future<void> _waitForResume() {
    if (_isResumed || _disposed) {
      return Future<void>.value();
    }
    final existing = _resumeCompleter;
    if (existing != null) {
      return existing.future;
    }
    final completer = Completer<void>();
    _resumeCompleter = completer;
    return completer.future.whenComplete(() {
      if (identical(_resumeCompleter, completer)) {
        _resumeCompleter = null;
      }
    });
  }

  Future<void> _waitForPollDelay(Duration delay) {
    _pollDelayTimer?.cancel();
    final completer = Completer<void>();
    _pollDelayCompleter = completer;
    _pollDelayTimer = Timer(delay, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future.whenComplete(() {
      if (identical(_pollDelayCompleter, completer)) {
        _pollDelayCompleter = null;
        _pollDelayTimer = null;
      }
    });
  }

  bool _isCurrentPollContext(_InsightPollContext context) {
    if (!_isActivePollIdentity(context)) {
      return false;
    }
    final current = state.asData?.value;
    if (current?.pendingInsightCheckInId != context.checkInId) {
      return false;
    }
    final session = ref.read(authControllerProvider).asData?.value;
    return session?.userId == context.userId &&
        ref.read(authSessionGenerationProvider) ==
            context.authSessionGeneration;
  }

  bool _isActivePollIdentity(_InsightPollContext context) {
    return !_disposed &&
        ref.mounted &&
        _activeInsightPollId == context.checkInId &&
        _pollGeneration == context.pollGeneration;
  }
}

class _InsightPollContext {
  const _InsightPollContext({
    required this.checkInId,
    required this.userId,
    required this.authSessionGeneration,
    required this.pollGeneration,
  });

  final int checkInId;
  final String userId;
  final int authSessionGeneration;
  final int pollGeneration;
}
