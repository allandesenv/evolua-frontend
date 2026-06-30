import 'package:evolua_frontend/features/content/domain/entities/trail_summary.dart';

class TrailSummaryDto {
  const TrailSummaryDto({
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

  factory TrailSummaryDto.fromJson(Map<String, dynamic> json) {
    return TrailSummaryDto(
      id: (json['id'] as num).toInt(),
      title: json['title'].toString(),
      summary: (json['summary'] ?? json['description']).toString(),
      category: json['category'].toString(),
      premium: json['premium'] as bool? ?? false,
      privateTrail: json['privateTrail'] as bool? ?? false,
      activeJourney: json['activeJourney'] as bool? ?? false,
      generatedByAi: json['generatedByAi'] as bool? ?? false,
      stepCount: (json['stepCount'] as num? ?? 0).toInt(),
      estimatedDurationMinutes: (json['estimatedDurationMinutes'] as num? ?? 0)
          .toInt(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'category': category,
      'premium': premium,
      'privateTrail': privateTrail,
      'activeJourney': activeJourney,
      'generatedByAi': generatedByAi,
      'stepCount': stepCount,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  TrailSummary toEntity() {
    return TrailSummary(
      id: id,
      title: title,
      summary: summary,
      category: category,
      premium: premium,
      privateTrail: privateTrail,
      activeJourney: activeJourney,
      generatedByAi: generatedByAi,
      stepCount: stepCount,
      estimatedDurationMinutes: estimatedDurationMinutes,
      createdAt: createdAt,
    );
  }

  static TrailSummaryDto fromEntity(TrailSummary entity) {
    return TrailSummaryDto(
      id: entity.id,
      title: entity.title,
      summary: entity.summary,
      category: entity.category,
      premium: entity.premium,
      privateTrail: entity.privateTrail,
      activeJourney: entity.activeJourney,
      generatedByAi: entity.generatedByAi,
      stepCount: entity.stepCount,
      estimatedDurationMinutes: entity.estimatedDurationMinutes,
      createdAt: entity.createdAt,
    );
  }
}
