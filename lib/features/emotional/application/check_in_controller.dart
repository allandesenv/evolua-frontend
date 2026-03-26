import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/emotional/data/repositories/check_in_repository_impl.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.emotionalBaseUrl));
  return CheckInRepositoryImpl(dio);
});

final checkInControllerProvider =
    AsyncNotifierProvider<CheckInController, List<CheckIn>>(CheckInController.new);

class CheckInController extends AsyncNotifier<List<CheckIn>> {
  @override
  Future<List<CheckIn>> build() async {
    return ref.watch(checkInRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(checkInRepositoryProvider).list();
    });
  }

  Future<void> create({
    required String mood,
    required String reflection,
    required int energyLevel,
    required String recommendedPractice,
  }) async {
    final repository = ref.read(checkInRepositoryProvider);
    final currentItems = state.asData?.value ?? const <CheckIn>[];

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final created = await repository.create(
        mood: mood,
        reflection: reflection,
        energyLevel: energyLevel,
        recommendedPractice: recommendedPractice,
      );

      return [created, ...currentItems];
    });
  }
}
