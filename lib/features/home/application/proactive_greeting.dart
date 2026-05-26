import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_day.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';

enum ProactiveGreetingAction { checkIn, continueJourney, evolutionMirror }

class ProactiveGreeting {
  const ProactiveGreeting({
    required this.greeting,
    required this.message,
    required this.action,
    required this.actionLabel,
  });

  final String greeting;
  final String message;
  final ProactiveGreetingAction action;
  final String actionLabel;
}

ProactiveGreeting buildProactiveGreeting({
  required String? displayName,
  required List<CheckIn> checkIns,
  required CheckIn? latestCreatedCheckIn,
  required Trail? activeJourney,
  required bool mentorPremiumPassActive,
  DateTime? mentorPremiumPassEndsAt,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final name = _firstName(displayName);
  final greeting =
      '${_periodGreeting(current)}${name == null ? '' : ', $name'}';
  final hasToday = hasCheckInToday(
    checkIns,
    latestCreatedCheckIn: latestCreatedCheckIn,
    now: current,
  );

  if (!hasToday) {
    final base = checkIns.isEmpty
        ? 'Que bom te ver por aqui. Um check-in curto ajuda o Evolua a entender seu momento de hoje.'
        : 'Antes de seguir, vale registrar como voce esta hoje para ajustar a trilha ao seu momento real.';
    return ProactiveGreeting(
      greeting: greeting,
      message: base,
      action: ProactiveGreetingAction.checkIn,
      actionLabel: 'Fazer check-in',
    );
  }

  if (activeJourney != null) {
    final mood = _dominantMood(checkIns);
    final prefix = mood == null
        ? 'Sua trilha esta pronta para o proximo passo.'
        : 'Seu historico recente aponta mais $mood.';
    final passNote = mentorPremiumPassActive
        ? ' Seu passe de mentoria esta ativo hoje.'
        : '';
    return ProactiveGreeting(
      greeting: greeting,
      message:
          '$prefix Continue ${activeJourney.title} com um passo pequeno e possivel.$passNote',
      action: ProactiveGreetingAction.continueJourney,
      actionLabel: 'Continuar trilha',
    );
  }

  final averageEnergy = _averageEnergy(checkIns);
  final energyMessage = averageEnergy == null
      ? 'Seu espelho ainda esta se formando. Alguns registros ja ajudam a revelar padroes com mais clareza.'
      : averageEnergy < 6
      ? 'Sua energia recente pede gentileza. Escolha uma acao menor e use o Espelho para perceber o ritmo sem cobranca.'
      : 'Sua energia recente esta sustentando movimento. O Espelho pode mostrar o que vem funcionando melhor.';
  return ProactiveGreeting(
    greeting: greeting,
    message: energyMessage,
    action: ProactiveGreetingAction.evolutionMirror,
    actionLabel: 'Abrir Espelho',
  );
}

String _periodGreeting(DateTime now) {
  final hour = now.toLocal().hour;
  if (hour < 12) {
    return 'Bom dia';
  }
  if (hour < 18) {
    return 'Boa tarde';
  }
  return 'Boa noite';
}

String? _firstName(String? displayName) {
  final normalized = displayName?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized.split(RegExp(r'\s+')).first;
}

String? _dominantMood(List<CheckIn> checkIns) {
  if (checkIns.isEmpty) {
    return null;
  }
  final counts = <String, int>{};
  for (final item in checkIns.take(5)) {
    final mood = item.mood.trim().toLowerCase();
    if (mood.isNotEmpty) {
      counts[mood] = (counts[mood] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) {
    return null;
  }
  final entry = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return entry.key;
}

double? _averageEnergy(List<CheckIn> checkIns) {
  if (checkIns.isEmpty) {
    return null;
  }
  final recent = checkIns.take(5).toList();
  return recent.map((item) => item.energyLevel).reduce((a, b) => a + b) /
      recent.length;
}
