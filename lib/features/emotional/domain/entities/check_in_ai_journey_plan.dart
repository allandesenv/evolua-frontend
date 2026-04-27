class CheckInAiJourneyPlan {
  const CheckInAiJourneyPlan({
    required this.journeyKey,
    required this.journeyTitle,
    required this.phaseLabel,
    required this.continuityMode,
    required this.summary,
    required this.nextCheckInPrompt,
  });

  final String journeyKey;
  final String journeyTitle;
  final String phaseLabel;
  final String continuityMode;
  final String summary;
  final String nextCheckInPrompt;
}
