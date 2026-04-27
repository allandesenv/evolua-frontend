import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';

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
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
  });

  Future<Trail?> currentJourney();

  Future<TrailJourney> journey(int trailId);

  Future<TrailJourney> startJourney(int trailId);

  Future<TrailJourney> completeStep(int trailId, int stepIndex);
}
