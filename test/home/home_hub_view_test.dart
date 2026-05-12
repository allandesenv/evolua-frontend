import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_progress.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/repositories/daily_ritual_repository.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_controller.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:evolua_frontend/features/future_message/domain/repositories/future_message_repository.dart';
import 'package:evolua_frontend/features/home/presentation/widgets/home_hub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeHubView briefing', () {
    testWidgets('renders the briefing flow in the intended order', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(now: DateTime(2026, 5, 7, 8)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Leo'), findsOneWidget);
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

    testWidgets(
      'shows daytime check-in action when user has no check-in today',
      (tester) async {
        var openedCheckIn = false;
        final yesterday = DateTime.now().subtract(const Duration(days: 1));

        await tester.pumpWidget(
          _testApp(
            onOpenCheckIn: () => openedCheckIn = true,
            now: DateTime(2026, 5, 7, 13),
            checkInRepository: _FakeCheckInRepository(
              items: [
                CheckIn(
                  id: 20,
                  userId: 'user-123',
                  mood: 'calmo',
                  reflection: 'ontem foi melhor',
                  energyLevel: 7,
                  recommendedPractice: 'Pausa curta',
                  aiInsight: null,
                  createdAt: yesterday,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Como esta seu dia ate aqui?'), findsOneWidget);
        expect(find.text('Fazer check-in'), findsOneWidget);

        await tester.tap(find.text('Fazer check-in'));
        await tester.pumpAndSettle();

        expect(openedCheckIn, isTrue);
      },
    );

    testWidgets('shows persisted intelligent reading from history', (
      tester,
    ) async {
      const persistedInsight =
          'Leitura recuperada do historico salvo no servidor.';
      await tester.pumpWidget(
        _testApp(
          checkInRepository: _FakeCheckInRepository(
            items: [
              CheckIn(
                id: 30,
                userId: 'user-123',
                mood: 'calmo',
                reflection: 'voltei para ver minha leitura',
                energyLevel: 7,
                recommendedPractice: 'Respirar por dois minutos.',
                aiInsight: _insight(insight: persistedInsight),
                createdAt: DateTime(2026, 5, 7, 9),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Leitura recuperada do historico salvo no servidor',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Depois do proximo check-in'), findsNothing);
    });

    testWidgets('shows compact intelligent reading bullets on Home', (
      tester,
    ) async {
      const longInsight =
          'Seu momento atual pede reducao de carga e foco em uma unica acao simples. Este segundo bloco fica guardado para a analise completa.';
      await tester.pumpWidget(
        _testApp(
          checkInRepository: _FakeCheckInRepository(
            items: [
              CheckIn(
                id: 31,
                userId: 'user-123',
                mood: 'tensao relevante',
                reflection: 'muitas frentes abertas',
                energyLevel: 7,
                recommendedPractice: 'Desacelerar por dois minutos.',
                aiInsight: _insight(insight: longInsight),
                createdAt: DateTime(2026, 5, 7, 9),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(longInsight), findsNothing);
      expect(
        find.textContaining('Energia: 7/10', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Estado: Tensao relevante', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Melhor resposta agora:', findRichText: true),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Ver analise completa'));
      await tester.tap(find.text('Ver analise completa'));
      await tester.pumpAndSettle();

      expect(find.text(longInsight), findsOneWidget);
    });

    testWidgets('updates intelligent reading after check-in creation', (
      tester,
    ) async {
      final repository = _MutableCheckInRepository(
        initialItems: const <CheckIn>[],
        created: CheckIn(
          id: 77,
          userId: 'user-123',
          mood: 'ansioso',
          reflection: '',
          energyLevel: 6,
          recommendedPractice: '',
          aiInsight: null,
          createdAt: DateTime(2026, 5, 7, 9),
        ),
        listedAfterCreate: [
          CheckIn(
            id: 77,
            userId: 'user-123',
            mood: 'ansioso',
            reflection: '',
            energyLevel: 6,
            recommendedPractice: 'Desacelerar',
            aiInsight: _insight(
              insight: 'Seu momento atual pede reducao de carga.',
            ),
            createdAt: DateTime(2026, 5, 7, 9),
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          now: DateTime(2026, 5, 7, 13),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Depois do proximo check-in'),
        findsOneWidget,
      );

      final context = tester.element(find.byType(HomeHubView));
      final container = ProviderScope.containerOf(context);
      await container.read(checkInControllerProvider.notifier).create(
            mood: 'ansioso',
            reflection: null,
            energyLevel: 6,
          );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Seu momento atual pede reducao de carga'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Energia: 6/10', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Estado: Ansioso', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows contextual mini cards and opens direct actions', (
      tester,
    ) async {
      var openedFutureMessages = false;
      var openedReflections = false;
      var openedMirror = false;

      await tester.pumpWidget(
        _testApp(
          onOpenFutureMessages: () => openedFutureMessages = true,
          onOpenFeed: () => openedReflections = true,
          onOpenEvolutionMirror: () => openedMirror = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Carta para o futuro'), findsOneWidget);
      expect(find.text('Reflexao recente'), findsOneWidget);
      expect(find.text('Insight rapido'), findsOneWidget);
      expect(find.text('Marco de evolucao'), findsOneWidget);

      await tester.tap(find.text('Carta para o futuro'));
      await tester.tap(find.text('Reflexao recente'));
      await tester.tap(find.text('Marco de evolucao'));
      await tester.pumpAndSettle();

      expect(openedFutureMessages, isTrue);
      expect(openedReflections, isTrue);
      expect(openedMirror, isTrue);
    });

    testWidgets('insight mini card opens analysis when insight exists', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insight rapido'));
      await tester.pumpAndSettle();
      expect(find.text('Analise completa'), findsOneWidget);
    });

    testWidgets('insight mini card opens check-in when insight is missing', (
      tester,
    ) async {
      var openedCheckIn = false;
      await tester.pumpWidget(
        _testApp(
          checkInRepository: _FakeCheckInRepository(
            items: [
              CheckIn(
                id: 32,
                userId: 'user-123',
                mood: 'calmo',
                reflection: 'sem insight ainda',
                energyLevel: 7,
                recommendedPractice: 'Respirar.',
                aiInsight: null,
                createdAt: DateTime(2026, 5, 7, 9),
              ),
            ],
          ),
          onOpenCheckIn: () => openedCheckIn = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insight rapido'));
      await tester.pumpAndSettle();
      expect(openedCheckIn, isTrue);
    });

    testWidgets('shows morning ritual entry point first', (tester) async {
      String? openedType;

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 8),
          onOpenDailyRitual: (type) => openedType = type,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bom dia, Leo'), findsOneWidget);
      expect(find.text('Iniciar Ritual do Dia'), findsOneWidget);
      expect(find.text('Fazer check-in'), findsOneWidget);

      await tester.tap(find.text('Iniciar Ritual do Dia'));
      await tester.pumpAndSettle();

      expect(openedType, DailyRitualType.morning);
    });

    testWidgets('shows evening closing entry point', (tester) async {
      String? openedType;
      var openedReflections = false;

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 20),
          onOpenDailyRitual: (type) => openedType = type,
          onOpenFeed: () => openedReflections = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vamos fechar o dia?'), findsOneWidget);
      expect(find.text('Fazer Fechamento do Dia'), findsOneWidget);
      expect(find.text('Escrever reflexao'), findsOneWidget);

      await tester.tap(find.text('Fazer Fechamento do Dia'));
      await tester.pumpAndSettle();
      expect(openedType, DailyRitualType.evening);

      await tester.tap(find.text('Escrever reflexao'));
      await tester.pumpAndSettle();
      expect(openedReflections, isTrue);
    });

    testWidgets('shows completed morning ritual until evening', (tester) async {
      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 14),
          dailyRitualRepository: _FakeDailyRitualRepository(
            morning: _testRitual(DailyRitualType.morning),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ritual do Dia concluido'), findsOneWidget);
      expect(find.text('Intencao de hoje: agir com calma'), findsOneWidget);
      expect(
        find.text('Pequeno passo: pausar antes de reagir'),
        findsOneWidget,
      );
      expect(find.text('Ver meu ritual'), findsOneWidget);
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

    testWidgets(
      'suggested trail action closes full analysis before opening trails',
      (tester) async {
        var openedTrails = false;
        await tester.pumpWidget(
          _testApp(onOpenTrails: () => openedTrails = true),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Ver analise completa'));
        await tester.tap(find.text('Ver analise completa'));
        await tester.pumpAndSettle();

        expect(find.text('Analise completa'), findsOneWidget);

        await tester.tap(find.text('Abrir trilha sugerida'));
        await tester.pumpAndSettle();

        expect(openedTrails, isTrue);
        expect(find.text('Analise completa'), findsNothing);
      },
    );

    testWidgets('shows next-step metadata as auxiliary context', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('8 min'), findsOneWidget);
      expect(find.text('mantem constancia'), findsOneWidget);
      expect(find.text('jornada ativa'), findsOneWidget);
      expect(find.text('Continuar jornada'), findsAtLeastNWidgets(1));
      expect(find.text('Espacos'), findsOneWidget);

      expect(find.widgetWithText(OutlinedButton, 'Espacos'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '8 min'), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'mantem constancia'),
        findsNothing,
      );
    });

    testWidgets('does not render journey progress inside next-step card', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Sua jornada em movimento'), findsNothing);
      expect(find.text('50%'), findsNothing);
      expect(find.text('50% da jornada'), findsNothing);
      expect(find.text('1/2 etapas'), findsNothing);
      expect(find.text('Proxima etapa: Escolher'), findsNothing);
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

    testWidgets('opens evolution mirror directly from rhythm card', (
      tester,
    ) async {
      var openedMirror = false;
      await tester.pumpWidget(
        _testApp(onOpenEvolutionMirror: () => openedMirror = true),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver Espelho da Evolucao'));
      await tester.tap(find.text('Ver Espelho da Evolucao'));
      await tester.pumpAndSettle();

      expect(openedMirror, isTrue);
      expect(find.text('Seu ritmo hoje'), findsNothing);
    });

    testWidgets('opens rhythm details from recent check-ins action', (
      tester,
    ) async {
      var openedMirror = false;
      await tester.pumpWidget(
        _testApp(onOpenEvolutionMirror: () => openedMirror = true),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver ultimos check-ins'));
      await tester.tap(find.text('Ver ultimos check-ins'));
      await tester.pumpAndSettle();

      expect(find.text('Seu ritmo hoje'), findsOneWidget);
      expect(find.text('Energia media'), findsOneWidget);
      expect(find.text('Estado dominante'), findsOneWidget);
      expect(find.text('Check-ins na semana'), findsOneWidget);
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('Consistencia da semana'), findsOneWidget);
      expect(find.text('Ultimos check-ins'), findsOneWidget);
      expect(find.text('Abrir Espelho da Evolucao'), findsOneWidget);

      await tester.ensureVisible(find.text('Abrir Espelho da Evolucao'));
      await tester.tap(find.text('Abrir Espelho da Evolucao'));
      await tester.pumpAndSettle();

      expect(openedMirror, isTrue);
      expect(find.text('Seu ritmo hoje'), findsNothing);
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

    testWidgets('uses light surfaces and readable text in light theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(theme: AppTheme.light(accessibleFont: true)),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('O que isso significa?'));
      final colors = context.evoluaColors;
      final panel = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = panel.decoration! as BoxDecoration;

      expect(Theme.of(context).brightness, Brightness.light);
      expect(decoration.color, colors.surface.withValues(alpha: 0.94));
      expect(
        decoration.color,
        isNot(AppColors.surface.withValues(alpha: 0.94)),
      );
      expect(
        Theme.of(context).textTheme.headlineSmall?.color,
        isNot(AppColors.textPrimary),
      );
    });
  });
}

Widget _testApp({
  CheckInRepository? checkInRepository,
  TrailRepository? trailRepository,
  DailyRitualRepository? dailyRitualRepository,
  ThemeData? theme,
  DateTime? now,
  VoidCallback? onOpenTrails,
  VoidCallback? onOpenFeed,
  VoidCallback? onOpenCommunity,
  VoidCallback? onOpenEvolutionMirror,
  VoidCallback? onOpenFutureMessages,
  ValueChanged<String>? onOpenDailyRitual,
  VoidCallback? onOpenCheckIn,
}) {
  return ProviderScope(
    overrides: [
      checkInRepositoryProvider.overrideWithValue(
        checkInRepository ?? _FakeCheckInRepository(),
      ),
      trailRepositoryProvider.overrideWithValue(
        trailRepository ?? _FakeTrailRepository(currentJourney: _testTrail()),
      ),
      futureMessageRepositoryProvider.overrideWithValue(
        _FakeFutureMessageRepository(),
      ),
      dailyRitualRepositoryProvider.overrideWithValue(
        dailyRitualRepository ?? const _FakeDailyRitualRepository(),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeHubView(
            profilesCount: 1,
            trailsCount: 1,
            checkInsCount: 4,
            postsCount: 2,
            communitiesCount: 1,
            displayName: 'Leo Respiro',
            mentorPremiumPassActive: false,
            now: now,
            onOpenTrails: onOpenTrails ?? () {},
            onOpenFeed: onOpenFeed ?? () {},
            onOpenCommunity: onOpenCommunity ?? () {},
            onOpenProfile: () {},
            onOpenEvolutionMirror: onOpenEvolutionMirror ?? () {},
            onOpenFutureMessages: onOpenFutureMessages ?? () {},
            onOpenFutureMessage: (_) {},
            onOpenDailyRitual: onOpenDailyRitual ?? (_) {},
            onOpenCheckIn: onOpenCheckIn ?? () {},
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

class _MutableCheckInRepository implements CheckInRepository {
  _MutableCheckInRepository({
    required List<CheckIn> initialItems,
    required this.created,
    required this.listedAfterCreate,
  }) : _items = initialItems;

  List<CheckIn> _items;
  final CheckIn created;
  final List<CheckIn> listedAfterCreate;

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
      items: _items,
      page: page,
      size: size,
      totalItems: _items.length,
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
    _items = listedAfterCreate;
    return created;
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
  Future<TrailJourney> journey(int trailId) async {
    final trail = _currentJourney;
    if (trail == null) {
      throw StateError('Sem jornada ativa.');
    }
    final steps = [
      const TrailJourneyStep(
        index: 0,
        title: 'Respirar',
        summary: 'Dois minutos de presenca.',
        content: 'Respire por quatro ciclos.',
        status: 'completed',
        estimatedMinutes: 2,
        mediaLinks: [],
      ),
      const TrailJourneyStep(
        index: 1,
        title: 'Escolher',
        summary: 'Uma proxima acao simples.',
        content: 'Escolha uma acao pequena.',
        status: 'current',
        estimatedMinutes: 4,
        mediaLinks: [],
      ),
    ];
    return TrailJourney(
      trail: trail,
      steps: steps,
      progress: TrailProgress(
        currentStepIndex: 1,
        completedStepIndexes: const [0],
        startedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        completedAt: null,
      ),
      progressPercent: 50,
      nextStep: steps.last,
    );
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

class _FakeFutureMessageRepository implements FutureMessageRepository {
  @override
  Future<PaginatedResponse<FutureMessage>> list({
    required int page,
    required int size,
    List<String>? statuses,
  }) async {
    return PaginatedResponse<FutureMessage>.empty(page: page, size: size);
  }

  @override
  Future<PaginatedResponse<FutureMessage>> delivered({
    required int page,
    required int size,
  }) async {
    return PaginatedResponse<FutureMessage>.empty(page: page, size: size);
  }

  @override
  Future<FutureMessage> create(FutureMessageDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<FutureMessage> get(int id) {
    throw UnimplementedError();
  }

  @override
  Future<void> heartbeat() async {}

  @override
  Future<FutureMessage> markRead(int id) {
    throw UnimplementedError();
  }

  @override
  Future<FutureMessage> react(int id, String reaction) {
    throw UnimplementedError();
  }
}

class _FakeDailyRitualRepository implements DailyRitualRepository {
  const _FakeDailyRitualRepository({this.morning});

  final DailyRitual? morning;

  @override
  Future<DailyRitual?> today({
    required String type,
    required DateTime localDate,
  }) async {
    return type == DailyRitualType.evening ? null : morning;
  }

  @override
  Future<DailyRitual> create(DailyRitualDraft draft) {
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

DailyRitual _testRitual(String type) {
  return DailyRitual(
    id: type == DailyRitualType.evening ? 2 : 1,
    localDate: DateTime(2026, 5, 7),
    type: type,
    emotionalState: 'calmo',
    dayNeed: 'clareza',
    intention: 'agir com calma',
    microAction: 'pausar antes de reagir',
    createdAt: DateTime(2026, 5, 7, 8),
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
