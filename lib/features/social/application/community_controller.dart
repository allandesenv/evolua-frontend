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
    AsyncNotifierProvider<CommunityController, PaginatedResponse<Community>>(CommunityController.new);

class CommunityController extends AsyncNotifier<PaginatedResponse<Community>> {
  static const _pageSize = 8;
  String? _search;
  String? _visibility;
  String? _category;
  bool? _joined;

  @override
  Future<PaginatedResponse<Community>> build() async {
    return _fetch(page: 0);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: state.asData?.value.page ?? 0));
  }

  Future<void> applyFilters({
    String? search,
    String? visibility,
    String? category,
    bool? joined,
  }) async {
    _search = search;
    _visibility = visibility;
    _category = category;
    _joined = joined;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: 0));
  }

  Future<void> goToPage(int page) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: page));
  }

  Future<void> create({
    required String name,
    required String slug,
    required String description,
    required String visibility,
    required String category,
  }) async {
    final repository = ref.read(communityRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.create(
        name: name,
        slug: slug,
        description: description,
        visibility: visibility,
        category: category,
      );
      return _fetch(page: 0);
    });
  }

  Future<void> join(String id) async {
    final repository = ref.read(communityRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.join(id);
      return _fetch(page: state.asData?.value.page ?? 0);
    });
  }

  Future<void> leave(String id) async {
    final repository = ref.read(communityRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.leave(id);
      return _fetch(page: state.asData?.value.page ?? 0);
    });
  }

  Future<PaginatedResponse<Community>> _fetch({required int page}) {
    return ref.read(communityRepositoryProvider).list(
          page: page,
          size: _pageSize,
          search: _search,
          visibility: _visibility,
          category: _category,
          joined: _joined,
        );
  }
}
