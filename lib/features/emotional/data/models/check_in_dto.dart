import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';

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
      fallbackUsed: value['fallbackUsed'] as bool? ?? false,
    );
  }
}
