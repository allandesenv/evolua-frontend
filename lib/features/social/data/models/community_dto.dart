import 'package:evolua_frontend/features/social/domain/entities/community.dart';

class CommunityDto {
  const CommunityDto({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.visibility,
    required this.category,
    required this.memberCount,
    required this.joined,
    required this.createdAt,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final String visibility;
  final String category;
  final int memberCount;
  final bool joined;
  final DateTime createdAt;

  factory CommunityDto.fromJson(Map<String, dynamic> json) {
    return CommunityDto(
      id: json['id'].toString(),
      slug: json['slug'].toString(),
      name: json['name'].toString(),
      description: json['description'].toString(),
      visibility: json['visibility'].toString(),
      category: json['category'].toString(),
      memberCount: int.tryParse(json['memberCount'].toString()) ?? 0,
      joined: json['joined'] == true,
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  factory CommunityDto.fromEntity(Community community) {
    return CommunityDto(
      id: community.id,
      slug: community.slug,
      name: community.name,
      description: community.description,
      visibility: community.visibility,
      category: community.category,
      memberCount: community.memberCount,
      joined: community.joined,
      createdAt: community.createdAt,
    );
  }

  Community toEntity() {
    return Community(
      id: id,
      slug: slug,
      name: name,
      description: description,
      visibility: visibility,
      category: category,
      memberCount: memberCount,
      joined: joined,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'name': name,
      'description': description,
      'visibility': visibility,
      'category': category,
      'memberCount': memberCount,
      'joined': joined,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
