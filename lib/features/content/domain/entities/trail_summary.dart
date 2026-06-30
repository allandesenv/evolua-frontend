import 'package:evolua_frontend/features/content/domain/entities/trail.dart';

class TrailSummary {
  const TrailSummary({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.premium,
    required this.privateTrail,
    required this.activeJourney,
    required this.generatedByAi,
    required this.stepCount,
    required this.estimatedDurationMinutes,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String summary;
  final String category;
  final bool premium;
  final bool privateTrail;
  final bool activeJourney;
  final bool generatedByAi;
  final int stepCount;
  final int estimatedDurationMinutes;
  final DateTime createdAt;

  bool get accessible => !premium;

  factory TrailSummary.fromTrail(Trail trail) {
    return TrailSummary(
      id: trail.id,
      title: trail.title,
      summary: trail.summary,
      category: trail.category,
      premium: trail.premium,
      privateTrail: trail.privateTrail,
      activeJourney: trail.activeJourney,
      generatedByAi: trail.generatedByAi,
      stepCount: trail.steps.length,
      estimatedDurationMinutes: trail.steps.fold<int>(
        0,
        (total, step) => total + step.durationMinutes,
      ),
      createdAt: trail.createdAt,
    );
  }
}
