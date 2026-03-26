class SocialPost {
  const SocialPost({
    required this.id,
    required this.userId,
    required this.content,
    required this.community,
    required this.visibility,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String content;
  final String community;
  final String visibility;
  final DateTime createdAt;
}
