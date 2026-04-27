import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';

class TrailJourneyStep {
  const TrailJourneyStep({
    required this.index,
    required this.title,
    required this.summary,
    required this.content,
    required this.status,
    required this.estimatedMinutes,
    required this.mediaLinks,
  });

  final int index;
  final String title;
  final String summary;
  final String content;
  final String status;
  final int estimatedMinutes;
  final List<TrailMediaLink> mediaLinks;

  bool get isCompleted => status == 'completed';
  bool get isCurrent => status == 'current';
}
