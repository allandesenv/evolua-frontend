class TrailProgress {
  const TrailProgress({
    required this.currentStepIndex,
    required this.completedStepIndexes,
    required this.startedAt,
    required this.updatedAt,
    required this.completedAt,
  });

  final int currentStepIndex;
  final List<int> completedStepIndexes;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;
}
