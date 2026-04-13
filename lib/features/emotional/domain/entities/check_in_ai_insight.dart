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
}
