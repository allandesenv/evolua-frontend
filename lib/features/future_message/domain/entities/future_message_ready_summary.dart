class FutureMessageReadySummary {
  const FutureMessageReadySummary({
    required this.hasReady,
    required this.firstMessageId,
  });

  const FutureMessageReadySummary.empty()
    : hasReady = false,
      firstMessageId = null;

  final bool hasReady;
  final int? firstMessageId;

  factory FutureMessageReadySummary.fromJson(Map<String, dynamic> json) {
    final firstMessageId = (json['firstMessageId'] as num?)?.toInt();
    return FutureMessageReadySummary(
      hasReady: json['hasReady'] == true && firstMessageId != null,
      firstMessageId: firstMessageId,
    );
  }
}
