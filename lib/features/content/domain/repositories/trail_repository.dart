import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_response.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_summary.dart';

abstract class TrailRepository {
  Future<PaginatedResponse<TrailSummary>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? category,
    bool? premium,
  });

  Future<Trail> detail(int id) {
    throw UnimplementedError();
  }

  Future<Trail> create({
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  });

  Future<Trail> update({
    required int id,
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  });

  Future<void> delete(int id);

  Future<Trail?> currentJourney();

  Future<List<TrailJourney>> listInProgressJourneys();

  Future<TrailJourney> journey(int trailId);

  Future<TrailJourney> startJourney(int trailId);

  Future<TrailJourney> completeStep(int trailId, int stepIndex);

  Future<TrailJourney> updateVideoProgress({
    required int trailId,
    required int stepIndex,
    required int watchedSeconds,
    required int durationSeconds,
  });

  Future<TrailStepResponse?> stepResponse({
    required int trailId,
    required int stepIndex,
  });

  Future<TrailStepResponse> saveStepResponse({
    required int trailId,
    required int stepIndex,
    required String responseText,
  });

  Future<List<TrailStepResponse>> listStepResponses({int limit = 20});
}
