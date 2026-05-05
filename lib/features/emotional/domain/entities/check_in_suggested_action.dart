class CheckInSuggestedAction {
  const CheckInSuggestedAction({
    required this.type,
    required this.title,
    this.durationMinutes,
  });

  final String type;
  final String title;
  final int? durationMinutes;
}
