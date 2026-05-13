class TrailStepVideoProgress {
  const TrailStepVideoProgress({
    required this.watchedSeconds,
    required this.durationSeconds,
    required this.watchedPercent,
    required this.completed,
    required this.updatedAt,
  });

  final int watchedSeconds;
  final int durationSeconds;
  final int watchedPercent;
  final bool completed;
  final DateTime updatedAt;
}
