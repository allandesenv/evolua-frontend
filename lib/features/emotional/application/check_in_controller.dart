import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
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

class CheckInHistoryState {
  const CheckInHistoryState({
    required this.result,
    required this.selectedGrouping,
    this.latestCreatedCheckIn,
    this.search,
    this.mood,
    this.energyRange,
    this.from,
    this.to,
  });

  final PaginatedResponse<CheckIn> result;
  final String selectedGrouping;
  final CheckIn? latestCreatedCheckIn;
  final String? search;
  final String? mood;
  final String? energyRange;
  final DateTime? from;
  final DateTime? to;
}

class CheckInController extends AsyncNotifier<CheckInHistoryState> {
  static const _pageSize = 6;

  String? _search;
  String? _mood;
  String? _energyRange;
  DateTime? _from;
  DateTime? _to;
  String _selectedGrouping = 'monthly';

  @override
  Future<CheckInHistoryState> build() async {
    final result = await _fetch(page: 0);
    return _stateFromResult(
      result,
      latestCreatedCheckIn: result.items.firstOrNull,
    );
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async {
        final result = await _fetch(page: current?.result.page ?? 0);
        return _stateFromResult(
          result,
          latestCreatedCheckIn: _canonicalLatestCheckIn(
            result,
            current?.latestCreatedCheckIn,
          ),
        );
      },
    );
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
    state = await AsyncValue.guard(
      () async {
        final result = await _fetch(page: 0);
        return _stateFromResult(
          result,
          latestCreatedCheckIn: _canonicalLatestCheckIn(
            result,
            latestCreatedCheckIn,
          ),
        );
      },
    );
  }

  Future<void> clearFilters() async {
    _search = null;
    _mood = null;
    _energyRange = null;
    _from = null;
    _to = null;

    final latestCreatedCheckIn = state.asData?.value.latestCreatedCheckIn;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async {
        final result = await _fetch(page: 0);
        return _stateFromResult(
          result,
          latestCreatedCheckIn: _canonicalLatestCheckIn(
            result,
            latestCreatedCheckIn,
          ),
        );
      },
    );
  }

  Future<void> goToPage(int page) async {
    final latestCreatedCheckIn = state.asData?.value.latestCreatedCheckIn;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async {
        final result = await _fetch(page: page);
        return _stateFromResult(
          result,
          latestCreatedCheckIn: _canonicalLatestCheckIn(
            result,
            latestCreatedCheckIn,
          ),
        );
      },
    );
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
        latestCreatedCheckIn: current.latestCreatedCheckIn,
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final created = await repository.create(
        mood: mood,
        reflection: reflection,
        energyLevel: energyLevel,
      );

      ref.invalidate(currentJourneyTrailProvider);
      ref.invalidate(trailControllerProvider);

      final result = await _fetch(page: 0);
      return _stateFromResult(
        result,
        latestCreatedCheckIn: _canonicalLatestCheckIn(result, created),
      );
    });
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
  }) {
    return CheckInHistoryState(
      result: result,
      selectedGrouping: _selectedGrouping,
      latestCreatedCheckIn:
          latestCreatedCheckIn ?? state.asData?.value.latestCreatedCheckIn,
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
    if (fallback != null) {
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

    if (listed.recommendedPractice.trim().isNotEmpty &&
        fallback.recommendedPractice.trim().isEmpty) {
      return listed;
    }

    return listed.createdAt.isAfter(fallback.createdAt) ? listed : fallback;
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
}
