import 'dart:async';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/social/data/repositories/community_repository_impl.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/features/social/domain/repositories/community_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.socialBaseUrl));
  return CommunityRepositoryImpl(dio);
});

final communityControllerProvider =
    AsyncNotifierProvider<CommunityController, CommunityCatalogState>(
      CommunityController.new,
    );

class CommunityCatalogState {
  const CommunityCatalogState({
    required this.result,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isFromCache = false,
    this.loadMoreError,
    this.refreshError,
  });

  final PaginatedResponse<Community> result;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isFromCache;
  final Object? loadMoreError;
  final Object? refreshError;

  bool get hasItems => result.items.isNotEmpty;

  CommunityCatalogState copyWith({
    PaginatedResponse<Community>? result,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isFromCache,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
    Object? refreshError,
    bool clearRefreshError = false,
  }) {
    return CommunityCatalogState(
      result: result ?? this.result,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isFromCache: isFromCache ?? this.isFromCache,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
      refreshError: clearRefreshError
          ? null
          : refreshError ?? this.refreshError,
    );
  }

  factory CommunityCatalogState.initial() {
    return CommunityCatalogState(
      result: PaginatedResponse.empty(
        page: 0,
        size: CommunityController.pageSize,
      ),
    );
  }
}

class CommunityController extends AsyncNotifier<CommunityCatalogState> {
  static const pageSize = 8;
  String? _search;
  String? _visibility;
  String? _category;
  bool? _joined;
  CommunityCatalogState? _lastState;

  @override
  Future<CommunityCatalogState> build() async {
    final cached = _lastState;
    if (cached != null) {
      unawaited(_refreshInBackground());
      return cached.copyWith(isFromCache: true, clearRefreshError: true);
    }
    final result = await _fetch(page: 0);
    final next = CommunityCatalogState(result: result);
    _lastState = next;
    return next;
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    if (current == null || !current.hasItems) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        final result = await _fetch(page: current?.result.page ?? 0);
        final next = CommunityCatalogState(result: result);
        _lastState = next;
        return next;
      });
      return;
    }

    state = AsyncData(
      current.copyWith(
        isRefreshing: true,
        clearRefreshError: true,
        clearLoadMoreError: true,
      ),
    );
    try {
      final result = await _fetch(page: current.result.page);
      final next = current.copyWith(
        result: result,
        isRefreshing: false,
        isFromCache: false,
        clearRefreshError: true,
      );
      _lastState = next;
      state = AsyncData(next);
    } catch (error) {
      final next = current.copyWith(isRefreshing: false, refreshError: error);
      _lastState = next;
      state = AsyncData(next);
    }
  }

  Future<void> applyFilters({
    String? search,
    String? visibility,
    String? category,
    bool? joined,
  }) async {
    final trimmedSearch = search?.trim();
    final normalizedSearch = trimmedSearch == null || trimmedSearch.isEmpty
        ? null
        : trimmedSearch;
    if (_search == normalizedSearch &&
        _visibility == visibility &&
        _category == category &&
        _joined == joined) {
      return;
    }
    _search = normalizedSearch;
    _visibility = visibility;
    _category = category;
    _joined = joined;
    final current = state.asData?.value;
    if (current == null || !current.hasItems) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        final result = await _fetch(page: 0);
        final next = CommunityCatalogState(result: result);
        _lastState = next;
        return next;
      });
      return;
    }
    state = AsyncData(
      current.copyWith(
        isRefreshing: true,
        clearRefreshError: true,
        clearLoadMoreError: true,
      ),
    );
    try {
      final result = await _fetch(page: 0);
      final next = CommunityCatalogState(result: result);
      _lastState = next;
      state = AsyncData(next);
    } catch (error) {
      final next = current.copyWith(isRefreshing: false, refreshError: error);
      _lastState = next;
      state = AsyncData(next);
    }
  }

  Future<void> goToPage(int page) async {
    final current = state.asData?.value;
    if (current == null || !current.hasItems) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        final result = await _fetch(page: page);
        final next = CommunityCatalogState(result: result);
        _lastState = next;
        return next;
      });
      return;
    }
    state = AsyncData(
      current.copyWith(isRefreshing: true, clearRefreshError: true),
    );
    try {
      final result = await _fetch(page: page);
      final next = CommunityCatalogState(result: result);
      _lastState = next;
      state = AsyncData(next);
    } catch (error) {
      final next = current.copyWith(isRefreshing: false, refreshError: error);
      _lastState = next;
      state = AsyncData(next);
    }
  }

  Future<void> loadNextPage() async {
    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingMore ||
        current.isRefreshing ||
        !current.result.hasNext) {
      return;
    }
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final nextPage = await _fetch(page: current.result.page + 1);
      final itemsById = <String, Community>{
        for (final item in current.result.items) item.id: item,
      };
      for (final item in nextPage.items) {
        itemsById[item.id] = item;
      }
      final merged = nextPage.copyWith(items: itemsById.values.toList());
      final next = current.copyWith(
        result: merged,
        isLoadingMore: false,
        isFromCache: false,
        clearLoadMoreError: true,
      );
      _lastState = next;
      state = AsyncData(next);
    } catch (error) {
      final next = current.copyWith(isLoadingMore: false, loadMoreError: error);
      _lastState = next;
      state = AsyncData(next);
    }
  }

  Future<void> retryLoadMore() => loadNextPage();

  Future<void> _refreshInBackground() async {
    final current = state.asData?.value ?? _lastState;
    if (current == null || current.isRefreshing) return;
    state = AsyncData(current.copyWith(isRefreshing: true));
    try {
      final result = await _fetch(page: current.result.page);
      final next = current.copyWith(
        result: result,
        isRefreshing: false,
        isFromCache: false,
        clearRefreshError: true,
      );
      _lastState = next;
      state = AsyncData(next);
    } catch (error) {
      final next = current.copyWith(isRefreshing: false, refreshError: error);
      _lastState = next;
      state = AsyncData(next);
    }
  }

  Future<void> create({
    required String name,
    required String slug,
    required String description,
    required String visibility,
    required String category,
  }) async {
    final repository = ref.read(communityRepositoryProvider);
    final current = state.asData?.value;
    state = AsyncData(
      (current ?? CommunityCatalogState.initial()).copyWith(
        isRefreshing: true,
        clearRefreshError: true,
      ),
    );
    state = await AsyncValue.guard(() async {
      await repository.create(
        name: name,
        slug: slug,
        description: description,
        visibility: visibility,
        category: category,
      );
      final result = await _fetch(page: 0);
      final next = CommunityCatalogState(result: result);
      _lastState = next;
      return next;
    });
  }

  Future<void> join(String id) async {
    final repository = ref.read(communityRepositoryProvider);
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(isRefreshing: true));
    } else {
      state = const AsyncLoading();
    }
    try {
      await repository.join(id);
      final page = current?.result.page ?? 0;
      final result = await _fetch(page: page);
      final next = CommunityCatalogState(result: result);
      _lastState = next;
      state = AsyncData(next);
    } catch (error, stackTrace) {
      if (current != null) {
        state = AsyncData(current.copyWith(isRefreshing: false));
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> leave(String id) async {
    final repository = ref.read(communityRepositoryProvider);
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(isRefreshing: true));
    } else {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(() async {
      await repository.leave(id);
      final page = current?.result.page ?? 0;
      final result = await _fetch(page: page);
      final next = CommunityCatalogState(result: result);
      _lastState = next;
      return next;
    });
  }

  Future<PaginatedResponse<Community>> _fetch({required int page}) {
    return ref
        .read(communityRepositoryProvider)
        .list(
          page: page,
          size: pageSize,
          search: _search,
          visibility: _visibility,
          category: _category,
          joined: _joined,
        );
  }
}
