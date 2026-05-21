import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:evolua_frontend/features/emotional/presentation/pages/check_in_quick_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CheckInQuickView', () {
    testWidgets('shows quick moods and expands additional mood groups', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('briefing'), findsNothing);
      expect(find.text('Calma'), findsOneWidget);
      expect(find.text('Ansiedade'), findsOneWidget);
      expect(find.text('Cansaço'), findsOneWidget);
      expect(find.text('Distração'), findsOneWidget);
      expect(find.text('Mais estados'), findsOneWidget);
      expect(find.text('Foco'), findsNothing);

      await tester.tap(find.text('Mais estados'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Voltar'), findsOneWidget);
      expect(find.text('Buscar estado'), findsOneWidget);
      expect(find.text('Emocionais'), findsOneWidget);
      expect(find.text('Mentais'), findsOneWidget);
      expect(find.text('Físicos'), findsOneWidget);
      expect(find.text('Comportamentais'), findsOneWidget);

      await tester.ensureVisible(find.text('Foco'));
      await tester.tap(find.text('Foco'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Estado selecionado: Foco'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Foco'), findsOneWidget);
    });

    testWidgets('supports other mood with optional free text', (tester) async {
      final repository = _FakeCheckInRepository();

      await tester.pumpWidget(_testApp(checkInRepository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mais estados'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Outro estado'));
      await tester.tap(find.text('Outro estado'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Estado selecionado: Outro estado'), findsOneWidget);
      expect(find.text('Descreva com suas palavras'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descreva com suas palavras'),
        'saudade tranquila',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pumpAndSettle();

      expect(repository.createdMood, 'saudade tranquila');
    });

    testWidgets('creates check-in and calls completion callback', (
      tester,
    ) async {
      var completed = false;
      final repository = _FakeCheckInRepository();

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          onCompleted: () => completed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'preciso organizar o dia',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pumpAndSettle();

      expect(repository.createdMood, 'calma');
      expect(repository.createdReflection, 'preciso organizar o dia');
      expect(repository.createdEnergy, 7);
      expect(completed, isTrue);
    });
  });
}

Widget _testApp({
  CheckInRepository? checkInRepository,
  VoidCallback? onCompleted,
}) {
  return ProviderScope(
    overrides: [
      checkInRepositoryProvider.overrideWithValue(
        checkInRepository ?? _FakeCheckInRepository(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CheckInQuickView(onCompleted: onCompleted),
        ),
      ),
    ),
  );
}

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository({List<CheckIn>? items}) : items = items ?? _checkIns();

  final List<CheckIn> items;
  String? createdMood;
  String? createdReflection;
  int? createdEnergy;

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
    createdMood = mood;
    createdReflection = reflection;
    createdEnergy = energyLevel;

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

  @override
  Future<CheckIn> generateDeepReading(int checkInId) async {
    return items.firstWhere(
      (item) => item.id == checkInId,
      orElse: () => CheckIn(
        id: checkInId,
        userId: 'user-123',
        mood: 'calmo',
        reflection: '',
        energyLevel: 7,
        recommendedPractice: 'Respire por dois minutos.',
        aiInsight: _insight(),
        createdAt: DateTime.now(),
      ),
    );
  }
}

List<CheckIn> _checkIns() {
  return [
    CheckIn(
      id: 1,
      userId: 'user-123',
      mood: 'ansioso',
      reflection: 'manha intensa',
      energyLevel: 6,
      recommendedPractice: 'Respiracao curta',
      aiInsight: _insight(),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}

CheckInAiInsight _insight() {
  return const CheckInAiInsight(
    insight: 'Um momento de ansiedade leve.',
    suggestedAction: 'Respire por alguns ciclos.',
    riskLevel: 'low',
    suggestedTrailId: null,
    suggestedTrailTitle: null,
    suggestedTrailReason: '',
    suggestedSpace: null,
    journeyPlan: null,
    generatedTrailDraft: null,
    fallbackUsed: false,
  );
}
