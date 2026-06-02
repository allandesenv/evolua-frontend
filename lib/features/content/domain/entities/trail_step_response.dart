class TrailStepResponse {
  const TrailStepResponse({
    required this.id,
    required this.trailId,
    this.journeyKey,
    required this.stepIndex,
    required this.stepTitle,
    required this.stepType,
    required this.responseText,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int trailId;
  final String? journeyKey;
  final int stepIndex;
  final String stepTitle;
  final String stepType;
  final String responseText;
  final DateTime createdAt;
  final DateTime updatedAt;
}
