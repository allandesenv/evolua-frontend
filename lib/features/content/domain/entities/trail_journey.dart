import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_progress.dart';

class TrailJourney {
  const TrailJourney({
    required this.trail,
    required this.steps,
    required this.progress,
    required this.progressPercent,
    required this.nextStep,
  });

  final Trail trail;
  final List<TrailJourneyStep> steps;
  final TrailProgress? progress;
  final int progressPercent;
  final TrailJourneyStep? nextStep;

  int get completedSteps => steps.where((step) => step.isCompleted).length;
  bool get isStarted => progress != null;
  bool get isCompleted => progress?.isCompleted ?? false;
}
