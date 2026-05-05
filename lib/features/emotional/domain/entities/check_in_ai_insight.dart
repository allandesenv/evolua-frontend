import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_generated_trail.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_journey_plan.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_suggested_space.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_suggested_action.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_suggested_trail.dart';

class CheckInAiInsight {
  const CheckInAiInsight({
    required this.insight,
    required this.suggestedAction,
    required this.riskLevel,
    required this.suggestedTrailId,
    required this.suggestedTrailTitle,
    required this.suggestedTrailReason,
    required this.suggestedSpace,
    required this.journeyPlan,
    required this.generatedTrailDraft,
    required this.fallbackUsed,
    this.quotaLimited = false,
    this.quotaRemainingToday = 0,
    this.rewardedAdAvailable = false,
    this.upgradeRecommended = false,
    this.limitMessage,
    this.emotionalStateLabel,
    this.shortInsight,
    this.nextStep,
    this.severityLevel,
    this.tags = const [],
    this.shouldSuggestAIChat = false,
    this.shouldSuggestHistoryAnalysis = false,
    this.suggestedTrailDetail,
    this.suggestedActionDetail,
  });

  final String insight;
  final String suggestedAction;
  final String riskLevel;
  final int? suggestedTrailId;
  final String? suggestedTrailTitle;
  final String suggestedTrailReason;
  final CheckInAiSuggestedSpace? suggestedSpace;
  final CheckInAiJourneyPlan? journeyPlan;
  final CheckInAiGeneratedTrail? generatedTrailDraft;
  final bool fallbackUsed;
  final bool quotaLimited;
  final int quotaRemainingToday;
  final bool rewardedAdAvailable;
  final bool upgradeRecommended;
  final String? limitMessage;
  final String? emotionalStateLabel;
  final String? shortInsight;
  final String? nextStep;
  final String? severityLevel;
  final List<String> tags;
  final bool shouldSuggestAIChat;
  final bool shouldSuggestHistoryAnalysis;
  final CheckInSuggestedTrail? suggestedTrailDetail;
  final CheckInSuggestedAction? suggestedActionDetail;
}
