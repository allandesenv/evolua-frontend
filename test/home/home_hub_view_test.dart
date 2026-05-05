import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:evolua_frontend/features/home/presentation/widgets/home_hub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeHubView briefing', () {
    testWidgets('renders the briefing flow in the intended order', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('O que isso significa?'), findsOneWidget);
      expect(find.text('O que faco agora?'), findsOneWidget);
      expect(find.text('Como anda meu ritmo?'), findsOneWidget);

      final insightTop = tester
          .getTopLeft(find.text('O que isso significa?'))
          .dy;
      final nextStepTop = tester.getTopLeft(find.text('O que faco agora?')).dy;
      final rhythmTop = tester.getTopLeft(find.text('Como anda meu ritmo?')).dy;

      expect(insightTop, lessThan(nextStepTop));
      expect(nextStepTop, lessThan(rhythmTop));
    });

    testWidgets('opens full intelligent analysis from summarized card', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Ver analise completa'), findsOneWidget);
      await tester.ensureVisible(find.text('Ver analise completa'));
      await tester.tap(find.text('Ver analise completa'));
      await tester.pumpAndSettle();

      expect(find.text('Analise completa'), findsOneWidget);
      expect(find.text('Risco low'), findsAtLeastNWidgets(1));
      expect(find.text('Abrir trilha sugerida'), findsOneWidget);
    });

    testWidgets('shows next-step metadata as auxiliary context', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('8 min'), findsOneWidget);
      expect(find.text('mantem constancia'), findsOneWidget);
      expect(find.text('jornada ativa'), findsOneWidget);
      expect(find.text('Continuar jornada'), findsOneWidget);
      expect(find.text('Espacos'), findsOneWidget);

      expect(find.widgetWithText(OutlinedButton, 'Espacos'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '8 min'), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'mantem constancia'),
        findsNothing,
      );
    });

    testWidgets('renders safe-mode analysis text in full analysis', (
      tester,
    ) async {
      const safeInsightText =
          'Seu check-in mostra um momento de avanco e capacidade de fechamento.';
      await tester.pumpWidget(
        _testApp(
          checkInRepository: _FakeCheckInRepository(
            items: [
              CheckIn(
                id: 10,
                userId: 'user-123',
                mood: 'produtivo',
                reflection: 'tarefas concluidas',
                energyLevel: 7,
                recommendedPractice: 'Organize a proxima prioridade.',
                aiInsight: _insight(
                  insight: safeInsightText,
                  fallbackUsed: true,
                ),
                createdAt: DateTime.now(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver analise completa'));
      await tester.tap(find.text('Ver analise completa'));
      await tester.pumpAndSettle();

      expect(find.text('Modo seguro'), findsAtLeastNWidgets(1));
      expect(find.text(safeInsightText), findsAtLeastNWidgets(1));
    });

    testWidgets('opens rhythm details with personal metrics', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver detalhes do seu ritmo'));
      await tester.tap(find.text('Ver detalhes do seu ritmo'));
      await tester.pumpAndSettle();

      expect(find.text('Seu ritmo hoje'), findsOneWidget);
      expect(find.text('Energia media'), findsOneWidget);
      expect(find.text('Estado dominante'), findsOneWidget);
      expect(find.text('Check-ins esta semana'), findsOneWidget);
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('Ultimos check-ins'), findsOneWidget);
    });

    testWidgets('keeps the briefing usable on mobile width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Leitura inteligente'), findsOneWidget);
      expect(find.text('Proximo passo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _testApp({
  CheckInRepository? checkInRepository,
  TrailRepository? trailRepository,
}) {
  return ProviderScope(
    overrides: [
      checkInRepositoryProvider.overrideWithValue(
        checkInRepository ?? _FakeCheckInRepository(),
      ),
      trailRepositoryProvider.overrideWithValue(
        trailRepository ?? _FakeTrailRepository(currentJourney: _testTrail()),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeHubView(
            profilesCount: 1,
            trailsCount: 1,
            checkInsCount: 4,
            postsCount: 2,
            communitiesCount: 1,
            onOpenTrails: () {},
            onOpenFeed: () {},
            onOpenCommunity: () {},
            onOpenProfile: () {},
            onOpenCheckIn: () {},
          ),
        ),
      ),
    ),
  );
}

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository({List<CheckIn>? items}) : items = items ?? _checkIns();

  final List<CheckIn> items;

  @override
  Future<PaginatedResponse<CheckIn>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? mood,
    String? energyRange,
    DateTime? from,
    DateTime? to,
  }) async {
    return PaginatedResponse(
      items: items,
      page: page,
      size: size,
      totalItems: items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<CheckIn> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) async {
    return CheckIn(
      id: 99,
      userId: 'user-123',
      mood: mood,
      reflection: reflection ?? '',
      energyLevel: energyLevel,
      recommendedPractice: 'Respire por dois minutos.',
      aiInsight: _insight(),
      createdAt: DateTime.now(),
    );
  }
}

class _FakeTrailRepository implements TrailRepository {
  const _FakeTrailRepository({Trail? currentJourney})
    : _currentJourney = currentJourney;

  final Trail? _currentJourney;

  @override
  Future<Trail?> currentJourney() async => _currentJourney;

  @override
  Future<PaginatedResponse<Trail>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? category,
    bool? premium,
  }) async {
    final items = _currentJourney == null
        ? const <Trail>[]
        : <Trail>[_currentJourney];
    return PaginatedResponse(
      items: items,
      page: page,
      size: size,
      totalItems: items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<Trail> create({
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(int id) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> journey(int trailId) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> startJourney(int trailId) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> completeStep(int trailId, int stepIndex) {
    throw UnimplementedError();
  }

  @override
  Future<Trail> update({
    required int id,
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
  }) {
    throw UnimplementedError();
  }
}

List<CheckIn> _checkIns() {
  final now = DateTime.now();
  return [
    CheckIn(
      id: 1,
      userId: 'user-123',
      mood: 'ansioso',
      reflection: 'manha intensa',
      energyLevel: 6,
      recommendedPractice: 'Respiracao curta',
      aiInsight: _insight(),
      createdAt: now,
    ),
    CheckIn(
      id: 2,
      userId: 'user-123',
      mood: 'calmo',
      reflection: 'andou bem',
      energyLevel: 8,
      recommendedPractice: 'Caminhada curta',
      aiInsight: null,
      createdAt: now.subtract(const Duration(days: 1, hours: 1)),
    ),
    CheckIn(
      id: 3,
      userId: 'user-123',
      mood: 'cansado',
      reflection: 'sono ruim',
      energyLevel: 5,
      recommendedPractice: 'Pausa guiada',
      aiInsight: null,
      createdAt: now.subtract(const Duration(days: 2, hours: 2)),
    ),
  ];
}

CheckInAiInsight _insight({
  String insight =
      'Seu momento aponta para ansiedade leve e pede uma acao simples para recuperar clareza sem abrir muitas frentes agora.',
  bool fallbackUsed = false,
}) {
  return CheckInAiInsight(
    insight: insight,
    suggestedAction:
        'Faca uma respiracao de 4 ciclos e escolha uma tarefa pequena.',
    riskLevel: 'low',
    suggestedTrailId: 1,
    suggestedTrailTitle: 'Clareza em 8 minutos',
    suggestedTrailReason:
        'Ajuda a reduzir sobrecarga e escolher o proximo passo.',
    suggestedSpace: null,
    journeyPlan: null,
    generatedTrailDraft: null,
    fallbackUsed: fallbackUsed,
  );
}

Trail _testTrail() {
  return Trail(
    id: 1,
    userId: 'user-123',
    title: 'Clareza em 8 minutos',
    summary: 'Uma trilha curta para organizar o momento sem pressa.',
    content: 'Respire, nomeie e escolha.',
    category: 'clareza',
    premium: false,
    privateTrail: false,
    activeJourney: true,
    generatedByAi: true,
    journeyKey: 'clareza',
    sourceStyle: 'briefing',
    accessible: true,
    mediaLinks: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}
