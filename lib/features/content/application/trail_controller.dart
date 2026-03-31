import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/content/data/repositories/trail_repository_impl.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trailRepositoryProvider = Provider<TrailRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.contentBaseUrl));
  return TrailRepositoryImpl(dio);
});

final trailControllerProvider =
    AsyncNotifierProvider<TrailController, PaginatedResponse<Trail>>(TrailController.new);

class TrailController extends AsyncNotifier<PaginatedResponse<Trail>> {
  static const _pageSize = 4;
  String? _search;
  bool? _premium;
  String? _category;

  @override
  Future<PaginatedResponse<Trail>> build() async {
    return _fetch(page: 0);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: state.asData?.value.page ?? 0));
  }

  Future<void> applyFilters({
    String? search,
    bool? premium,
    String? category,
  }) async {
    _search = search;
    _premium = premium;
    _category = category;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: 0));
  }

  Future<void> goToPage(int page) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: page));
  }

  Future<void> create({
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
  }) async {
    final repository = ref.read(trailRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.create(
        title: title,
        summary: summary,
        content: content,
        category: category,
        premium: premium,
        mediaLinks: mediaLinks,
      );

      return _fetch(page: 0);
    });
  }

  Future<PaginatedResponse<Trail>> _fetch({required int page}) {
    return ref.read(trailRepositoryProvider).list(
          page: page,
          size: _pageSize,
          search: _search,
          premium: _premium,
          category: _category,
        );
  }
}
