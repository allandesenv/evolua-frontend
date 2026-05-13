import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_video.dart';

class TrailStep {
  const TrailStep({
    required this.position,
    required this.title,
    required this.type,
    required this.summary,
    required this.durationMinutes,
    required this.content,
    this.video,
    required this.mediaLinks,
  });

  final int position;
  final String title;
  final String type;
  final String summary;
  final int durationMinutes;
  final String content;
  final TrailStepVideo? video;
  final List<TrailMediaLink> mediaLinks;
}
