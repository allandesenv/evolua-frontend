import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_generated_trail.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_generated_trail_link.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_journey_plan.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_suggested_space.dart';

class CheckInDto {
  const CheckInDto({
    required this.id,
    required this.userId,
    required this.mood,
    required this.reflection,
    required this.energyLevel,
    required this.recommendedPractice,
    required this.aiInsight,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String mood;
  final String reflection;
  final int energyLevel;
  final String recommendedPractice;
  final CheckInAiInsight? aiInsight;
  final DateTime createdAt;

  factory CheckInDto.fromJson(Map<String, dynamic> json) {
    return CheckInDto(
      id: (json['id'] as num).toInt(),
      userId: json['userId'].toString(),
      mood: json['mood'].toString(),
      reflection: json['reflection'].toString(),
      energyLevel: (json['energyLevel'] as num).toInt(),
      recommendedPractice: json['recommendedPractice'].toString(),
      aiInsight: _parseInsight(json['aiInsight']),
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  CheckIn toEntity() {
    return CheckIn(
      id: id,
      userId: userId,
      mood: mood,
      reflection: reflection,
      energyLevel: energyLevel,
      recommendedPractice: recommendedPractice,
      aiInsight: aiInsight,
      createdAt: createdAt,
    );
  }

  static CheckInAiInsight? _parseInsight(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return CheckInAiInsight(
      insight: value['insight']?.toString() ?? '',
      suggestedAction: value['suggestedAction']?.toString() ?? '',
      riskLevel: value['riskLevel']?.toString() ?? 'low',
      suggestedTrailId: (value['suggestedTrailId'] as num?)?.toInt(),
      suggestedTrailTitle: value['suggestedTrailTitle']?.toString(),
      suggestedTrailReason: value['suggestedTrailReason']?.toString() ?? '',
      suggestedSpace: _parseSuggestedSpace(value['suggestedSpace']),
      journeyPlan: _parseJourneyPlan(value['journeyPlan']),
      generatedTrailDraft: _parseGeneratedTrail(value['generatedTrailDraft']),
      fallbackUsed: value['fallbackUsed'] as bool? ?? false,
    );
  }

  static CheckInAiSuggestedSpace? _parseSuggestedSpace(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return CheckInAiSuggestedSpace(
      id: value['id']?.toString() ?? '',
      slug: value['slug']?.toString() ?? '',
      name: value['name']?.toString() ?? '',
      reason: value['reason']?.toString() ?? '',
    );
  }

  static CheckInAiJourneyPlan? _parseJourneyPlan(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return CheckInAiJourneyPlan(
      journeyKey: value['journeyKey']?.toString() ?? '',
      journeyTitle: value['journeyTitle']?.toString() ?? '',
      phaseLabel: value['phaseLabel']?.toString() ?? '',
      continuityMode: value['continuityMode']?.toString() ?? '',
      summary: value['summary']?.toString() ?? '',
      nextCheckInPrompt: value['nextCheckInPrompt']?.toString() ?? '',
    );
  }

  static CheckInAiGeneratedTrail? _parseGeneratedTrail(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return CheckInAiGeneratedTrail(
      title: value['title']?.toString() ?? '',
      summary: value['summary']?.toString() ?? '',
      content: value['content']?.toString() ?? '',
      category: value['category']?.toString() ?? '',
      sourceStyle: value['sourceStyle']?.toString() ?? '',
      mediaLinks: (value['mediaLinks'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => CheckInAiGeneratedTrailLink(
              label: item['label']?.toString() ?? '',
              url: item['url']?.toString() ?? '',
              type: item['type']?.toString() ?? '',
            ),
          )
          .toList(),
    );
  }
}
