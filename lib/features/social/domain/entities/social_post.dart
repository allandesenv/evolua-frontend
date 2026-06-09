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

  SocialPost copyWith({
    String? id,
    String? userId,
    String? content,
    String? community,
    String? visibility,
    DateTime? createdAt,
  }) {
    return SocialPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      community: community ?? this.community,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
