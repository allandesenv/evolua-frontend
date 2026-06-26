import 'dart:async';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/social/application/social_page_cache.dart';
import 'package:evolua_frontend/features/social/data/models/community_dto.dart';
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
  static const _freshTtl = Duration(minutes: 10);
  static const _maxStaleAge = Duration(hours: 2);

  String? _search;
  String? _visibility;
  String? _category;
  bool? _joined;
  int _requestRevision = 0;
  int _mutationGeneration = 0;
  Timer? _revalidateTimer;
  final _pageIds = <int, List<String>>{};

  @override
  Future<CommunityCatalogState> build() async {
    ref.onDispose(() => _revalidateTimer?.cancel());
    final context = await _contextFor(page: 0);
    if (context == null) {
      return CommunityCatalogState.initial();
    }
    final cached = await _readCached(context);
    if (cached != null) {
      _pageIds[0] = cached.result.items.map((item) => item.id).toList();
      final next = CommunityCatalogState(
        result: cached.result,
        isFromCache: true,
      );
      _scheduleBackgroundRefresh(context);
      return next;
    }
    final result = await _fetchRemote(context);
    _pageIds[0] = result.items.map((item) => item.id).toList();
    return CommunityCatalogState(result: result);
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    final page = current?.result.page ?? 0;
    final context = await _contextFor(page: page);
    if (context == null) {
      state = AsyncData(CommunityCatalogState.initial());
      return;
    }
    if (current == null || !current.hasItems) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        final result = await _fetchRemote(context);
        _pageIds[page] = result.items.map((item) => item.id).toList();
        return CommunityCatalogState(result: result);
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
      final result = await _fetchRemote(context);
      if (!_isCurrent(context)) return;
      _pageIds[page] = result.items.map((item) => item.id).toList();
      state = AsyncData(
        current.copyWith(
          result: result,
          isRefreshing: false,
          isFromCache: false,
          clearRefreshError: true,
        ),
      );
    } catch (error) {
      if (!_isCurrent(context)) return;
      state = AsyncData(
        current.copyWith(isRefreshing: false, refreshError: error),
      );
    }
  }

  Future<void> applyFilters({
    String? search,
    String? visibility,
    String? category,
    bool? joined,
  }) async {
    final normalizedSearch = _normalizeText(search);
    final normalizedVisibility = _normalizeText(visibility)?.toUpperCase();
    final normalizedCategory = _normalizeText(category)?.toLowerCase();
    if (_search == normalizedSearch &&
        _visibility == normalizedVisibility &&
        _category == normalizedCategory &&
        _joined == joined) {
      return;
    }
    _requestRevision++;
    _pageIds.clear();
    _search = normalizedSearch;
    _visibility = normalizedVisibility;
    _category = normalizedCategory;
    _joined = joined;
    await _loadPage(page: 0);
  }

  Future<void> goToPage(int page) async {
    _requestRevision++;
    await _loadPage(page: page);
  }

  Future<void> loadNextPage() async {
    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingMore ||
        current.isRefreshing ||
        !current.result.hasNext) {
      return;
    }
    final nextPage = current.result.page + 1;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    final context = await _contextFor(page: nextPage);
    if (context == null) {
      final latest = state.asData?.value ?? current;
      state = AsyncData(latest.copyWith(isLoadingMore: false));
      return;
    }
    final cached = await _readCached(context);
    if (cached != null) {
      _pageIds[nextPage] = cached.result.items.map((item) => item.id).toList();
      final merged = _mergePage(current.result, cached.result);
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(
          result: merged,
          isLoadingMore: false,
          isFromCache: true,
          clearLoadMoreError: true,
        ),
      );
      _scheduleBackgroundRefresh(context, replacePageOnly: true);
      return;
    }
    try {
      final pageResult = await _fetchRemote(context);
      if (!_isCurrent(context)) return;
      _pageIds[nextPage] = pageResult.items.map((item) => item.id).toList();
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(
          result: _mergePage(latest.result, pageResult),
          isLoadingMore: false,
          isFromCache: false,
          clearLoadMoreError: true,
        ),
      );
    } catch (error) {
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(isLoadingMore: false, loadMoreError: error),
      );
    }
  }

  Future<void> retryLoadMore() => loadNextPage();

  Future<void> create({
    required String name,
    required String slug,
    required String description,
    required String visibility,
    required String category,
  }) async {
    _mutationGeneration++;
    final mutationGeneration = _mutationGeneration;
    final created = await ref
        .read(communityRepositoryProvider)
        .create(
          name: name,
          slug: slug,
          description: description,
          visibility: visibility,
          category: category,
        );
    if (mutationGeneration == _mutationGeneration) {
      await _applyCommunityMutation(
        created,
        operation: _CommunityOperation.create,
      );
    }
  }

  Future<Community> join(String id) async {
    _mutationGeneration++;
    final mutationGeneration = _mutationGeneration;
    final joined = await ref.read(communityRepositoryProvider).join(id);
    if (mutationGeneration == _mutationGeneration) {
      await _applyCommunityMutation(
        joined,
        operation: _CommunityOperation.join,
      );
    }
    return joined;
  }

  Future<void> leave(String id) async {
    _mutationGeneration++;
    final mutationGeneration = _mutationGeneration;
    final left = await ref.read(communityRepositoryProvider).leave(id);
    if (mutationGeneration == _mutationGeneration) {
      await _applyCommunityMutation(left, operation: _CommunityOperation.leave);
    }
  }

  Future<void> _loadPage({required int page}) async {
    final context = await _contextFor(page: page);
    if (context == null) {
      state = AsyncData(CommunityCatalogState.initial());
      return;
    }
    final cached = await _readCached(context);
    if (cached != null) {
      _pageIds[page] = cached.result.items.map((item) => item.id).toList();
      state = AsyncData(
        CommunityCatalogState(result: cached.result, isFromCache: true),
      );
      _scheduleBackgroundRefresh(context);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _fetchRemote(context);
      _pageIds[page] = result.items.map((item) => item.id).toList();
      return CommunityCatalogState(result: result);
    });
  }

  Future<PaginatedResponse<Community>> _fetchRemote(
    _CommunityRequestContext context,
  ) async {
    final cache = await ref.read(socialPageCacheProvider.future);
    final result = await cache.runDeduplicated<PaginatedResponse<Community>>(
      context.cacheKey.requestKey,
      () {
        return ref
            .read(communityRepositoryProvider)
            .list(
              page: context.page,
              size: pageSize,
              search: _search,
              visibility: _visibility,
              category: _category,
              joined: _joined,
            );
      },
    );
    if (_isCurrent(context)) {
      await cache.write(
        key: context.cacheKey,
        payload: _responseToJson(result),
        nowUtc: DateTime.now().toUtc(),
      );
    }
    return result;
  }

  Future<_CachedCommunities?> _readCached(
    _CommunityRequestContext context,
  ) async {
    final cache = await ref.read(socialPageCacheProvider.future);
    final now = DateTime.now().toUtc();
    final entry = await cache.read(
      key: context.cacheKey,
      nowUtc: now,
      maxAge: _maxStaleAge,
    );
    if (entry == null) return null;
    try {
      return _CachedCommunities(
        result: _responseFromJson(entry.payload),
        isStale: entry.isStale(now, _freshTtl),
      );
    } catch (_) {
      await cache.remove(context.cacheKey);
      return null;
    }
  }

  void _scheduleBackgroundRefresh(
    _CommunityRequestContext context, {
    bool replacePageOnly = false,
  }) {
    Future.microtask(() async {
      if (!_isCurrent(context)) return;
      final current = state.asData?.value;
      if (current == null || current.isRefreshing) return;
      state = AsyncData(current.copyWith(isRefreshing: true));
      try {
        final result = await _fetchRemote(context);
        if (!_isCurrent(context)) return;
        final latest = state.asData?.value ?? current;
        final staleIds = _pageIds[context.page]?.toSet() ?? const <String>{};
        final nextResult = replacePageOnly
            ? _replacePage(latest.result, staleIds, result)
            : result;
        _pageIds[context.page] = result.items.map((item) => item.id).toList();
        state = AsyncData(
          latest.copyWith(
            result: nextResult,
            isRefreshing: false,
            isFromCache: false,
            clearRefreshError: true,
          ),
        );
      } catch (error) {
        if (!_isCurrent(context)) return;
        final latest = state.asData?.value;
        if (latest != null) {
          state = AsyncData(
            latest.copyWith(isRefreshing: false, refreshError: error),
          );
        }
      }
    });
  }

  void _scheduleMutationRevalidation() {
    _revalidateTimer?.cancel();
    _revalidateTimer = Timer(
      ref.read(socialMutationRevalidateDelayProvider),
      () {
        if (!ref.mounted) return;
        final page = state.asData?.value.result.page ?? 0;
        Future.microtask(() async {
          if (!ref.mounted) return;
          final context = await _contextFor(page: page);
          if (context != null) {
            _scheduleBackgroundRefresh(context);
          }
        });
      },
    );
  }

  Future<void> _applyCommunityMutation(
    Community community, {
    required _CommunityOperation operation,
  }) async {
    final value = state.asData?.value;
    if (value == null) {
      _scheduleMutationRevalidation();
      return;
    }
    var result = value.result;
    if (operation == _CommunityOperation.create) {
      if (result.page == 0 && _matchesCurrentFilters(community)) {
        final items = <Community>[
          community,
          ...result.items.where((item) => item.id != community.id),
        ].take(result.size).toList();
        result = _withAdjustedTotals(
          result.copyWith(items: items),
          totalItems: result.totalItems + 1,
        );
      }
    } else {
      final items = <Community>[];
      for (final item in result.items) {
        if (item.id == community.id) {
          if (_matchesCurrentFilters(community)) {
            items.add(community);
          }
        } else {
          items.add(item);
        }
      }
      final removed =
          result.items.any((item) => item.id == community.id) &&
          !items.any((item) => item.id == community.id);
      result = _withAdjustedTotals(
        result.copyWith(items: items),
        totalItems: result.totalItems - (removed ? 1 : 0),
      );
    }
    final next = CommunityCatalogState(result: result);
    state = AsyncData(next);
    await _invalidateOtherCommunityCachesAndPersist(next);
    _scheduleMutationRevalidation();
  }

  Future<void> _invalidateOtherCommunityCachesAndPersist(
    CommunityCatalogState next,
  ) async {
    final context = await _contextFor(page: next.result.page);
    if (context == null) return;
    final cache = await ref.read(socialPageCacheProvider.future);
    await cache.invalidate(
      resource: SocialPageCacheResource.communities,
      userId: context.userId,
    );
    await cache.write(
      key: context.cacheKey,
      payload: _responseToJson(next.result),
      nowUtc: DateTime.now().toUtc(),
    );
  }

  PaginatedResponse<Community> _mergePage(
    PaginatedResponse<Community> current,
    PaginatedResponse<Community> page,
  ) {
    final byId = <String, Community>{
      for (final item in current.items) item.id: item,
    };
    for (final item in page.items) {
      byId[item.id] = item;
    }
    return page.copyWith(items: byId.values.toList());
  }

  PaginatedResponse<Community> _replacePage(
    PaginatedResponse<Community> current,
    Set<String> staleIds,
    PaginatedResponse<Community> pageResult,
  ) {
    final byId = <String, Community>{
      for (final item in current.items)
        if (!staleIds.contains(item.id)) item.id: item,
    };
    for (final item in pageResult.items) {
      byId[item.id] = item;
    }
    return pageResult.copyWith(items: byId.values.toList());
  }

  bool _matchesCurrentFilters(Community community) {
    final search = _search;
    if (search != null &&
        !community.name.toLowerCase().contains(search) &&
        !community.description.toLowerCase().contains(search)) {
      return false;
    }
    if (_visibility != null &&
        community.visibility.toUpperCase() != _visibility) {
      return false;
    }
    if (_category != null && community.category.toLowerCase() != _category) {
      return false;
    }
    if (_joined != null && community.joined != _joined) {
      return false;
    }
    return true;
  }

  PaginatedResponse<Community> _withAdjustedTotals(
    PaginatedResponse<Community> result, {
    required int totalItems,
  }) {
    final normalizedTotal = totalItems.clamp(0, 1 << 31).toInt();
    final totalPages = normalizedTotal == 0
        ? 1
        : ((normalizedTotal + result.size - 1) ~/ result.size);
    return result.copyWith(
      totalItems: normalizedTotal,
      totalPages: totalPages,
      hasNext: result.page < totalPages - 1,
      hasPrevious: result.page > 0,
    );
  }

  Future<_CommunityRequestContext?> _contextFor({required int page}) async {
    var session = ref.read(authControllerProvider).asData?.value;
    if (session == null) {
      try {
        session = await ref.read(authControllerProvider.future);
      } catch (_) {
        return null;
      }
    }
    if (session == null) {
      return null;
    }
    if (!ref.mounted) {
      return null;
    }
    final locale = await effectiveSocialLocale(ref);
    if (!ref.mounted) {
      return null;
    }
    final cache = await ref.read(socialPageCacheProvider.future);
    if (!ref.mounted) {
      return null;
    }
    return _CommunityRequestContext(
      userId: session.userId,
      generation: ref.read(authSessionGenerationProvider),
      locale: locale,
      page: page,
      requestRevision: _requestRevision,
      mutationGeneration: _mutationGeneration,
      cacheKey: cache.key(
        resource: SocialPageCacheResource.communities,
        socialBaseUrl: AppConfig.socialBaseUrl,
        endpoint: '/v1/communities',
        userId: session.userId,
        locale: locale,
        page: page,
        size: pageSize,
        sortBy: 'createdAt',
        sortDir: 'desc',
        filters: _filters(),
      ),
    );
  }

  bool _isCurrent(_CommunityRequestContext context) {
    if (!ref.mounted) {
      return false;
    }
    final session = ref.read(authControllerProvider).asData?.value;
    return session?.userId == context.userId &&
        ref.read(authSessionGenerationProvider) == context.generation &&
        _requestRevision == context.requestRevision &&
        _mutationGeneration == context.mutationGeneration;
  }

  Map<String, Object?> _filters() {
    return {
      'search': _search,
      'visibility': _visibility,
      'category': _category,
      'joined': _joined,
    };
  }

  Map<String, dynamic> _responseToJson(PaginatedResponse<Community> result) {
    return {
      'items': result.items
          .map((item) => CommunityDto.fromEntity(item).toJson())
          .toList(),
      'page': result.page,
      'size': result.size,
      'totalItems': result.totalItems,
      'totalPages': result.totalPages,
      'hasNext': result.hasNext,
      'hasPrevious': result.hasPrevious,
      'sortBy': result.sortBy,
      'sortDir': result.sortDir,
      'filters': result.filters,
    };
  }

  PaginatedResponse<Community> _responseFromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CommunityDto.fromJson(Map<String, dynamic>.from(item)))
        .map((item) => item.toEntity())
        .toList();
    return PaginatedResponse(
      items: items,
      page: (json['page'] as num? ?? 0).toInt(),
      size: (json['size'] as num? ?? pageSize).toInt(),
      totalItems: (json['totalItems'] as num? ?? items.length).toInt(),
      totalPages: (json['totalPages'] as num? ?? 1).toInt(),
      hasNext: json['hasNext'] == true,
      hasPrevious: json['hasPrevious'] == true,
      sortBy: json['sortBy']?.toString() ?? 'createdAt',
      sortDir: json['sortDir']?.toString() ?? 'desc',
      filters: json['filters'] is Map
          ? Map<String, dynamic>.from(json['filters'] as Map)
          : const {},
    );
  }

  String? _normalizeText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text.toLowerCase();
  }
}

class _CachedCommunities {
  const _CachedCommunities({required this.result, required this.isStale});

  final PaginatedResponse<Community> result;
  final bool isStale;
}

class _CommunityRequestContext {
  const _CommunityRequestContext({
    required this.userId,
    required this.generation,
    required this.locale,
    required this.page,
    required this.requestRevision,
    required this.mutationGeneration,
    required this.cacheKey,
  });

  final String userId;
  final int generation;
  final String locale;
  final int page;
  final int requestRevision;
  final int mutationGeneration;
  final SocialPageCacheKey cacheKey;
}

enum _CommunityOperation { create, join, leave }
