import 'package:evolua_frontend/features/emotional/data/models/check_in_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses deterministic check-in insight fields and legacy fields', () {
    final checkIn = CheckInDto.fromJson({
      'id': 1,
      'userId': 'user-123',
      'mood': 'ansioso',
      'reflection': 'muita coisa',
      'energyLevel': 9,
      'recommendedPractice': 'Escolha uma prioridade.',
      'emotion': 'ansioso',
      'intensity': 8,
      'energy': 'alta',
      'context': 'trabalho',
      'decisionTags': 'ansiedade,energia-alta',
      'severityLevel': 'medium',
      'createdAt': '2026-01-01T12:00:00Z',
      'aiInsight': {
        'insight': 'Sua mente parece estar tentando resolver muitas coisas.',
        'suggestedAction': 'Escolha uma prioridade.',
        'riskLevel': 'medium',
        'suggestedTrailId': null,
        'suggestedTrailTitle': 'Desacelerar e organizar',
        'suggestedTrailReason': 'Apoia seu proximo passo.',
        'suggestedSpace': null,
        'journeyPlan': null,
        'generatedTrailDraft': null,
        'fallbackUsed': false,
        'quotaLimited': false,
        'emotionalStateLabel': 'mente acelerada',
        'shortInsight':
            'Sua mente parece estar tentando resolver muitas coisas ao mesmo tempo.',
        'nextStep': 'Escolha uma unica prioridade para os proximos 10 minutos.',
        'severityLevel': 'medium',
        'tags': ['ansiedade', 'energia-alta'],
        'shouldSuggestAIChat': true,
        'shouldSuggestHistoryAnalysis': false,
        'suggestedTrailDetail': {
          'id': 'desacelerar-organizar',
          'title': 'Desacelerar e organizar',
        },
        'suggestedActionDetail': {
          'type': 'breathing_or_priority',
          'title': 'Respire e escolha uma prioridade',
          'durationMinutes': 3,
        },
      },
    }).toEntity();

    expect(checkIn.emotion, 'ansioso');
    expect(checkIn.intensity, 8);
    expect(checkIn.aiInsight?.emotionalStateLabel, 'mente acelerada');
    expect(checkIn.aiInsight?.shouldSuggestAIChat, isTrue);
    expect(checkIn.aiInsight?.suggestedTrailDetail?.id, 'desacelerar-organizar');
    expect(checkIn.aiInsight?.suggestedActionDetail?.durationMinutes, 3);
  });
}
