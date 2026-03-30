import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';

abstract class CommunityRepository {
  Future<PaginatedResponse<Community>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? visibility,
    String? category,
    bool? joined,
  });

  Future<Community> create({
    required String name,
    required String slug,
    required String description,
    required String visibility,
    required String category,
  });

  Future<Community> join(String id);

  Future<Community> leave(String id);
}
