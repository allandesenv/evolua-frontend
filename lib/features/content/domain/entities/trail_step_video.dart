class TrailStepVideo {
  const TrailStepVideo({
    required this.provider,
    required this.videoId,
    required this.url,
    required this.thumbnailUrl,
    required this.durationSeconds,
  });

  final String provider;
  final String? videoId;
  final String? url;
  final String? thumbnailUrl;
  final int? durationSeconds;

  bool get isYoutube => provider.toUpperCase() == 'YOUTUBE';
}
