import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';

class DailyRitualDto {
  const DailyRitualDto({
    required this.id,
    required this.localDate,
    required this.type,
    required this.emotionalState,
    required this.dayNeed,
    required this.intention,
    required this.microAction,
    required this.createdAt,
  });

  final int id;
  final DateTime localDate;
  final String type;
  final String emotionalState;
  final String dayNeed;
  final String intention;
  final String microAction;
  final DateTime createdAt;

  factory DailyRitualDto.fromJson(Map<String, dynamic> json) {
    return DailyRitualDto(
      id: (json['id'] as num).toInt(),
      localDate: DateTime.parse(json['localDate'].toString()),
      type: json['type']?.toString() ?? DailyRitualType.morning,
      emotionalState: json['emotionalState']?.toString() ?? '',
      dayNeed: json['dayNeed']?.toString() ?? '',
      intention: json['intention']?.toString() ?? '',
      microAction: json['microAction']?.toString() ?? '',
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  DailyRitual toEntity() {
    return DailyRitual(
      id: id,
      localDate: localDate,
      type: type,
      emotionalState: emotionalState,
      dayNeed: dayNeed,
      intention: intention,
      microAction: microAction,
      createdAt: createdAt,
    );
  }
}
