import 'package:evolua_frontend/features/content/domain/entities/trail.dart';

class TrailDto {
  const TrailDto({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.premium,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final bool premium;
  final DateTime createdAt;

  factory TrailDto.fromJson(Map<String, dynamic> json) {
    return TrailDto(
      id: (json['id'] as num).toInt(),
      userId: json['userId'].toString(),
      title: json['title'].toString(),
      description: json['description'].toString(),
      category: json['category'].toString(),
      premium: json['premium'] as bool,
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  Trail toEntity() {
    return Trail(
      id: id,
      userId: userId,
      title: title,
      description: description,
      category: category,
      premium: premium,
      createdAt: createdAt,
    );
  }
}
