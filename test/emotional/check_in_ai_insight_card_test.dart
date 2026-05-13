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
              limitMessage: 'Voce chegou ao limite de IA do plano gratuito hoje.',
            ),
            onWatchRewardedAd: () {},
            onOpenPremium: () {},
          ),
        ),
      ),
    );

    expect(find.text('Limite de IA atingido'), findsOneWidget);
    expect(
      find.text('Voce chegou ao limite de IA do plano gratuito hoje.'),
      findsOneWidget,
    );
    expect(find.text('Assistir anuncio para +1 analise'), findsOneWidget);
    expect(find.text('Assinar Premium'), findsOneWidget);
  });
}

