import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';

abstract class SocialPostRepository {
  Future<List<SocialPost>> list();

  Future<SocialPost> create({
    required String content,
    required String community,
    required String visibility,
  });
}
