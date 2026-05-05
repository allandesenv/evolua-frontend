import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';

class CheckIn {
  const CheckIn({
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
}
