import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/social/data/repositories/social_post_repository_impl.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/features/social/domain/repositories/social_post_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final socialPostRepositoryProvider = Provider<SocialPostRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.socialBaseUrl));
  return SocialPostRepositoryImpl(dio);
});

final socialPostControllerProvider =
    AsyncNotifierProvider<SocialPostController, PaginatedResponse<SocialPost>>(SocialPostController.new);

class SocialPostController extends AsyncNotifier<PaginatedResponse<SocialPost>> {
  static const _pageSize = 4;
  String? _search;
  String? _community;
  String? _visibility;

  @override
  Future<PaginatedResponse<SocialPost>> build() async {
    return _fetch(page: 0);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: state.asData?.value.page ?? 0));
  }

  Future<void> applyFilters({
    String? search,
    String? community,
    String? visibility,
  }) async {
    _search = search;
    _community = community;
    _visibility = visibility;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: 0));
  }

  Future<void> goToPage(int page) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: page));
  }

  Future<void> create({
    required String content,
    required String community,
    required String visibility,
  }) async {
    final repository = ref.read(socialPostRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.create(
        content: content,
        community: community,
        visibility: visibility,
      );

      return _fetch(page: 0);
    });
  }

  Future<PaginatedResponse<SocialPost>> _fetch({required int page}) {
    return ref.read(socialPostRepositoryProvider).list(
          page: page,
          size: _pageSize,
          search: _search,
          community: _community,
          visibility: _visibility,
        );
  }
}
