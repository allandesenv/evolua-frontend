import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/repositories/daily_ritual_repository.dart';
import 'package:evolua_frontend/features/daily_ritual/presentation/pages/daily_ritual_page.dart';
import 'package:evolua_frontend/shared/presentation/widgets/evolua_async_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('completes morning ritual flow and shows result', (tester) async {
    final repository = _FakeDailyRitualRepository();

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Ritual do Dia'), findsOneWidget);
    expect(find.text('Começar agora'), findsOneWidget);

    await tester.tap(find.text('Começar agora'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).textCapitalization,
      TextCapitalization.sentences,
    );

    await _answerStep(tester, 'calmo');
    await _answerStep(tester, 'clareza');
    await _answerStep(tester, 'agir com calma');
    await _answerStep(tester, 'pausar antes de reagir', submit: true);

    expect(find.text('Seu ritual de hoje está pronto'), findsOneWidget);
    expect(find.text('Leve isso com você hoje'), findsOneWidget);
    expect(find.text('Intenção escolhida'), findsOneWidget);
    expect(find.text('Microação escolhida'), findsOneWidget);
    expect(find.textContaining('Intencao'), findsNothing);
    expect(find.textContaining('Microacao'), findsNothing);
    expect(find.textContaining('Nao foi possivel'), findsNothing);
    expect(find.text('calmo'), findsOneWidget);
    expect(find.text('clareza'), findsOneWidget);
    expect(find.text('agir com calma'), findsAtLeastNWidgets(1));
    expect(find.text('pausar antes de reagir'), findsOneWidget);
  });

  testWidgets('shows existing evening closing in read-only mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        _FakeDailyRitualRepository(evening: _ritual(DailyRitualType.evening)),
        type: DailyRitualType.evening,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seu fechamento de hoje está pronto'), findsOneWidget);
    expect(find.text('Guarde isso do seu dia'), findsOneWidget);
    expect(find.text('agir com calma'), findsAtLeastNWidgets(1));
    expect(find.text('Começar agora'), findsNothing);
    expect(find.text('Intenção escolhida'), findsOneWidget);
    expect(find.text('Microação escolhida'), findsOneWidget);
  });

  testWidgets('morning continue starts disabled and enables with valid text', (
    tester,
  ) async {
    final repository = _FakeDailyRitualRepository();

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Começar agora'));
    await tester.pumpAndSettle();

    expect(_ritualActionButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   \n  ');
    await tester.pumpAndSettle();
    expect(_ritualActionButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'presente');
    await tester.pumpAndSettle();
    expect(_ritualActionButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(_ritualActionButton(tester).onPressed, isNull);
    expect(repository.createCallCount, 0);
  });

  testWidgets('evening continue requires valid response text', (tester) async {
    final repository = _FakeDailyRitualRepository();

    await tester.pumpWidget(
      _testApp(repository, type: DailyRitualType.evening),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Começar agora'));
    await tester.pumpAndSettle();

    expect(_ritualActionButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'cansado');
    await tester.pumpAndSettle();
    expect(_ritualActionButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(_ritualActionButton(tester).onPressed, isNull);
    expect(repository.createCallCount, 0);
  });

  testWidgets('final submit is disabled without valid ritual response', (
    tester,
  ) async {
    final repository = _FakeDailyRitualRepository();

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Começar agora'));
    await tester.pumpAndSettle();

    await _answerStep(tester, 'calmo');
    await _answerStep(tester, 'clareza');
    await _answerStep(tester, 'agir com calma');

    expect(_ritualActionButton(tester).onPressed, isNull);

    expect(repository.createCallCount, 0);
    expect(find.text('Salvando...'), findsNothing);

    await tester.enterText(find.byType(TextField), 'pausar antes de reagir');
    await tester.pumpAndSettle();
    expect(_ritualActionButton(tester).onPressed, isNotNull);
  });
}

Future<void> _answerStep(
  WidgetTester tester,
  String answer, {
  bool submit = false,
}) async {
  await tester.enterText(find.byType(TextField), answer);
  await tester.pumpAndSettle();
  await tester.tap(find.text(submit ? 'Concluir' : 'Continuar'));
  await tester.pumpAndSettle();
}

EvoluaAsyncButton _ritualActionButton(WidgetTester tester) {
  return tester.widget<EvoluaAsyncButton>(find.byType(EvoluaAsyncButton));
}

Widget _testApp(
  DailyRitualRepository repository, {
  String type = DailyRitualType.morning,
}) {
  return ProviderScope(
    overrides: [dailyRitualRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: DailyRitualView(type: type)),
      ),
    ),
  );
}

class _FakeDailyRitualRepository implements DailyRitualRepository {
  _FakeDailyRitualRepository({this.evening});

  DailyRitual? morning;
  DailyRitual? evening;
  int createCallCount = 0;

  @override
  Future<DailyRitual?> today({
    required String type,
    required DateTime localDate,
  }) async {
    return type == DailyRitualType.evening ? evening : morning;
  }

  @override
  Future<DailyRitual> create(DailyRitualDraft draft) async {
    createCallCount++;
    final created = DailyRitual(
      id: 1,
      localDate: draft.localDate,
      type: draft.type,
      emotionalState: draft.emotionalState,
      dayNeed: draft.dayNeed,
      intention: draft.intention,
      microAction: draft.microAction,
      createdAt: DateTime(2026, 5, 7, 8),
    );
    if (draft.type == DailyRitualType.evening) {
      evening = created;
    } else {
      morning = created;
    }
    return created;
  }
}

DailyRitual _ritual(String type) {
  return DailyRitual(
    id: 1,
    localDate: DateTime(2026, 5, 7),
    type: type,
    emotionalState: 'calmo',
    dayNeed: 'clareza',
    intention: 'agir com calma',
    microAction: 'pausar antes de reagir',
    createdAt: DateTime(2026, 5, 7, 8),
  );
}
