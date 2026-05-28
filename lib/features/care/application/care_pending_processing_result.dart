class CarePendingProcessingResult {
  const CarePendingProcessingResult({
    required this.applied,
    required this.failed,
    required this.attempted,
  });

  const CarePendingProcessingResult.empty()
    : applied = false,
      failed = false,
      attempted = false;

  final bool applied;
  final bool failed;
  final bool attempted;

  bool get hasFailures => failed;

  CarePendingProcessingResult merge(CarePendingProcessingResult other) {
    return CarePendingProcessingResult(
      applied: applied || other.applied,
      failed: failed || other.failed,
      attempted: attempted || other.attempted,
    );
  }
}
