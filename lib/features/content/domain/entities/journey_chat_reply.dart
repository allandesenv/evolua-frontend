class JourneyChatReply {
  const JourneyChatReply({
    required this.reply,
    required this.riskLevel,
    required this.suggestedNextStep,
    required this.fallbackUsed,
  });

  final String reply;
  final String riskLevel;
  final String suggestedNextStep;
  final bool fallbackUsed;

  factory JourneyChatReply.fromJson(Map<String, dynamic> json) {
    return JourneyChatReply(
      reply: json['reply']?.toString() ?? '',
      riskLevel: json['riskLevel']?.toString() ?? 'low',
      suggestedNextStep: json['suggestedNextStep']?.toString() ?? '',
      fallbackUsed: json['fallbackUsed'] as bool? ?? false,
    );
  }
}
