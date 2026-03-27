import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';

abstract class TrailRepository {
  Future<PaginatedResponse<Trail>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? category,
    bool? premium,
  });

  Future<Trail> create({
    required String title,
    required String description,
    required String category,
    required bool premium,
  });
}
