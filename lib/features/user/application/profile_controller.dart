import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/user/data/repositories/profile_repository_impl.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.userBaseUrl));
  return ProfileRepositoryImpl(dio);
});

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, List<Profile>>(ProfileController.new);

class ProfileController extends AsyncNotifier<List<Profile>> {
  @override
  Future<List<Profile>> build() async {
    final repository = ref.watch(profileRepositoryProvider);
    return repository.list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(profileRepositoryProvider).list();
    });
  }

  Future<void> create({
    required String displayName,
    required String bio,
    required int journeyLevel,
    required bool premium,
  }) async {
    final repository = ref.read(profileRepositoryProvider);
    final currentItems = state.asData?.value ?? const <Profile>[];

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final created = await repository.create(
        displayName: displayName,
        bio: bio,
        journeyLevel: journeyLevel,
        premium: premium,
      );

      return [created, ...currentItems];
    });
  }
}
