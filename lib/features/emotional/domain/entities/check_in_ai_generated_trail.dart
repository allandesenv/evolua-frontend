import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_generated_trail_link.dart';

class CheckInAiGeneratedTrail {
  const CheckInAiGeneratedTrail({
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    required this.sourceStyle,
    required this.mediaLinks,
  });

  final String title;
  final String summary;
  final String content;
  final String category;
  final String sourceStyle;
  final List<CheckInAiGeneratedTrailLink> mediaLinks;
}
