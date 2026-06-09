import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/social/data/repositories/social_post_repository_impl.dart';
import 'package:evolua_frontend/features/social/data/models/social_post_dto.dart';
import 'package:evolua_frontend/features/social/application/social_feed_state.dart';
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
  static const _legacyCachePrefix = 'evolua.social_feed_cache.v1';
  static const _cachePrefix = 'evolua.social_feed_cache.v2';
  String? _search;
  String? _community;
  String? _visibility;
  bool? _mine;

  static Future<void> clearOfflineCache(Ref ref) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await clearOfflineCacheFromPreferences(preferences);
  }

  static Future<void> clearOfflineCacheFromPreferences(
    SharedPreferences preferences,
  ) async {
    final keys = preferences
        .getKeys()
        .where(
          (key) =>
              key.startsWith(_legacyCachePrefix) ||
              key.startsWith(_cachePrefix),
        )
        .toList();
    for (final key in keys) {
      await preferences.remove(key);
    }
  }

  @override
  Future<SocialFeedState> build() async {
    return _fetch(page: 0);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async => _fetch(page: state.asData?.value.result.page ?? 0),
    );
  }

  Future<void> applyFilters({
    String? search,
    String? community,
    String? visibility,
    bool? mine,
  }) async {
    _search = search;
    _community = community;
    _visibility = visibility;
    _mine = mine;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: 0));
  }

  Future<void> goToPage(int page) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: page));
  }

  Future<SocialPost?> create({
    required String content,
    required String community,
    required String visibility,
  }) async {
    final repository = ref.read(socialPostRepositoryProvider);
    SocialPost? createdPost;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      createdPost = await repository.create(
        content: content,
        community: community,
        visibility: visibility,
      );

      return _fetch(page: 0);
    });
    return state.hasError ? null : createdPost;
  }

  Future<SocialPost> updatePost({
    required String id,
    required String content,
  }) async {
    final updatedPost = await ref
        .read(socialPostRepositoryProvider)
        .update(id: id, content: content);
    _replacePost(updatedPost);
    return updatedPost;
  }

  Future<void> deletePost(String id) async {
    await ref.read(socialPostRepositoryProvider).delete(id);
    _removePost(id);
  }

  Future<SocialFeedState> _fetch({required int page}) async {
    const sortBy = 'createdAt';
    const sortDir = 'desc';
    final filters = _filters();
    final userId =
        ref.read(authControllerProvider).asData?.value?.userId ?? 'anonymous';
    final key = _cacheKey(
      userId: userId,
      page: page,
      size: _pageSize,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: filters,
    );

    try {
      final result = await ref
          .read(socialPostRepositoryProvider)
          .list(
            page: page,
            size: _pageSize,
            search: _search,
            community: _community,
            visibility: _visibility,
            mine: _mine,
          );
      if (result.items.isNotEmpty) {
        await _writeCache(key, result);
      }
      return SocialFeedState.fresh(result);
    } catch (error) {
      if (!_isNetworkError(error)) {
        rethrow;
      }
      final cached = await _readCache(key);
      if (cached != null) {
        return SocialFeedState.cached(cached);
      }
      return SocialFeedState.offlineEmpty(
        page: page,
        size: _pageSize,
        sortBy: sortBy,
        sortDir: sortDir,
        filters: filters,
      );
    }
  }

  Map<String, dynamic> _filters() {
    return {
      if (_search != null && _search!.trim().isNotEmpty) 'search': _search,
      if (_community != null) 'community': _community,
      if (_visibility != null) 'visibility': _visibility,
      if (_mine != null) 'mine': _mine,
    };
  }

  String _cacheKey({
    required String userId,
    required int page,
    required int size,
    required String sortBy,
    required String sortDir,
    required Map<String, dynamic> filters,
  }) {
    final encoded = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'userId': userId,
          'page': page,
          'size': size,
          'sortBy': sortBy,
          'sortDir': sortDir,
          'filters': filters,
        }),
      ),
    );
    return '$_cachePrefix.$userId.$encoded';
  }

  Future<void> _writeCache(
    String key,
    PaginatedResponse<SocialPost> result,
  ) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setString(key, jsonEncode(_responseToJson(result)));
  }

  Future<PaginatedResponse<SocialPost>?> _readCache(String key) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final raw = preferences.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return _responseFromJson(decoded);
    } catch (_) {
      return null;
    }
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

  void _replacePost(SocialPost post) {
    final value = state.asData?.value;
    if (value == null) {
      return;
    }
    final items = value.result.items
        .map((item) => item.id == post.id ? post : item)
        .toList();
    state = AsyncData(SocialFeedState.fresh(value.result.copyWith(items: items)));
  }

  void _removePost(String id) {
    final value = state.asData?.value;
    if (value == null) {
      return;
    }
    final items = value.result.items.where((item) => item.id != id).toList();
    final removedCount = value.result.items.length - items.length;
    state = AsyncData(
      SocialFeedState.fresh(
        value.result.copyWith(
          items: items,
          totalItems: (value.result.totalItems - removedCount)
              .clamp(0, 1 << 31)
              .toInt(),
        ),
      ),
    );
  }
}
