class JourneyChatReply {
  const JourneyChatReply({
    required this.reply,
    required this.riskLevel,
    required this.suggestedNextStep,
    required this.fallbackUsed,
    this.quotaLimited = false,
    this.quotaRemainingToday = 0,
    this.rewardedAdAvailable = false,
    this.upgradeRecommended = false,
    this.limitMessage,
  });

  final String reply;
  final String riskLevel;
  final String suggestedNextStep;
  final bool fallbackUsed;
  final bool quotaLimited;
  final int quotaRemainingToday;
  final bool rewardedAdAvailable;
  final bool upgradeRecommended;
  final String? limitMessage;

  factory JourneyChatReply.fromJson(Map<String, dynamic> json) {
    return JourneyChatReply(
      reply: json['reply']?.toString() ?? '',
      riskLevel: json['riskLevel']?.toString() ?? 'low',
      suggestedNextStep: json['suggestedNextStep']?.toString() ?? '',
      fallbackUsed: json['fallbackUsed'] as bool? ?? false,
      quotaLimited: json['quotaLimited'] as bool? ?? false,
      quotaRemainingToday: (json['quotaRemainingToday'] as num?)?.toInt() ?? 0,
      rewardedAdAvailable: json['rewardedAdAvailable'] as bool? ?? false,
      upgradeRecommended: json['upgradeRecommended'] as bool? ?? false,
      limitMessage: json['limitMessage']?.toString(),
    );
  }
}
