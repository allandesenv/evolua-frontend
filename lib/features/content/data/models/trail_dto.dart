import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_video.dart';

class TrailDto {
  const TrailDto({
    required this.id,
    required this.userId,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    required this.premium,
    required this.privateTrail,
    required this.activeJourney,
    required this.generatedByAi,
    required this.journeyKey,
    required this.sourceStyle,
    required this.accessible,
    required this.mediaLinks,
    required this.steps,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String title;
  final String summary;
  final String? content;
  final String category;
  final bool premium;
  final bool privateTrail;
  final bool activeJourney;
  final bool generatedByAi;
  final String? journeyKey;
  final String? sourceStyle;
  final bool accessible;
  final List<TrailMediaLink> mediaLinks;
  final List<TrailStep> steps;
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
      privateTrail: json['privateTrail'] as bool? ?? false,
      activeJourney: json['activeJourney'] as bool? ?? false,
      generatedByAi: json['generatedByAi'] as bool? ?? false,
      journeyKey: json['journeyKey']?.toString(),
      sourceStyle: json['sourceStyle']?.toString(),
      accessible:
          json['accessible'] as bool? ?? !(json['premium'] as bool? ?? false),
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
      steps: (json['steps'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => _stepFromJson(Map<String, dynamic>.from(item)))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  static TrailStep _stepFromJson(Map<String, dynamic> json) {
    return TrailStep(
      position: (json['position'] as num? ?? 0).toInt(),
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'REFLECTION',
      summary: json['summary']?.toString() ?? '',
      durationMinutes: (json['durationMinutes'] as num? ?? 5).toInt(),
      content: json['content']?.toString() ?? '',
      video: _videoFromJson(json),
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

  static TrailStepVideo? _videoFromJson(Map<String, dynamic> json) {
    final provider = json['videoProvider']?.toString();
    if (provider == null || provider.isEmpty) {
      return null;
    }
    return TrailStepVideo(
      provider: provider,
      videoId: json['videoId']?.toString(),
      url: json['videoUrl']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
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
      privateTrail: privateTrail,
      activeJourney: activeJourney,
      generatedByAi: generatedByAi,
      journeyKey: journeyKey,
      sourceStyle: sourceStyle,
      accessible: accessible,
      mediaLinks: mediaLinks,
      steps: steps,
      createdAt: createdAt,
    );
  }
}
