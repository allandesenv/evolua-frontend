import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';

abstract class CheckInRepository {
  Future<PaginatedResponse<CheckIn>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? mood,
  });

  Future<CheckIn> create({
    required String mood,
    required String reflection,
    required int energyLevel,
    required String recommendedPractice,
  });
}
