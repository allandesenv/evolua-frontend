import 'package:evolua_frontend/features/content/data/models/trail_dto.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_progress.dart';

class TrailJourneyDto {
  const TrailJourneyDto({
    required this.trail,
    required this.steps,
    required this.progress,
    required this.progressPercent,
    required this.nextStep,
  });

  final TrailDto trail;
  final List<TrailJourneyStep> steps;
  final TrailProgress? progress;
  final int progressPercent;
  final TrailJourneyStep? nextStep;

  factory TrailJourneyDto.fromJson(Map<String, dynamic> json) {
    return TrailJourneyDto(
      trail: TrailDto.fromJson(Map<String, dynamic>.from(json['trail'] as Map)),
      steps: (json['steps'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => _stepFromJson(Map<String, dynamic>.from(item)))
          .toList(),
      progress: json['progress'] is Map
          ? _progressFromJson(Map<String, dynamic>.from(json['progress'] as Map))
          : null,
      progressPercent: (json['progressPercent'] as num? ?? 0).toInt(),
      nextStep: json['nextStep'] is Map
          ? _stepFromJson(Map<String, dynamic>.from(json['nextStep'] as Map))
          : null,
    );
  }

  TrailJourney toEntity() {
    return TrailJourney(
      trail: trail.toEntity(),
      steps: steps,
      progress: progress,
      progressPercent: progressPercent,
      nextStep: nextStep,
    );
  }

  static TrailJourneyStep _stepFromJson(Map<String, dynamic> json) {
    return TrailJourneyStep(
      index: (json['index'] as num? ?? 0).toInt(),
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      status: json['status']?.toString() ?? 'upcoming',
      estimatedMinutes: (json['estimatedMinutes'] as num? ?? 5).toInt(),
      mediaLinks: (json['mediaLinks'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => TrailMediaLink(
              label: item['label'].toString(),
              url: item['url'].toString(),
              type: item['type'].toString(),
            ),
          )
          .toList(),
    );
  }

  static TrailProgress _progressFromJson(Map<String, dynamic> json) {
    return TrailProgress(
      currentStepIndex: (json['currentStepIndex'] as num? ?? 0).toInt(),
      completedStepIndexes: (json['completedStepIndexes'] as List? ?? const [])
          .whereType<num>()
          .map((item) => item.toInt())
          .toList(),
      startedAt: DateTime.parse(json['startedAt'].toString()),
      updatedAt: DateTime.parse(json['updatedAt'].toString()),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'].toString()),
    );
  }
}
