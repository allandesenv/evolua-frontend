import 'package:evolua_frontend/features/content/domain/entities/trail_step_response.dart';

class TrailStepResponseDto {
  const TrailStepResponseDto({
    required this.id,
    required this.trailId,
    this.journeyKey,
    required this.stepIndex,
    required this.stepTitle,
    required this.stepType,
    required this.responseText,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int trailId;
  final String? journeyKey;
  final int stepIndex;
  final String stepTitle;
  final String stepType;
  final String responseText;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TrailStepResponseDto.fromJson(Map<String, dynamic> json) {
    return TrailStepResponseDto(
      id: (json['id'] as num? ?? 0).toInt(),
      trailId: (json['trailId'] as num? ?? 0).toInt(),
      journeyKey: json['journeyKey']?.toString(),
      stepIndex: (json['stepIndex'] as num? ?? 0).toInt(),
      stepTitle: json['stepTitle']?.toString() ?? '',
      stepType: json['stepType']?.toString() ?? 'REFLECTION',
      responseText: json['responseText']?.toString() ?? '',
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: DateTime.parse(json['updatedAt'].toString()),
    );
  }

  TrailStepResponse toEntity() {
    return TrailStepResponse(
      id: id,
      trailId: trailId,
      journeyKey: journeyKey,
      stepIndex: stepIndex,
      stepTitle: stepTitle,
      stepType: stepType,
      responseText: responseText,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
