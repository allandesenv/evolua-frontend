import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';

class TrailDto {
  const TrailDto({
    required this.id,
    required this.userId,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    required this.premium,
    required this.accessible,
    required this.mediaLinks,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String title;
  final String summary;
  final String? content;
  final String category;
  final bool premium;
  final bool accessible;
  final List<TrailMediaLink> mediaLinks;
  final DateTime createdAt;

  factory TrailDto.fromJson(Map<String, dynamic> json) {
    return TrailDto(
      id: (json['id'] as num).toInt(),
      userId: json['userId'].toString(),
      title: json['title'].toString(),
      summary: (json['summary'] ?? json['description']).toString(),
      content: json['content']?.toString(),
      category: json['category'].toString(),
      premium: json['premium'] as bool,
      accessible: json['accessible'] as bool? ?? !(json['premium'] as bool? ?? false),
      mediaLinks: (json['mediaLinks'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => TrailMediaLink(label: item['label'].toString(), url: item['url'].toString(), type: item['type'].toString()))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  Trail toEntity() {
    return Trail(
      id: id,
      userId: userId,
      title: title,
      summary: summary,
      content: content,
      category: category,
      premium: premium,
      accessible: accessible,
      mediaLinks: mediaLinks,
      createdAt: createdAt,
    );
  }
}
