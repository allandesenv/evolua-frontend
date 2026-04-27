import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';

abstract class SocialPostRepository {
  Future<PaginatedResponse<SocialPost>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? community,
    String? visibility,
    bool? mine,
  });

  Future<SocialPost> create({
    required String content,
    required String community,
    required String visibility,
  });
}
