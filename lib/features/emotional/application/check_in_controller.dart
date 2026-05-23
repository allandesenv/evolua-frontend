import 'dart:async';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/emotional/data/repositories/check_in_repository_impl.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
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
        attempts: 8,
        delay: Duration(seconds: 2),
      ),
    );

class CheckInInsightPollingConfig {
  const CheckInInsightPollingConfig({
    required this.attempts,
    required this.delay,
  });

  final int attempts;
  final Duration delay;
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
  Timer? _pollDelayTimer;
  Completer<void>? _pollDelayCompleter;
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
      ),
    );
  }

  Future<void> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) async {
    final repository = ref.read(checkInRepositoryProvider);
    int? pendingInsightId;
    try {
      final created = await repository.create(
        mood: mood,
        reflection: reflection,
        energyLevel: energyLevel,
      );
      _latestKnownCheckIn = created;

      ref.invalidate(currentJourneyTrailProvider);
      ref.invalidate(trailControllerProvider);

      final result = await _fetch(page: 0);
      final latest = _canonicalLatestCheckIn(result, created);
      pendingInsightId = latest?.aiInsight == null ? latest?.id : null;
      state = AsyncData(
        _stateFromResult(
          result,
          latestCreatedCheckIn: latest,
          pendingInsightCheckInId: pendingInsightId,
          unavailableInsightCheckInId: null,
        ),
      );
      _resumeInsightPollingFromState();
    } catch (error, stackTrace) {
      final previous = state.asData?.value;
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<CheckIn?> generateDeepReadingForLatest() async {
    final current = state.asData?.value;
    final latest = current?.latestCreatedCheckIn;
    if (latest == null) {
      return null;
    }

    final repository = ref.read(checkInRepositoryProvider);
    state = const AsyncLoading();
    CheckIn? refreshed;
    state = await AsyncValue.guard(() async {
      refreshed = await repository.generateDeepReading(latest.id);
      ref.invalidate(currentJourneyTrailProvider);
      ref.invalidate(trailControllerProvider);
      final result = await _fetch(page: current?.result.page ?? 0);
      return _stateFromResult(
        result,
        latestCreatedCheckIn: _canonicalLatestCheckIn(result, refreshed),
      );
    });
    _resumeInsightPollingFromState();
    return refreshed;
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
    if (_activeInsightPollId == latest.id) {
      return;
    }

    _activeInsightPollId = latest.id;
    unawaited(
      _pollForInsight(latest.id).whenComplete(() {
        if (_activeInsightPollId == latest.id) {
          _activeInsightPollId = null;
        }
      }),
    );
  }

  Future<void> _pollForInsight(int checkInId) async {
    final pollingConfig = ref.read(checkInInsightPollingConfigProvider);
    for (var attempt = 0; attempt < pollingConfig.attempts; attempt++) {
      await _waitForPollDelay(pollingConfig.delay);
      if (_disposed) {
        return;
      }
      if (state.asData?.value.pendingInsightCheckInId != checkInId) {
        return;
      }
      try {
        final result = await _fetch(page: 0);
        final listed = result.items
            .where((item) => item.id == checkInId)
            .firstOrNull;
        if (listed?.aiInsight != null) {
          state = AsyncData(
            _stateFromResult(
              result,
              latestCreatedCheckIn: listed,
              pendingInsightCheckInId: null,
              unavailableInsightCheckInId: null,
            ),
          );
          ref.invalidate(currentJourneyTrailProvider);
          ref.invalidate(trailControllerProvider);
          return;
        }
      } catch (_) {
        // Keep the current state visible while the backend finishes processing.
      }
    }

    final current = state.asData?.value;
    if (current == null || current.pendingInsightCheckInId != checkInId) {
      return;
    }
    state = AsyncData(
      CheckInHistoryState(
        result: current.result,
        selectedGrouping: current.selectedGrouping,
        ownerUserId: current.ownerUserId,
        latestCreatedCheckIn: current.latestCreatedCheckIn,
        pendingInsightCheckInId: null,
        unavailableInsightCheckInId: checkInId,
        search: current.search,
        mood: current.mood,
        energyRange: current.energyRange,
        from: current.from,
        to: current.to,
      ),
    );
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
    ref.onDispose(() {
      _disposed = true;
      _pollDelayTimer?.cancel();
      final completer = _pollDelayCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
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
}
