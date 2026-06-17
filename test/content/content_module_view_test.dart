import 'dart:async';
import 'dart:typed_data';

import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_progress.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_response.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/content_module_view.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ContentModuleView mobile trails navigation', () {
    Finder catalogTabFinder() {
      return find
          .ancestor(
            of: find.text('Explorar trilhas').first,
            matching: find.byType(InkWell),
          )
          .first;
    }

    Finder journeyTabFinder() {
      return find
          .ancestor(
            of: find.text('Trilha').first,
            matching: find.byType(InkWell),
          )
          .first;
    }

    testWidgets('shows journey and catalog switcher on compact width', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Trilha atual'), findsOneWidget);
      expect(find.text('Explorar trilhas'), findsWidgets);
      expect(catalogTabFinder(), findsOneWidget);
      expect(find.text('Explorar'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens catalog by default when there is no active journey', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(
        _testApp(trailRepository: _FakeTrailRepository(hasActiveTrail: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Catálogo de trilhas'), findsOneWidget);
      expect(find.text('Respiracao breve'), findsOneWidget);
      expect(find.text('Sua trilha'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps catalog focused when journey tab has no active trail', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(
        _testApp(trailRepository: _FakeTrailRepository(hasActiveTrail: false)),
      );
      await tester.pumpAndSettle();

      await tester.tap(journeyTabFinder());
      await tester.pumpAndSettle();

      expect(find.text('Catálogo de trilhas'), findsOneWidget);
      expect(find.text('Respiracao breve'), findsOneWidget);
      expect(find.text('Sua trilha'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens catalog even when an active journey exists', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await tester.tap(catalogTabFinder());
      await tester.pumpAndSettle();

      expect(find.text('Catálogo de trilhas'), findsOneWidget);
      expect(find.text('Respiracao breve'), findsOneWidget);
      expect(find.text('Minha trilha ativa'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens catalog from active journey action', (tester) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await tester.tap(catalogTabFinder());
      await tester.pumpAndSettle();

      expect(find.text('Catálogo de trilhas'), findsOneWidget);
      expect(find.text('Respiracao breve'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('completed journey shows final state and opens catalog', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(
        _testApp(
          trailRepository: _FakeTrailRepository(
            journeyBuilder: _completedByStepsJourney,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trilha concluída'), findsWidgets);
      expect(find.text('Fazer próxima etapa'), findsNothing);
      expect(find.text('Explorar novas trilhas'), findsWidgets);

      await tester.ensureVisible(find.text('Explorar novas trilhas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explorar novas trilhas').last);
      await tester.pumpAndSettle();

      expect(find.text('Respiracao breve'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('started journey CTA explains current step completion', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Fazer próxima etapa'), findsNothing);
      expect(find.text('Concluir etapa atual'), findsOneWidget);
      expect(find.textContaining('Leia a etapa atual'), findsNothing);
    });

    testWidgets('empty step list is not treated as completed', (tester) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(
        _testApp(
          trailRepository: _FakeTrailRepository(
            journeyBuilder: _emptyStepsJourney,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trilha concluída'), findsNothing);
      expect(find.text('Trilha indisponível'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('journey and catalog communicate different purposes', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Sua trilha'), findsOneWidget);
      expect(find.text('Catálogo de trilhas'), findsNothing);

      await tester.tap(catalogTabFinder());
      await tester.pumpAndSettle();

      expect(find.text('Catálogo de trilhas'), findsOneWidget);
      expect(
        find.textContaining(
          'Descubra trilhas por tema, formato e profundidade',
        ),
        findsOneWidget,
      );
    });

    testWidgets('rapid step taps never stack journey bottom sheets', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      final respirarNode = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('Respirar').first,
              matching: find.byType(InkWell),
            )
            .first,
      );
      final escolherNode = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('Escolher').first,
              matching: find.byType(InkWell),
            )
            .first,
      );

      respirarNode.onTap!.call();
      escolherNode.onTap!.call();
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Sua trilha'), findsOneWidget);

      escolherNode.onTap!.call();
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    });

    testWidgets('exercise step response can be saved and edited', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository();

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      expect(find.text('Sua resposta'), findsOneWidget);
      expect(find.text('Salvar resposta'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Toque para responder ao exercício...'),
        'Eu começo querendo clareza.',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Salvar resposta'));
      expect(_saveResponseButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Salvar resposta'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        trailRepository.savedResponses[(trailId: 1, stepIndex: 0)],
        'Eu começo querendo clareza.',
      );
      expect(find.text('Resposta salva no seu diário.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Toque para responder ao exercício...'),
        'Depois eu costumo escolher uma ação pequena.',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Salvar resposta'));
      expect(_saveResponseButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Salvar resposta'));
      await tester.pumpAndSettle();

      expect(
        trailRepository.savedResponses[(trailId: 1, stepIndex: 0)],
        'Depois eu costumo escolher uma ação pequena.',
      );
    });

    testWidgets('empty step response is blocked before repository call', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository();

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Salvar resposta'));
      final saveButton = _saveResponseButton(tester);

      expect(saveButton.onPressed, isNull);
      expect(trailRepository.saveStepResponseCallCount, 0);
      expect(find.text('Salvando...'), findsNothing);
    });

    testWidgets('whitespace step response is blocked before repository call', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository();

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Toque para responder ao exercício...'),
        '   \n   ',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Salvar resposta'));
      final saveButton = _saveResponseButton(tester);

      expect(saveButton.onPressed, isNull);
      expect(trailRepository.saveStepResponseCallCount, 0);
      expect(find.text('Salvando...'), findsNothing);
    });

    testWidgets('placeholder text is not accepted as step response', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository();

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Toque para responder ao exercício...'),
        'Toque para responder ao exercício...',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Salvar resposta'));
      final saveButton = _saveResponseButton(tester);

      expect(saveButton.onPressed, isNull);
      expect(trailRepository.saveStepResponseCallCount, 0);
    });

    testWidgets('unchanged loaded step response is not saved again', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        initialResponses: const {
          (trailId: 1, stepIndex: 0): 'Resposta existente.',
        },
      );

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Salvar resposta'));
      final saveButton = _saveResponseButton(tester);

      expect(saveButton.onPressed, isNull);
      expect(trailRepository.saveStepResponseCallCount, 0);
      expect(find.text('Salvando...'), findsNothing);
    });

    testWidgets('loaded step response can be removed by saving empty text', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        initialResponses: const {
          (trailId: 1, stepIndex: 0): 'Resposta existente.',
        },
      );

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Toque para responder ao exercício...'),
        '',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Salvar resposta'));
      final saveButton = _saveResponseButton(tester);
      expect(saveButton.onPressed, isNotNull);

      await tester.tap(find.text('Salvar resposta'));
      await tester.pumpAndSettle();

      expect(trailRepository.saveStepResponseCallCount, 1);
      expect(trailRepository.savedResponses[(trailId: 1, stepIndex: 0)], '');
      expect(find.text('Resposta removida.'), findsOneWidget);
    });

    testWidgets('save failure keeps typed step response visible', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(failSavingResponse: true);

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      final field = find.widgetWithText(
        TextField,
        'Toque para responder ao exercício...',
      );
      await tester.enterText(field, 'Texto que nao pode se perder.');
      await tester.pump();
      await tester.ensureVisible(find.text('Salvar resposta'));
      expect(_saveResponseButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Salvar resposta'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Não foi possível salvar sua resposta agora. Tente novamente em instantes.',
        ),
        findsOneWidget,
      );
      final editableText = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editableText.controller.text, 'Texto que nao pode se perder.');
    });

    testWidgets('load failure keeps step response field editable', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(failLoadingResponse: true);

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      expect(find.text('Sua resposta'), findsOneWidget);
      expect(
        find.text(
          'Não conseguimos carregar sua resposta agora, mas você ainda pode escrever e salvar normalmente.',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Toque para responder ao exercício...'),
        'Consigo responder mesmo assim.',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Salvar resposta'));
      expect(_saveResponseButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Salvar resposta'));
      await tester.pumpAndSettle();

      expect(
        trailRepository.savedResponses[(trailId: 1, stepIndex: 0)],
        'Consigo responder mesmo assim.',
      );
    });

    testWidgets('double tapping save sends only one step response request', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final saveGate = Completer<void>();
      final trailRepository = _FakeTrailRepository(saveGate: saveGate);

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Toque para responder ao exercício...'),
        'Uma resposta com rede lenta.',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Salvar resposta'));
      expect(_saveResponseButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Salvar resposta'));
      await tester.tap(find.text('Salvar resposta'));
      await tester.pump();

      expect(trailRepository.saveStepResponseCallCount, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      saveGate.complete();
      await tester.pumpAndSettle();

      expect(
        trailRepository.savedResponses[(trailId: 1, stepIndex: 0)],
        'Uma resposta com rede lenta.',
      );
    });

    testWidgets('local draft is loaded and cleared after confirmed save', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      const draftKey = 'trail_step_response_draft:user-1:1:0';
      final trailRepository = _FakeTrailRepository();

      await tester.pumpWidget(
        _testApp(
          trailRepository: trailRepository,
          initialPreferences: const {draftKey: 'Rascunho local guardado.'},
        ),
      );
      await tester.pumpAndSettle();

      final field = find.widgetWithText(
        TextField,
        'Toque para responder ao exercício...',
      );
      var editableText = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editableText.controller.text, 'Rascunho local guardado.');

      await tester.ensureVisible(find.text('Salvar resposta'));
      await tester.tap(find.text('Salvar resposta'));
      await tester.pumpAndSettle();

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(draftKey), isNull);
      expect(
        trailRepository.savedResponses[(trailId: 1, stepIndex: 0)],
        'Rascunho local guardado.',
      );
    });

    testWidgets('server response prevails over local draft', (tester) async {
      await _setCompactSurface(tester);
      const draftKey = 'trail_step_response_draft:user-1:1:0';

      await tester.pumpWidget(
        _testApp(
          trailRepository: _FakeTrailRepository(
            initialResponses: {
              (trailId: 1, stepIndex: 0): 'Resposta salva no servidor.',
            },
          ),
          initialPreferences: const {draftKey: 'Rascunho antigo.'},
        ),
      );
      await tester.pumpAndSettle();

      final field = find.widgetWithText(
        TextField,
        'Toque para responder ao exercício...',
      );
      final editableText = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editableText.controller.text, 'Resposta salva no servidor.');

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(draftKey), isNull);
    });

    testWidgets('saved step response is loaded when returning to journey', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        initialResponses: {
          (trailId: 1, stepIndex: 0): 'Resposta guardada no diario.',
        },
      );

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      final field = find.widgetWithText(
        TextField,
        'Toque para responder ao exercício...',
      );
      final editableText = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editableText.controller.text, 'Resposta guardada no diario.');
    });

    testWidgets('step response editor clears immediately when user changes', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final authController = _MutableFakeAuthController(userId: 'user-a');
      final trailRepository = _FakeTrailRepository(
        initialResponses: {
          (trailId: 1, stepIndex: 0): 'Resposta privada do usuario A.',
        },
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => authController),
          trailRepositoryProvider.overrideWithValue(trailRepository),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(
              body: SizedBox.expand(
                child: ContentModuleView(showSectionChips: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byType(TextField).first;
      var editableText = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editableText.controller.text, 'Resposta privada do usuario A.');

      trailRepository.savedResponses.clear();
      authController.switchUser('user-b');
      await tester.pump();

      editableText = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editableText.controller.text, isEmpty);
      expect(find.text('Resposta privada do usuario A.'), findsNothing);
    });

    testWidgets('journey advances without requiring a step response', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository();

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Concluir etapa atual'));
      await tester.tap(find.text('Concluir etapa atual'));
      await tester.pumpAndSettle();

      expect(trailRepository.completeStepCallCount, 1);
      expect(trailRepository.savedResponses, isEmpty);
    });

    testWidgets('step completion snackbar names released next step', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        completeStepJourneyBuilder: _journeyAfterFirstStep,
      );

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Concluir etapa atual'));
      await tester.tap(find.text('Concluir etapa atual'));
      await tester.pump();

      expect(
        find.text('Etapa concluída. Próxima etapa liberada: Escolher.'),
        findsOneWidget,
      );
    });

    testWidgets('video step does not render editable response block', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        journeyBuilder: _videoJourney,
      );

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      expect(find.text('Sua resposta'), findsNothing);
      expect(find.text('Salvar resposta'), findsNothing);
    });

    testWidgets('audio step does not render editable response block', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        journeyBuilder: _audioJourney,
      );

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      expect(find.text('Sua resposta'), findsNothing);
      expect(find.text('Salvar resposta'), findsNothing);
      expect(find.text('Pausar'), findsNothing);
      expect(find.text('Parar'), findsNothing);
      expect(find.text('0.75x'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('1.25x'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);

      final contentFinder = find.textContaining('orienta').first;
      final listenButtonFinder = find.byIcon(Icons.volume_up_rounded);

      expect(contentFinder, findsOneWidget);
      expect(listenButtonFinder, findsOneWidget);
      expect(
        tester.getTopLeft(contentFinder).dy,
        lessThan(tester.getTopLeft(listenButtonFinder).dy),
      );
    });

    testWidgets('reading step does not render editable response block', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        journeyBuilder: _readingJourney,
      );

      await tester.pumpWidget(_testApp(trailRepository: trailRepository));
      await tester.pumpAndSettle();

      expect(find.text('Sua resposta'), findsNothing);
      expect(find.text('Salvar resposta'), findsNothing);
    });

    testWidgets('premium filters send explicit premium values', (tester) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        catalogTrails: [
          _trail(
            id: 2,
            title: 'Respiracao breve',
            summary: 'Uma trilha essencial.',
            activeJourney: false,
            generatedByAi: false,
          ),
          _trail(
            id: 3,
            title: 'Sono premium',
            summary: 'Uma trilha premium.',
            activeJourney: false,
            generatedByAi: false,
            premium: true,
            accessible: false,
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: trailRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Essenciais'));
      await tester.pumpAndSettle();

      expect(trailRepository.lastPremium, isFalse);
      expect(find.text('Respiracao breve'), findsOneWidget);
      expect(find.text('Sono premium'), findsNothing);

      await tester.tap(find.text('Premium'));
      await tester.pumpAndSettle();

      expect(trailRepository.lastPremium, isTrue);
      expect(find.text('Sono premium'), findsOneWidget);
      expect(find.text('Respiracao breve'), findsNothing);

      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();

      expect(trailRepository.lastPremium, isNull);
    });

    testWidgets('search waits for four chars and debounces requests', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository();

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: trailRepository,
        ),
      );
      await tester.pumpAndSettle();
      final initialCalls = trailRepository.listCallCount;

      await tester.enterText(find.byType(TextFormField), 'son');
      await tester.pump(const Duration(milliseconds: 600));

      expect(trailRepository.listCallCount, initialCalls);
      expect(find.text('Respiracao breve'), findsOneWidget);
      expect(find.byType(FeedSkeleton), findsNothing);
      expect(
        find.text('Digite pelo menos 4 caracteres para buscar.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField), 'sono');
      await tester.pump(const Duration(milliseconds: 200));

      expect(trailRepository.listCallCount, initialCalls);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(trailRepository.lastSearch, 'sono');
      expect(trailRepository.listCallCount, initialCalls + 1);
    });

    testWidgets('catalog shows real count and premium empty state', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        catalogTrails: [
          _trail(
            id: 2,
            title: 'Respiracao breve',
            summary: 'Uma trilha essencial.',
            activeJourney: false,
            generatedByAi: false,
          ),
          _trail(
            id: 3,
            title: 'Foco gentil',
            summary: 'Outra trilha essencial.',
            activeJourney: false,
            generatedByAi: false,
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: trailRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 trilhas encontradas'), findsOneWidget);

      await tester.tap(find.text('Premium'));
      await tester.pumpAndSettle();

      expect(find.text('Novas trilhas premium em breve.'), findsOneWidget);
    });

    testWidgets('mobile catalog hides manual pagination and loads next page', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        catalogTrails: _catalogTrailSet(6),
      );

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: trailRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anterior'), findsNothing);
      expect(find.text('Proxima'), findsNothing);
      expect(find.textContaining('Pagina'), findsNothing);
      expect(find.text('Trilha catalogo 1'), findsOneWidget);
      expect(find.text('Trilha catalogo 6'), findsNothing);

      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1400),
        1800,
      );
      await tester.pumpAndSettle();

      expect(trailRepository.requestedPages, containsAllInOrder([0, 1]));
      expect(find.text('Trilha catalogo 6'), findsOneWidget);
      expect(
        find.text('Você viu todas as trilhas disponíveis.'),
        findsOneWidget,
      );
    });

    testWidgets('mobile infinite catalog deduplicates repeated trail ids', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        catalogTrails: [
          ..._catalogTrailSet(4),
          _trail(
            id: 6,
            title: 'Trilha duplicada que nao deve aparecer',
            summary: 'Duplicada',
            activeJourney: false,
            generatedByAi: false,
          ),
          _trail(
            id: 6,
            title: 'Trilha duplicada que nao deve aparecer',
            summary: 'Duplicada',
            activeJourney: false,
            generatedByAi: false,
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: trailRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1400),
        1800,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Trilha duplicada que nao deve aparecer'),
        findsOneWidget,
      );
    });

    testWidgets('mobile load more error keeps current catalog and retries', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final failingPages = <int>{1};
      final trailRepository = _FakeTrailRepository(
        catalogTrails: _catalogTrailSet(6),
        failingPages: failingPages,
      );

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: trailRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1400),
        1800,
      );
      await tester.pumpAndSettle();

      expect(find.text('Trilha catalogo 1'), findsOneWidget);
      expect(find.text('Trilha catalogo 6'), findsNothing);
      expect(
        find.text('Não foi possível carregar mais trilhas.'),
        findsOneWidget,
      );

      failingPages.clear();
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Trilha catalogo 6'), findsOneWidget);
    });

    testWidgets('mobile catalog pull-to-refresh reloads first page', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final trailRepository = _FakeTrailRepository(
        catalogTrails: _catalogTrailSet(6),
      );

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: trailRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 420));
      await tester.pumpAndSettle();

      expect(
        trailRepository.requestedPages.where((page) => page == 0).length,
        2,
      );
    });

    testWidgets('uses light surfaces and readable text in light theme', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(
        _testApp(theme: AppTheme.light(accessibleFont: true)),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Trilha atual'));
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
        Theme.of(context).textTheme.bodyMedium?.color,
        isNot(AppColors.textSecondary),
      );
    });

    testWidgets('locked mentor premium trail offers Premium-only details', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      var premiumOpened = false;

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: _FakeTrailRepository(
            catalogTrail: _trail(
              id: 7,
              title: 'Mentoria para destravar a trilha',
              summary: 'Uma trilha de mentoria para clarear bloqueios.',
              activeJourney: false,
              generatedByAi: false,
              category: 'mentoria',
              premium: true,
              accessible: false,
              sourceStyle: 'mentor_exclusive',
            ),
          ),
          onOpenPremium: () => premiumOpened = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mentoria premium'), findsOneWidget);
      expect(find.text('Premium'), findsWidgets);

      await tester.ensureVisible(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalhes'));
      await tester.pumpAndSettle();

      expect(find.text('Mentoria disponível no Premium'), findsOneWidget);
      expect(find.text('Assistir anúncio'), findsNothing);
      expect(find.text('Aprofundar com Premium'), findsOneWidget);

      await tester.ensureVisible(find.text('Aprofundar com Premium'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprofundar com Premium'));
      await tester.pumpAndSettle();

      expect(premiumOpened, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mentor premium trail does not use rewarded pass refresh', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final rewardedService = _FakeRewardedAdService();
      final subscriptionRepository = _FakeSubscriptionRepository(
        mentorPassActiveFromCall: 4,
      );
      final trailRepository = _FakeTrailRepository(
        catalogTrail: _trail(
          id: 8,
          title: 'Mentoria para destravar a trilha',
          summary: 'Uma trilha de mentoria para clarear bloqueios.',
          activeJourney: false,
          generatedByAi: false,
          category: 'mentoria',
          premium: true,
          accessible: false,
          sourceStyle: 'mentor_exclusive',
        ),
      );

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: trailRepository,
          subscriptionRepository: subscriptionRepository,
          rewardedAdService: rewardedService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('Mentoria disponível no Premium'), findsOneWidget);
      expect(find.text('Assistir anúncio'), findsNothing);
      expect(rewardedService.lastRewardType, isNull);
      expect(subscriptionRepository.currentCallCount, greaterThanOrEqualTo(1));
      expect(trailRepository.listCallCount, 1);
      expect(find.text('Continuar trilha'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mentor trail stays blocked without Premium', (tester) async {
      await _setCompactSurface(tester);
      final rewardedService = _FakeRewardedAdService();
      final subscriptionRepository = _FakeSubscriptionRepository();
      final trailRepository = _FakeTrailRepository(
        catalogTrail: _trail(
          id: 10,
          title: 'Mentoria para destravar a trilha',
          summary: 'Uma trilha de mentoria para clarear bloqueios.',
          activeJourney: false,
          generatedByAi: false,
          category: 'mentoria',
          premium: true,
          accessible: false,
          sourceStyle: 'mentor_exclusive',
        ),
      );

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: trailRepository,
          subscriptionRepository: subscriptionRepository,
          rewardedAdService: rewardedService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('Mentoria disponível no Premium'), findsOneWidget);
      expect(find.text('Assistir anúncio'), findsNothing);
      expect(rewardedService.lastRewardType, isNull);
      expect(find.text('Continuar trilha'), findsNothing);
      expect(trailRepository.listCallCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('regular premium trail keeps premium-only detail state', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: _FakeTrailRepository(
            catalogTrail: _trail(
              id: 9,
              title: 'Sono profundo premium',
              summary: 'Uma trilha premium fora da mentoria.',
              activeJourney: false,
              generatedByAi: false,
              category: 'sono',
              premium: true,
              accessible: false,
              sourceStyle: 'catalog',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalhes'));
      await tester.pumpAndSettle();

      expect(
        find.text('Esta trilha aprofunda sua evolução emocional'),
        findsOneWidget,
      );
      expect(find.text('Assistir anúncio'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _setCompactSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 820));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

ButtonStyleButton _saveResponseButton(WidgetTester tester) {
  return tester.widget<ButtonStyleButton>(
    find.ancestor(
      of: find.text('Salvar resposta'),
      matching: find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton,
      ),
    ),
  );
}

Widget _testApp({
  ThemeData? theme,
  ContentModuleSection section = ContentModuleSection.journey,
  TrailRepository? trailRepository,
  SubscriptionRepository? subscriptionRepository,
  RewardedAdService? rewardedAdService,
  VoidCallback? onOpenPremium,
  Map<String, Object> initialPreferences = const {},
}) {
  SharedPreferences.setMockInitialValues(initialPreferences);

  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => _FakeAuthController(userId: 'user-1'),
      ),
      trailRepositoryProvider.overrideWithValue(
        trailRepository ?? _FakeTrailRepository(),
      ),
      subscriptionRepositoryProvider.overrideWithValue(
        subscriptionRepository ?? _FakeSubscriptionRepository(),
      ),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
      if (rewardedAdService != null)
        rewardedAdServiceProvider.overrideWithValue(rewardedAdService),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: Scaffold(
        body: SizedBox.expand(
          child: ContentModuleView(
            section: section,
            showSectionChips: true,
            onOpenPremium: onOpenPremium,
          ),
        ),
      ),
    ),
  );
}

class _FakeAuthController extends AuthController {
  _FakeAuthController({required this.userId});

  final String userId;

  @override
  Future<AuthSession?> build() async {
    return AuthSession(
      userId: userId,
      email: '$userId@evolua.test',
      roles: const ['ROLE_USER'],
      accessToken: 'test-token',
    );
  }
}

class _MutableFakeAuthController extends AuthController {
  _MutableFakeAuthController({required String userId}) : _userId = userId;

  String _userId;

  @override
  Future<AuthSession?> build() async => _session();

  void switchUser(String userId) {
    _userId = userId;
    state = AsyncData(_session());
  }

  AuthSession _session() {
    return AuthSession(
      userId: _userId,
      email: '$_userId@evolua.test',
      roles: const ['ROLE_USER'],
      accessToken: 'test-token',
    );
  }
}

class _FakeTrailRepository implements TrailRepository {
  _FakeTrailRepository({
    bool hasActiveTrail = true,
    Trail? activeTrail,
    Trail? catalogTrail,
    List<Trail>? catalogTrails,
    Map<({int trailId, int stepIndex}), String>? initialResponses,
    TrailJourney Function(Trail trail)? journeyBuilder,
    TrailJourney Function(Trail trail)? completeStepJourneyBuilder,
    bool failLoadingResponse = false,
    bool failSavingResponse = false,
    Completer<void>? saveGate,
    Set<int> failingPages = const {},
  }) : _activeTrail = hasActiveTrail
           ? activeTrail ??
                 _trail(
                   id: 1,
                   title: 'Clareza em 8 minutos',
                   summary: 'Uma trilha ativa para organizar o momento.',
                   activeJourney: true,
                   generatedByAi: true,
                 )
           : null,
       _catalogTrails =
           catalogTrails ??
           [
             catalogTrail ??
                 _trail(
                   id: 2,
                   title: 'Respiracao breve',
                   summary: 'Uma trilha curta para voltar ao corpo.',
                   activeJourney: false,
                   generatedByAi: false,
                 ),
           ],
       savedResponses = Map.of(initialResponses ?? const {}),
       _journeyBuilder = journeyBuilder,
       _completeStepJourneyBuilder = completeStepJourneyBuilder,
       _failLoadingResponse = failLoadingResponse,
       _failSavingResponse = failSavingResponse,
       _saveGate = saveGate,
       _failingPages = failingPages;

  final Trail? _activeTrail;
  final List<Trail> _catalogTrails;
  final Map<({int trailId, int stepIndex}), String> savedResponses;
  final TrailJourney Function(Trail trail)? _journeyBuilder;
  final TrailJourney Function(Trail trail)? _completeStepJourneyBuilder;
  final bool _failLoadingResponse;
  final bool _failSavingResponse;
  final Completer<void>? _saveGate;
  final Set<int> _failingPages;
  int listCallCount = 0;
  int completeStepCallCount = 0;
  int saveStepResponseCallCount = 0;
  final requestedPages = <int>[];
  String? lastSearch;
  bool? lastPremium;

  @override
  Future<Trail?> currentJourney() async => _activeTrail;

  @override
  Future<List<TrailJourney>> listInProgressJourneys() async {
    final activeTrail = _activeTrail;
    if (activeTrail == null) {
      return const [];
    }
    return [await journey(activeTrail.id)];
  }

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
    listCallCount++;
    requestedPages.add(page);
    if (_failingPages.contains(page)) {
      throw Exception('page unavailable');
    }
    lastSearch = search;
    lastPremium = premium;
    var items = _catalogTrails;
    if (premium != null) {
      items = items.where((trail) => trail.premium == premium).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final normalized = search.trim().toLowerCase();
      items = items
          .where(
            (trail) =>
                trail.title.toLowerCase().contains(normalized) ||
                trail.summary.toLowerCase().contains(normalized) ||
                trail.category.toLowerCase().contains(normalized),
          )
          .toList();
    }
    final totalPages = items.isEmpty ? 1 : (items.length / size).ceil();
    final start = page * size;
    final pageItems = start >= items.length
        ? <Trail>[]
        : items.skip(start).take(size).toList();
    return PaginatedResponse(
      items: pageItems,
      page: page,
      size: size,
      totalItems: items.length,
      totalPages: totalPages,
      hasNext: page < totalPages - 1,
      hasPrevious: page > 0,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<TrailJourney> journey(int trailId) async {
    final activeTrail = _activeTrail;
    final trail = activeTrail != null && trailId == activeTrail.id
        ? activeTrail
        : _catalogTrails.firstWhere((trail) => trail.id == trailId);
    return (_journeyBuilder ?? _journey)(trail);
  }

  @override
  Future<TrailJourney> startJourney(int trailId) async {
    return journey(trailId);
  }

  @override
  Future<TrailJourney> completeStep(int trailId, int stepIndex) async {
    completeStepCallCount++;
    final completeStepJourneyBuilder = _completeStepJourneyBuilder;
    if (completeStepJourneyBuilder != null) {
      final activeTrail = _activeTrail;
      final trail = activeTrail != null && trailId == activeTrail.id
          ? activeTrail
          : _catalogTrails.firstWhere((trail) => trail.id == trailId);
      return completeStepJourneyBuilder(trail);
    }
    return journey(trailId);
  }

  @override
  Future<TrailJourney> updateVideoProgress({
    required int trailId,
    required int stepIndex,
    required int watchedSeconds,
    required int durationSeconds,
  }) async {
    return journey(trailId);
  }

  @override
  Future<TrailStepResponse?> stepResponse({
    required int trailId,
    required int stepIndex,
  }) async {
    if (_failLoadingResponse) {
      throw Exception('response unavailable');
    }
    final text = savedResponses[(trailId: trailId, stepIndex: stepIndex)];
    if (text == null) {
      return null;
    }
    return _stepResponse(trailId: trailId, stepIndex: stepIndex, text: text);
  }

  @override
  Future<TrailStepResponse> saveStepResponse({
    required int trailId,
    required int stepIndex,
    required String responseText,
  }) async {
    saveStepResponseCallCount++;
    await _saveGate?.future;
    if (_failSavingResponse) {
      throw Exception('save unavailable');
    }
    final text = responseText.trim();
    savedResponses[(trailId: trailId, stepIndex: stepIndex)] = text;
    return _stepResponse(trailId: trailId, stepIndex: stepIndex, text: text);
  }

  @override
  Future<List<TrailStepResponse>> listStepResponses({int limit = 20}) async {
    return savedResponses.entries
        .take(limit)
        .map(
          (entry) => _stepResponse(
            trailId: entry.key.trailId,
            stepIndex: entry.key.stepIndex,
            text: entry.value,
          ),
        )
        .toList();
  }

  @override
  Future<Trail> create({
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(int id) {
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
    required List<TrailStep> steps,
  }) {
    throw UnimplementedError();
  }
}

class _FakeRewardedAdService implements RewardedAdService {
  String? lastRewardType;

  @override
  Future<RewardedAdResult> showRewardedAd({
    required String rewardType,
    String? contextId,
    void Function()? onAdClosed,
  }) async {
    lastRewardType = rewardType;
    return RewardedAdResult.rewarded;
  }
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({this.mentorPassActiveFromCall});

  final int? mentorPassActiveFromCall;
  int currentCallCount = 0;

  @override
  Future<CurrentSubscription?> current() async {
    currentCallCount++;
    final mentorPassActive =
        mentorPassActiveFromCall != null &&
        currentCallCount >= mentorPassActiveFromCall!;
    return CurrentSubscription(
      planCode: 'essential-free',
      status: 'ACTIVE',
      billingCycle: 'MONTHLY',
      premium: false,
      adsEnabled: true,
      aiQuotaRemainingToday: 1,
      mentorPremiumPassActive: mentorPassActive,
      mentorRewardedAdAvailable: !mentorPassActive,
      mentorPremiumPassEndsAt: mentorPassActive ? DateTime(2026, 5, 7) : null,
    );
  }

  @override
  Future<List<PlanView>> listPlans() async => const [];

  @override
  Future<CurrentSubscription?> cancel() async => current();

  @override
  Future<CheckoutSession> checkoutStatus(String checkoutId) {
    throw UnimplementedError();
  }

  @override
  Future<CheckoutSession> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    required String packageName,
    required String planCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> createRewardSession({
    required String rewardType,
    String? contextId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> grantTestReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> grantClientOpenedReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<CheckoutSession> startCheckout({
    required String planCode,
    required String frontendBaseUrl,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MonetizationAccessStatus> monetizationAccess({
    required String resource,
    String? contextId,
  }) async {
    return MonetizationAccessStatus(
      resource: resource,
      contextId: contextId,
      allowed: false,
      premium: false,
      rewardedAdAvailable: true,
      upgradeRecommended: true,
    );
  }
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<Profile?> getMe() async => null;

  @override
  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) {
    throw UnimplementedError();
  }
}

Trail _trail({
  required int id,
  required String title,
  required String summary,
  required bool activeJourney,
  required bool generatedByAi,
  String category = 'clareza',
  bool premium = false,
  bool accessible = true,
  String? sourceStyle = 'briefing',
}) {
  return Trail(
    id: id,
    userId: 'user-123',
    title: title,
    summary: summary,
    content: 'Respire, nomeie e escolha.',
    category: category,
    premium: premium,
    privateTrail: false,
    activeJourney: activeJourney,
    generatedByAi: generatedByAi,
    journeyKey: 'clareza',
    sourceStyle: sourceStyle,
    accessible: accessible,
    mediaLinks: const [],
    steps: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}

List<Trail> _catalogTrailSet(int count) {
  return List.generate(
    count,
    (index) => _trail(
      id: index + 2,
      title: 'Trilha catalogo ${index + 1}',
      summary: 'Resumo da trilha ${index + 1}.',
      activeJourney: false,
      generatedByAi: false,
    ),
  );
}

TrailJourney _journey(Trail trail) {
  final steps = [
    const TrailJourneyStep(
      index: 0,
      title: 'Respirar',
      summary: 'Dois minutos de presenca.',
      content: 'Respire por quatro ciclos.',
      type: 'EXERCISE',
      status: 'current',
      estimatedMinutes: 2,
      mediaLinks: [],
    ),
    const TrailJourneyStep(
      index: 1,
      title: 'Escolher',
      summary: 'Uma proxima acao simples.',
      content: 'Escolha uma acao pequena.',
      type: 'REFLECTION',
      status: 'pending',
      estimatedMinutes: 4,
      mediaLinks: [],
    ),
  ];

  return TrailJourney(
    trail: trail,
    steps: steps,
    progress: TrailProgress(
      currentStepIndex: 0,
      completedStepIndexes: const [],
      startedAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      completedAt: null,
    ),
    progressPercent: 0,
    nextStep: steps.first,
  );
}

TrailJourney _journeyAfterFirstStep(Trail trail) {
  final steps = [
    const TrailJourneyStep(
      index: 0,
      title: 'Respirar',
      summary: 'Dois minutos de presenca.',
      content: 'Respire por quatro ciclos.',
      type: 'EXERCISE',
      status: 'completed',
      estimatedMinutes: 2,
      mediaLinks: [],
    ),
    const TrailJourneyStep(
      index: 1,
      title: 'Escolher',
      summary: 'Uma proxima acao simples.',
      content: 'Escolha uma acao pequena.',
      type: 'REFLECTION',
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

TrailJourney _completedByStepsJourney(Trail trail) {
  final steps = [
    const TrailJourneyStep(
      index: 0,
      title: 'Respirar',
      summary: 'Dois minutos de presenca.',
      content: 'Respire por quatro ciclos.',
      type: 'EXERCISE',
      status: 'completed',
      estimatedMinutes: 2,
      mediaLinks: [],
    ),
    const TrailJourneyStep(
      index: 1,
      title: 'Escolher',
      summary: 'Uma proxima acao simples.',
      content: 'Escolha uma acao pequena.',
      type: 'REFLECTION',
      status: 'completed',
      estimatedMinutes: 4,
      mediaLinks: [],
    ),
  ];

  return TrailJourney(
    trail: trail,
    steps: steps,
    progress: TrailProgress(
      currentStepIndex: 1,
      completedStepIndexes: const [0, 1],
      startedAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      completedAt: null,
    ),
    progressPercent: 100,
    nextStep: null,
  );
}

TrailJourney _emptyStepsJourney(Trail trail) {
  return TrailJourney(
    trail: trail,
    steps: const [],
    progress: TrailProgress(
      currentStepIndex: 0,
      completedStepIndexes: const [],
      startedAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      completedAt: null,
    ),
    progressPercent: 0,
    nextStep: null,
  );
}

TrailJourney _videoJourney(Trail trail) {
  final steps = [
    const TrailJourneyStep(
      index: 0,
      title: 'Assistir',
      summary: 'Uma prática em vídeo.',
      content: 'Assista ao vídeo com calma.',
      type: 'VIDEO',
      status: 'current',
      estimatedMinutes: 5,
      mediaLinks: [],
    ),
  ];

  return TrailJourney(
    trail: trail,
    steps: steps,
    progress: TrailProgress(
      currentStepIndex: 0,
      completedStepIndexes: const [],
      startedAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      completedAt: null,
    ),
    progressPercent: 0,
    nextStep: steps.first,
  );
}

TrailJourney _audioJourney(Trail trail) {
  final steps = [
    const TrailJourneyStep(
      index: 0,
      title: 'Ouvir',
      summary: 'Uma prática em áudio.',
      content: 'Ouça a orientação com calma.',
      type: 'AUDIO',
      status: 'current',
      estimatedMinutes: 5,
      mediaLinks: [],
    ),
  ];

  return TrailJourney(
    trail: trail,
    steps: steps,
    progress: TrailProgress(
      currentStepIndex: 0,
      completedStepIndexes: const [],
      startedAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      completedAt: null,
    ),
    progressPercent: 0,
    nextStep: steps.first,
  );
}

TrailJourney _readingJourney(Trail trail) {
  final steps = [
    const TrailJourneyStep(
      index: 0,
      title: 'Ler',
      summary: 'Uma leitura breve.',
      content: 'Leia o conteúdo com calma.',
      type: 'READING',
      status: 'current',
      estimatedMinutes: 5,
      mediaLinks: [],
    ),
  ];

  return TrailJourney(
    trail: trail,
    steps: steps,
    progress: TrailProgress(
      currentStepIndex: 0,
      completedStepIndexes: const [],
      startedAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      completedAt: null,
    ),
    progressPercent: 0,
    nextStep: steps.first,
  );
}

TrailStepResponse _stepResponse({
  required int trailId,
  required int stepIndex,
  required String text,
}) {
  final now = DateTime(2026, 1, 2, 9);
  return TrailStepResponse(
    id: stepIndex + 1,
    trailId: trailId,
    journeyKey: 'clareza',
    stepIndex: stepIndex,
    stepTitle: stepIndex == 0 ? 'Respirar' : 'Escolher',
    stepType: stepIndex == 0 ? 'EXERCISE' : 'REFLECTION',
    responseText: text,
    createdAt: now,
    updatedAt: now,
  );
}
