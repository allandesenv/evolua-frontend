import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/presentation/widgets/check_in_ai_insight_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows rewarded ad and premium actions when check-in quota ends', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckInAiInsightCard(
            insight: const CheckInAiInsight(
              insight: 'Salvamos seu check-in com uma orientacao segura.',
              suggestedAction: 'Respire por dois minutos.',
              riskLevel: 'low',
              suggestedTrailId: null,
              suggestedTrailTitle: null,
              suggestedTrailReason: '',
              suggestedSpace: null,
              journeyPlan: null,
              generatedTrailDraft: null,
              fallbackUsed: true,
              quotaLimited: true,
              rewardedAdAvailable: true,
              upgradeRecommended: true,
              limitMessage:
                  'Sua jornada já está salva. O limite gratuito de IA acabou por hoje. Você pode voltar amanhã, assistir a um anúncio para liberar +1 análise ou assinar Premium.',
            ),
            onWatchRewardedAd: () {},
            onOpenPremium: () {},
          ),
        ),
      ),
    );

    expect(find.text('Limite de IA atingido'), findsOneWidget);
    expect(
      find.text(
        'Sua jornada já está salva. O limite gratuito de IA acabou por hoje. Você pode voltar amanhã, assistir a um anúncio para liberar +1 análise ou assinar Premium.',
      ),
      findsOneWidget,
    );
    expect(find.text('Assistir anúncio'), findsOneWidget);
    expect(find.text('Aprofundar com Premium'), findsOneWidget);
  });

  testWidgets('shows personalization signals and reading actions', (
    tester,
  ) async {
    final selectedStyles = <String>[];
    var saved = false;
    var ritual = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckInAiInsightCard(
            insight: CheckInAiInsight(
              insight:
                  'Ana, seus ultimos registros mostram melhora gradual hoje.',
              suggestedAction: 'Continue com um passo simples.',
              riskLevel: 'low',
              suggestedTrailId: null,
              suggestedTrailTitle: null,
              suggestedTrailReason: '',
              suggestedSpace: null,
              journeyPlan: null,
              generatedTrailDraft: null,
              fallbackUsed: false,
              contextSignals: const ['ultimos check-ins', 'trilha ativa'],
              usedContextSummary:
                  'Com base nos seus ultimos check-ins e na trilha ativa.',
              nextStep: const CheckInAiNextStep(
                type: 'ritual',
                label: 'Fazer uma pausa guiada de 2 minutos.',
              ),
            ),
            onRegenerate: selectedStyles.add,
            onSaveReading: () => saved = true,
            onCreateRitual: () => ritual = true,
          ),
        ),
      ),
    );

    expect(find.text('Personalizada'), findsOneWidget);
    expect(find.text('ultimos check-ins'), findsOneWidget);
    expect(find.text('trilha ativa'), findsOneWidget);
    expect(find.text('Mais curta'), findsOneWidget);
    expect(find.text('Salvar leitura'), findsOneWidget);
    expect(find.text('Transformar em ritual'), findsOneWidget);

    await tester.tap(find.text('Mais pratica'));
    await tester.tap(find.text('Salvar leitura'));
    await tester.tap(find.text('Transformar em ritual'));

    expect(selectedStyles, ['practical']);
    expect(saved, isTrue);
    expect(ritual, isTrue);
  });
}
