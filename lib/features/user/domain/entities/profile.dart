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
    this.personalGoals,
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
  final String? personalGoals;

  Profile copyWith({
    int? id,
    String? userId,
    String? displayName,
    String? bio,
    int? journeyLevel,
    bool? premium,
    DateTime? birthDate,
    String? gender,
    String? customGender,
    String? avatarUrl,
    DateTime? createdAt,
    String? personalGoals,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      journeyLevel: journeyLevel ?? this.journeyLevel,
      premium: premium ?? this.premium,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      customGender: customGender ?? this.customGender,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      personalGoals: personalGoals ?? this.personalGoals,
    );
  }
}
