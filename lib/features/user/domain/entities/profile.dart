class Profile {
  const Profile({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.journeyLevel,
    required this.premium,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String displayName;
  final String bio;
  final int journeyLevel;
  final bool premium;
  final DateTime createdAt;
}
