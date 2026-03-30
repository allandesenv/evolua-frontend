class Community {
  const Community({
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
}
