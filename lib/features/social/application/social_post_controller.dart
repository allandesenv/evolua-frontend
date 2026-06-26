import 'dart:async';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/social/application/social_feed_state.dart';
import 'package:evolua_frontend/features/social/application/social_page_cache.dart';
import 'package:evolua_frontend/features/social/data/models/social_post_dto.dart';
import 'package:evolua_frontend/features/social/data/repositories/social_post_repository_impl.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/features/social/domain/repositories/social_post_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final socialPostRepositoryProvider = Provider<SocialPostRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.socialBaseUrl));
  return SocialPostRepositoryImpl(dio);
});

final socialPostControllerProvider =
    AsyncNotifierProvider<SocialPostController, SocialFeedState>(
      SocialPostController.new,
    );

class SocialPostController extends AsyncNotifier<SocialFeedState> {
  static const _pageSize = 4;
  static const _freshTtl = Duration(minutes: 5);
  static const _maxStaleAge = Duration(minutes: 30);

  String? _search;
  String? _community;
  String? _visibility;
  bool? _mine;
  int _requestRevision = 0;
  int _mutationGeneration = 0;
  Timer? _revalidateTimer;

  static Future<void> clearOfflineCache(Ref ref) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await clearOfflineCacheFromPreferences(preferences);
  }

  static Future<void> clearOfflineCacheFromPreferences(
    SharedPreferences preferences,
  ) {
    return SocialPageCache.clearAllSocialCaches(preferences);
  }

  @override
  Future<SocialFeedState> build() async {
    ref.onDispose(() => _revalidateTimer?.cancel());
    final context = await _contextFor(page: 0);
    if (context == null) {
      return SocialFeedState.fresh(_empty(page: 0));
    }
    final cached = await _readCached(context);
    if (cached != null) {
      final state = SocialFeedState.cached(
        cached.result,
      ).copyWith(isStale: cached.isStale);
      _scheduleBackgroundRefresh(context);
      return state;
    }
    try {
      return SocialFeedState.fresh(await _fetchRemote(context));
    } catch (error) {
      if (_isNetworkError(error)) {
        return SocialFeedState.offlineEmpty(
          page: 0,
          size: _pageSize,
          sortBy: 'createdAt',
          sortDir: 'desc',
          filters: Map<String, dynamic>.from(_filters()),
        );
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    final page = current?.result.page ?? 0;
    final context = await _contextFor(page: page);
    if (context == null) {
      state = AsyncData(SocialFeedState.fresh(_empty(page: page)));
      return;
    }
    if (current != null) {
      state = AsyncData(
        current.copyWith(isRefreshing: true, clearRefreshError: true),
      );
    } else {
      state = const AsyncLoading();
    }
    try {
      final result = await _fetchRemote(context);
      if (!_isCurrent(context)) return;
      state = AsyncData(SocialFeedState.fresh(result));
    } catch (error, stackTrace) {
      if (current != null) {
        state = AsyncData(
          current.copyWith(isRefreshing: false, refreshError: error),
        );
      } else {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<void> applyFilters({
    String? search,
    String? community,
    String? visibility,
    bool? mine,
  }) async {
    _requestRevision++;
    _search = _normalizeText(search);
    _community = _normalizeText(community);
    _visibility = _normalizeText(visibility)?.toUpperCase();
    _mine = mine;
    await _loadPage(page: 0);
  }

  Future<void> goToPage(int page) async {
    _requestRevision++;
    await _loadPage(page: page);
  }

  Future<SocialPost?> create({
    required String content,
    required String community,
    required String visibility,
  }) async {
    _mutationGeneration++;
    final mutationGeneration = _mutationGeneration;
    final repository = ref.read(socialPostRepositoryProvider);
    try {
      final createdPost = await repository.create(
        content: content,
        community: community,
        visibility: visibility,
      );
      if (mutationGeneration != _mutationGeneration) {
        return createdPost;
      }
      await _applyPostMutation(createdPost, operation: _PostOperation.create);
      return createdPost;
    } catch (_) {
      return null;
    }
  }

  Future<SocialPost> updatePost({
    required String id,
    required String content,
  }) async {
    _mutationGeneration++;
    final mutationGeneration = _mutationGeneration;
    final updatedPost = await ref
        .read(socialPostRepositoryProvider)
        .update(id: id, content: content);
    if (mutationGeneration == _mutationGeneration) {
      await _applyPostMutation(updatedPost, operation: _PostOperation.update);
    }
    return updatedPost;
  }

  Future<void> deletePost(String id) async {
    _mutationGeneration++;
    final mutationGeneration = _mutationGeneration;
    await ref.read(socialPostRepositoryProvider).delete(id);
    if (mutationGeneration == _mutationGeneration) {
      await _removePost(id);
    }
  }

  Future<void> _loadPage({required int page}) async {
    final context = await _contextFor(page: page);
    if (context == null) {
      state = AsyncData(SocialFeedState.fresh(_empty(page: page)));
      return;
    }
    final cached = await _readCached(context);
    if (cached != null) {
      state = AsyncData(
        SocialFeedState.cached(
          cached.result,
        ).copyWith(isStale: cached.isStale, clearRefreshError: true),
      );
      _scheduleBackgroundRefresh(context);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final result = await _fetchRemote(context);
        return SocialFeedState.fresh(result);
      } catch (error) {
        if (_isNetworkError(error)) {
          return SocialFeedState.offlineEmpty(
            page: context.page,
            size: _pageSize,
            sortBy: 'createdAt',
            sortDir: 'desc',
            filters: Map<String, dynamic>.from(_filters()),
          );
        }
        rethrow;
      }
    });
  }

  Future<PaginatedResponse<SocialPost>> _fetchRemote(
    _SocialPostRequestContext context,
  ) async {
    final cache = await ref.read(socialPageCacheProvider.future);
    final result = await cache.runDeduplicated<PaginatedResponse<SocialPost>>(
      context.cacheKey.requestKey,
      () {
        return ref
            .read(socialPostRepositoryProvider)
            .list(
              page: context.page,
              size: _pageSize,
              search: _search,
              community: _community,
              visibility: _visibility,
              mine: _mine,
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

  Future<_CachedSocialPosts?> _readCached(
    _SocialPostRequestContext context,
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
      return _CachedSocialPosts(
        result: _responseFromJson(entry.payload),
        isStale: entry.isStale(now, _freshTtl),
      );
    } catch (_) {
      await cache.remove(context.cacheKey);
      return null;
    }
  }

  void _scheduleBackgroundRefresh(_SocialPostRequestContext context) {
    Future.microtask(() async {
      if (!_isCurrent(context)) return;
      final current = state.asData?.value;
      if (current == null || current.isRefreshing) return;
      state = AsyncData(
        current.copyWith(isRefreshing: true, clearRefreshError: true),
      );
      try {
        final result = await _fetchRemote(context);
        if (!_isCurrent(context)) return;
        state = AsyncData(SocialFeedState.fresh(result));
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

  Future<void> _applyPostMutation(
    SocialPost post, {
    required _PostOperation operation,
  }) async {
    final value = state.asData?.value;
    if (value == null) {
      _scheduleMutationRevalidation();
      return;
    }
    var result = value.result;
    if (operation == _PostOperation.create) {
      if (result.page == 0 && _matchesCurrentFilters(post)) {
        final items = <SocialPost>[
          post,
          ...result.items.where((item) => item.id != post.id),
        ].take(result.size).toList();
        result = _withAdjustedTotals(
          result.copyWith(items: items),
          totalItems: result.totalItems + 1,
        );
      }
    } else {
      final items = <SocialPost>[];
      for (final item in result.items) {
        if (item.id == post.id) {
          if (_matchesCurrentFilters(post)) {
            items.add(post);
          }
        } else {
          items.add(item);
        }
      }
      final removed =
          result.items.any((item) => item.id == post.id) &&
          !items.any((item) => item.id == post.id);
      result = _withAdjustedTotals(
        result.copyWith(items: items),
        totalItems: result.totalItems - (removed ? 1 : 0),
      );
    }
    final next = SocialFeedState.fresh(result);
    state = AsyncData(next);
    await _invalidateOtherPostCachesAndPersist(next);
    _scheduleMutationRevalidation();
  }

  Future<void> _removePost(String id) async {
    final value = state.asData?.value;
    if (value == null) {
      _scheduleMutationRevalidation();
      return;
    }
    final items = value.result.items.where((item) => item.id != id).toList();
    final removedCount = value.result.items.length - items.length;
    final result = _withAdjustedTotals(
      value.result.copyWith(items: items),
      totalItems: value.result.totalItems - removedCount,
    );
    final next = SocialFeedState.fresh(result);
    state = AsyncData(next);
    await _invalidateOtherPostCachesAndPersist(next);
    _scheduleMutationRevalidation();
  }

  Future<void> _invalidateOtherPostCachesAndPersist(
    SocialFeedState next,
  ) async {
    final context = await _contextFor(page: next.result.page);
    if (context == null) return;
    final cache = await ref.read(socialPageCacheProvider.future);
    await cache.invalidate(
      resource: SocialPageCacheResource.posts,
      userId: context.userId,
    );
    await cache.write(
      key: context.cacheKey,
      payload: _responseToJson(next.result),
      nowUtc: DateTime.now().toUtc(),
    );
  }

  bool _matchesCurrentFilters(SocialPost post) {
    final search = _search?.toLowerCase();
    if (search != null && !post.content.toLowerCase().contains(search)) {
      return false;
    }
    if (_community != null && post.community.toLowerCase() != _community) {
      return false;
    }
    if (_visibility != null && post.visibility.toUpperCase() != _visibility) {
      return false;
    }
    final userId = ref.read(authControllerProvider).asData?.value?.userId;
    if (_mine == true && post.userId != userId) {
      return false;
    }
    return true;
  }

  PaginatedResponse<SocialPost> _withAdjustedTotals(
    PaginatedResponse<SocialPost> result, {
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

  Future<_SocialPostRequestContext?> _contextFor({required int page}) async {
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
    final filters = _filters();
    return _SocialPostRequestContext(
      userId: session.userId,
      generation: ref.read(authSessionGenerationProvider),
      locale: locale,
      page: page,
      requestRevision: _requestRevision,
      mutationGeneration: _mutationGeneration,
      cacheKey: cache.key(
        resource: SocialPageCacheResource.posts,
        socialBaseUrl: AppConfig.socialBaseUrl,
        endpoint: '/v1/posts',
        userId: session.userId,
        locale: locale,
        page: page,
        size: _pageSize,
        sortBy: 'createdAt',
        sortDir: 'desc',
        filters: filters,
      ),
    );
  }

  bool _isCurrent(_SocialPostRequestContext context) {
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
      'community': _community,
      'visibility': _visibility,
      'mine': _mine,
    };
  }

  PaginatedResponse<SocialPost> _empty({required int page}) {
    return PaginatedResponse.empty(
      page: page,
      size: _pageSize,
      sortBy: 'createdAt',
      sortDir: 'desc',
      filters: Map<String, dynamic>.from(_filters()),
    );
  }

  Map<String, dynamic> _responseToJson(PaginatedResponse<SocialPost> result) {
    return {
      'items': result.items
          .map((item) => SocialPostDto.fromEntity(item).toJson())
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

  PaginatedResponse<SocialPost> _responseFromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => SocialPostDto.fromJson(Map<String, dynamic>.from(item)))
        .map((item) => item.toEntity())
        .toList();
    return PaginatedResponse(
      items: items,
      page: (json['page'] as num? ?? 0).toInt(),
      size: (json['size'] as num? ?? _pageSize).toInt(),
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
    return text == null || text.isEmpty ? null : text;
  }

  bool _isNetworkError(Object error) {
    if (error is! DioException) {
      return false;
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => true,
      _ => false,
    };
  }
}

class _CachedSocialPosts {
  const _CachedSocialPosts({required this.result, required this.isStale});

  final PaginatedResponse<SocialPost> result;
  final bool isStale;
}

class _SocialPostRequestContext {
  const _SocialPostRequestContext({
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

enum _PostOperation { create, update }
