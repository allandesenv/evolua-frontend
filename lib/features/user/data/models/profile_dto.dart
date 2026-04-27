import 'package:evolua_frontend/features/user/domain/entities/profile.dart';

class ProfileDto {
  const ProfileDto({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.journeyLevel,
    required this.premium,
    this.birthDate,
    this.gender,
    this.customGender,
    this.avatarUrl,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String displayName;
  final String bio;
  final int journeyLevel;
  final bool premium;
  final DateTime? birthDate;
  final String? gender;
  final String? customGender;
  final String? avatarUrl;
  final DateTime createdAt;

  factory ProfileDto.fromJson(Map<String, dynamic> json) {
    return ProfileDto(
      id: (json['id'] as num).toInt(),
      userId: json['userId'].toString(),
      displayName: json['displayName'].toString(),
      bio: (json['bio'] ?? '').toString(),
      journeyLevel: (json['journeyLevel'] as num).toInt(),
      premium: json['premium'] as bool,
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.tryParse(json['birthDate'].toString()),
      gender: json['gender']?.toString(),
      customGender: json['customGender']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  Profile toEntity() {
    return Profile(
      id: id,
      userId: userId,
      displayName: displayName,
      bio: bio,
      journeyLevel: journeyLevel,
      premium: premium,
      birthDate: birthDate,
      gender: gender,
      customGender: customGender,
      avatarUrl: avatarUrl,
      createdAt: createdAt,
    );
  }
}
