import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';

class CheckInDto {
  const CheckInDto({
    required this.id,
    required this.userId,
    required this.mood,
    required this.reflection,
    required this.energyLevel,
    required this.recommendedPractice,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String mood;
  final String reflection;
  final int energyLevel;
  final String recommendedPractice;
  final DateTime createdAt;

  factory CheckInDto.fromJson(Map<String, dynamic> json) {
    return CheckInDto(
      id: (json['id'] as num).toInt(),
      userId: json['userId'].toString(),
      mood: json['mood'].toString(),
      reflection: json['reflection'].toString(),
      energyLevel: (json['energyLevel'] as num).toInt(),
      recommendedPractice: json['recommendedPractice'].toString(),
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
      createdAt: createdAt,
    );
  }
}
