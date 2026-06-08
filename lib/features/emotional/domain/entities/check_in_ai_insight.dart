import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_generated_trail.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_journey_plan.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_suggested_space.dart';

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
    this.contextSignals = const [],
    this.readingDepth,
    this.responseFingerprint,
    this.usedContextSummary,
    this.nextStep,
    this.title,
    this.surface,
    this.behind,
    this.identifiedState,
    this.revealingQuestion,
    this.possibleNewState,
    this.microAction,
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
  final List<String> contextSignals;
  final String? readingDepth;
  final String? responseFingerprint;
  final String? usedContextSummary;
  final CheckInAiNextStep? nextStep;
  final String? title;
  final String? surface;
  final String? behind;
  final String? identifiedState;
  final String? revealingQuestion;
  final String? possibleNewState;
  final String? microAction;
}

class CheckInAiNextStep {
  const CheckInAiNextStep({
    required this.type,
    required this.label,
    this.target,
  });

  final String type;
  final String label;
  final String? target;
}
