class TrailMediaLink {
  const TrailMediaLink({
    required this.label,
    required this.url,
    required this.type,
  });

  final String label;
  final String url;
  final String type;

  bool get isYoutube => type == 'youtube';
}
