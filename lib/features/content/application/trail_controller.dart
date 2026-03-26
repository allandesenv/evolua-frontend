import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/content/data/repositories/trail_repository_impl.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trailRepositoryProvider = Provider<TrailRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.contentBaseUrl));
  return TrailRepositoryImpl(dio);
});

final trailControllerProvider =
    AsyncNotifierProvider<TrailController, List<Trail>>(TrailController.new);

class TrailController extends AsyncNotifier<List<Trail>> {
  @override
  Future<List<Trail>> build() async {
    return ref.watch(trailRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(trailRepositoryProvider).list();
    });
  }

  Future<void> create({
    required String title,
    required String description,
    required String category,
    required bool premium,
  }) async {
    final repository = ref.read(trailRepositoryProvider);
    final currentItems = state.asData?.value ?? const <Trail>[];

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final created = await repository.create(
        title: title,
        description: description,
        category: category,
        premium: premium,
      );

      return [created, ...currentItems];
    });
  }
}
