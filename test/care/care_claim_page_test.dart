import 'package:evolua_frontend/features/care/application/care_claim_controller.dart';
import 'package:evolua_frontend/features/care/presentation/pages/care_claim_page.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders therapist portal on mobile without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          careClaimControllerProvider.overrideWith(
            () => _FakeCareClaimController(_claimState()),
          ),
        ],
        child: const MaterialApp(home: CareClaimPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Painel clínico Evolua Care'), findsOneWidget);
    expect(find.text('Resumo clínico rápido'), findsOneWidget);
    expect(find.text('Pontos de atenção'), findsOneWidget);
    expect(
      find.text('Linha: energia registrada nos check-ins (0 a 10).'),
      findsOneWidget,
    );
    expect(find.text('Contexto emocional observado'), findsOneWidget);
    expect(find.text('Intenção terapêutica'), findsOneWidget);
    expect(find.text('Micro-ação sugerida'), findsOneWidget);
    expect(find.text('Prescrever ritual personalizado'), findsOneWidget);
    expect(find.textContaining('clÃ'), findsNothing);
    expect(find.textContaining('relatÃ'), findsNothing);
    expect(find.textContaining('nÃ'), findsNothing);
  });
}

class _FakeCareClaimController extends CareClaimController {
  _FakeCareClaimController(this._state);

  final CareClaimState _state;

  @override
  Future<CareClaimState> build() async => _state;

  @override
  Future<void> sendPrescription({
    required String type,
    required DateTime localDate,
    required String emotionalState,
    required String intention,
    required String microAction,
  }) async {}
}

CareClaimState _claimState() {
  return CareClaimState(
    shareId: 'share-1',
    numericCode: '123456',
    secretBase64: 'secret=',
    sessionExpiresAt: DateTime(2026, 5, 27, 8, 30),
    report: CareClinicalReport(
      generatedAt: DateTime(2026, 5, 27, 7),
      checkIns: [
        CareClinicalCheckIn(
          mood: 'ansiedade',
          energyLevel: 3,
          createdAt: DateTime(2026, 5, 27, 7),
          aiInsight:
              'O paciente relata maior tensão no início do dia. A queda de energia aparece associada a excesso de demandas.',
        ),
        CareClinicalCheckIn(
          mood: 'ansiedade',
          energyLevel: 4,
          createdAt: DateTime(2026, 5, 26, 7),
        ),
        CareClinicalCheckIn(
          mood: 'cansaço',
          energyLevel: 6,
          createdAt: DateTime(2026, 5, 25, 7),
        ),
      ],
      rituals: [
        CareClinicalRitual(
          type: DailyRitualType.morning,
          localDate: DateTime(2026, 5, 27),
          intention: 'começar com presença',
          microAction: 'respirar antes de abrir mensagens',
        ),
      ],
    ),
  );
}
