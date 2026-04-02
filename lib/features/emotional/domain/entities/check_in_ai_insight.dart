class CheckInAiInsight {
  const CheckInAiInsight({
    required this.insight,
    required this.suggestedAction,
    required this.riskLevel,
    required this.suggestedTrailId,
    required this.suggestedTrailTitle,
    required this.suggestedTrailReason,
    required this.fallbackUsed,
  });

  final String insight;
  final String suggestedAction;
  final String riskLevel;
  final int? suggestedTrailId;
  final String? suggestedTrailTitle;
  final String suggestedTrailReason;
  final bool fallbackUsed;
}
