class Trail {
  const Trail({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.premium,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final bool premium;
  final DateTime createdAt;
}
