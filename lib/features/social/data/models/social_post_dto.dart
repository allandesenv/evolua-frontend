import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';

class SocialPostDto {
  const SocialPostDto({
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

  factory SocialPostDto.fromJson(Map<String, dynamic> json) {
    return SocialPostDto(
      id: json['id'].toString(),
      userId: json['userId'].toString(),
      content: json['content'].toString(),
      community: json['community'].toString(),
      visibility: json['visibility'].toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  SocialPost toEntity() {
    return SocialPost(
      id: id,
      userId: userId,
      content: content,
      community: community,
      visibility: visibility,
      createdAt: createdAt,
    );
  }
}
