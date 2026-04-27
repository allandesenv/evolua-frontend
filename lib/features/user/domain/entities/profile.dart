class Profile {
  const Profile({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.journeyLevel,
    required this.premium,
    required this.birthDate,
    required this.gender,
    required this.customGender,
    required this.avatarUrl,
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
}
