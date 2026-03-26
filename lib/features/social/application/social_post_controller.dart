import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/social/data/repositories/social_post_repository_impl.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/features/social/domain/repositories/social_post_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final socialPostRepositoryProvider = Provider<SocialPostRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.socialBaseUrl));
  return SocialPostRepositoryImpl(dio);
});

final socialPostControllerProvider =
    AsyncNotifierProvider<SocialPostController, List<SocialPost>>(SocialPostController.new);

class SocialPostController extends AsyncNotifier<List<SocialPost>> {
  @override
  Future<List<SocialPost>> build() async {
    return ref.watch(socialPostRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(socialPostRepositoryProvider).list();
    });
  }

  Future<void> create({
    required String content,
    required String community,
    required String visibility,
  }) async {
    final repository = ref.read(socialPostRepositoryProvider);
    final currentItems = state.asData?.value ?? const <SocialPost>[];

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final created = await repository.create(
        content: content,
        community: community,
        visibility: visibility,
      );

      return [created, ...currentItems];
    });
  }
}
