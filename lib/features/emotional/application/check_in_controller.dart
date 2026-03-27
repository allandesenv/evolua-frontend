import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/emotional/data/repositories/check_in_repository_impl.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.emotionalBaseUrl));
  return CheckInRepositoryImpl(dio);
});

final checkInControllerProvider =
    AsyncNotifierProvider<CheckInController, PaginatedResponse<CheckIn>>(CheckInController.new);

class CheckInController extends AsyncNotifier<PaginatedResponse<CheckIn>> {
  static const _pageSize = 4;
  String? _search;
  String? _mood;

  @override
  Future<PaginatedResponse<CheckIn>> build() async {
    return _fetch(page: 0);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: state.asData?.value.page ?? 0));
  }

  Future<void> applyFilters({
    String? search,
    String? mood,
  }) async {
    _search = search;
    _mood = mood;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: 0));
  }

  Future<void> goToPage(int page) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: page));
  }

  Future<void> create({
    required String mood,
    required String reflection,
    required int energyLevel,
    required String recommendedPractice,
  }) async {
    final repository = ref.read(checkInRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.create(
        mood: mood,
        reflection: reflection,
        energyLevel: energyLevel,
        recommendedPractice: recommendedPractice,
      );

      return _fetch(page: 0);
    });
  }

  Future<PaginatedResponse<CheckIn>> _fetch({required int page}) {
    return ref.read(checkInRepositoryProvider).list(
          page: page,
          size: _pageSize,
          search: _search,
          mood: _mood,
        );
  }
}
