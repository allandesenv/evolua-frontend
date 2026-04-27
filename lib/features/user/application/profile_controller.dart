import 'dart:typed_data';

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
    AsyncNotifierProvider<ProfileController, Profile?>(ProfileController.new);

final currentProfileProvider = Provider<Profile?>((ref) {
  return ref.watch(profileControllerProvider).asData?.value;
});

class ProfileController extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final repository = ref.watch(profileRepositoryProvider);
    return repository.getMe();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(profileRepositoryProvider).getMe();
    });
  }

  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  }) async {
    final repository = ref.read(profileRepositoryProvider);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return repository.upsertMe(
        displayName: displayName,
        birthDate: birthDate,
        gender: gender,
        customGender: customGender,
        bio: bio,
        journeyLevel: journeyLevel,
      );
    });

    return state.requireValue!;
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final repository = ref.read(profileRepositoryProvider);
    final avatarUrl = await repository.uploadAvatar(
      bytes: bytes,
      fileName: fileName,
    );
    await refresh();
    return avatarUrl;
  }
}
