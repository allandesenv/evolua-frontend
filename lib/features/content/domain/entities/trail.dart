import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';

class Trail {
  const Trail({
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
}
