import 'dart:async';

import 'package:evolua_frontend/features/care/application/care_claim_controller.dart';
import 'package:evolua_frontend/features/care/presentation/pages/care_claim_page.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders therapist portal on mobile without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetViewInsets);

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
    expect(
      find.text(
        'Anexos aceitos: PDF, JPG, PNG ou WebP, até 10 MB por arquivo.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('clÃ'), findsNothing);
    expect(find.textContaining('relatÃ'), findsNothing);
    expect(find.textContaining('nÃ'), findsNothing);
    final freeTextFields = tester.widgetList<TextField>(find.byType(TextField));
    expect(freeTextFields, hasLength(4));
    expect(
      freeTextFields.map((field) => field.textCapitalization),
      everyElement(TextCapitalization.sentences),
    );
  });
  testWidgets('keeps recommendation guidance field usable after mobile focus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetViewInsets);

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

    final guidanceField = find.byType(TextField).last;
    await tester.ensureVisible(guidanceField);
    tester.view.viewInsets = FakeViewPadding(bottom: 320);
    await tester.tap(guidanceField);
    await tester.enterText(guidanceField, 'orientacao de teste');
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('orientacao de teste'), findsOneWidget);

    tester.view.resetViewInsets();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('orientacao de teste'), findsOneWidget);
  });

  testWidgets('keeps prescription fields visible with keyboard insets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetViewInsets);

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

    tester.view.viewInsets = FakeViewPadding(bottom: 320);
    await tester.pump(const Duration(milliseconds: 320));

    final fields = find.byType(TextField);
    for (var index = 0; index < 3; index++) {
      final field = fields.at(index);
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.enterText(field, 'texto de teste $index');
      await tester.pump(const Duration(milliseconds: 360));

      expect(tester.takeException(), isNull);
      expect(find.text('texto de teste $index'), findsOneWidget);
    }
  });

  testWidgets('keeps dark background after native keyboard dismiss', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetViewInsets);

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

    final microActionField = find.byType(TextField).at(2);
    tester.view.viewInsets = FakeViewPadding(bottom: 320);
    await tester.ensureVisible(microActionField);
    await tester.tap(microActionField);
    await tester.enterText(microActionField, 'respirar antes de mensagens');
    await tester.pump(const Duration(milliseconds: 320));

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('respirar antes de mensagens'), findsOneWidget);
    expect(find.text('Prescrever ritual personalizado'), findsOneWidget);
    expect(find.byType(CareClaimPage), findsOneWidget);
  });

  testWidgets(
    'keyboard hide chevron preserves focused form and valid scroll bounds',
    (tester) async {
      final picker = _installFakeFilePicker();
      final controller = _FakeCareClaimController(_claimState());
      picker.nextResult = FilePickerResult([
        PlatformFile(
          name: 'plano.pdf',
          size: 128,
          bytes: Uint8List.fromList(List.filled(128, 1)),
        ),
      ]);

      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            careClaimControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(home: CareClaimPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Adicionar anexos'));
      await tester.tap(find.text('Adicionar anexos'));
      await tester.pumpAndSettle();

      tester.view.viewInsets = FakeViewPadding(bottom: 320);
      final microActionField = find.byType(TextField).at(2);
      await tester.ensureVisible(microActionField);
      await tester.tap(microActionField);
      await tester.enterText(microActionField, 'respirar antes de mensagens');

      final guidanceField = find.byType(TextField).last;
      await tester.ensureVisible(guidanceField);
      await tester.tap(guidanceField);
      await tester.enterText(guidanceField, 'orientacao mantida');
      await tester.pump(const Duration(milliseconds: 320));

      final guidanceWidget = tester.widget<TextField>(guidanceField);
      expect(guidanceWidget.focusNode?.hasFocus, isTrue);

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.pumpAndSettle();

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      final position = scrollView.controller!.position;

      expect(tester.takeException(), isNull);
      expect(find.byType(CareClaimPage), findsOneWidget);
      expect(find.text('Abrindo acesso seguro...'), findsNothing);
      expect(find.text('respirar antes de mensagens'), findsOneWidget);
      expect(find.text('orientacao mantida'), findsOneWidget);
      expect(find.text('plano.pdf'), findsOneWidget);
      expect(find.textContaining('Recomenda'), findsWidgets);
      expect(guidanceWidget.focusNode?.hasFocus, isTrue);
      expect(
        position.pixels,
        inInclusiveRange(position.minScrollExtent, position.maxScrollExtent),
      );
      expect(controller.buildCalls, 1);
      expect(controller.recommendationCalls, 0);
    },
  );

  testWidgets(
    'native keyboard back only dismisses focused prescription field',
    (tester) async {
      if (kIsWeb) {
        return;
      }
      final controller = _FakeCareClaimController(_claimState());

      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            careClaimControllerProvider.overrideWith(() => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CareClaimPage(),
                          ),
                        );
                      },
                      child: const Text('open claim'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open claim'));
      await tester.pumpAndSettle();

      final microActionField = find.byType(TextField).at(2);
      tester.view.viewInsets = FakeViewPadding(bottom: 320);
      await tester.ensureVisible(microActionField);
      await tester.tap(microActionField);
      await tester.enterText(microActionField, 'respirar antes de mensagens');
      await tester.pump(const Duration(milliseconds: 320));

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byType(CareClaimPage), findsOneWidget);
      expect(find.text('Abrindo acesso seguro...'), findsNothing);
      expect(find.text('respirar antes de mensagens'), findsOneWidget);
      expect(controller.buildCalls, 1);
      expect(controller.recommendationCalls, 0);

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('open claim'), findsOneWidget);
    },
  );

  testWidgets(
    'native keyboard back preserves guidance text and selected attachment',
    (tester) async {
      if (kIsWeb) {
        return;
      }
      final picker = _installFakeFilePicker();
      final controller = _FakeCareClaimController(_claimState());
      picker.nextResult = FilePickerResult([
        PlatformFile(
          name: 'plano.pdf',
          size: 128,
          bytes: Uint8List.fromList(List.filled(128, 1)),
        ),
      ]);

      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            careClaimControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(home: CareClaimPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Adicionar anexos'));
      await tester.tap(find.text('Adicionar anexos'));
      await tester.pumpAndSettle();

      final guidanceField = find.byType(TextField).last;
      tester.view.viewInsets = FakeViewPadding(bottom: 320);
      await tester.ensureVisible(guidanceField);
      await tester.tap(guidanceField);
      await tester.enterText(guidanceField, 'orientacao mantida');
      await tester.pump(const Duration(milliseconds: 320));

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byType(CareClaimPage), findsOneWidget);
      expect(find.text('Abrindo acesso seguro...'), findsNothing);
      expect(find.text('orientacao mantida'), findsOneWidget);
      expect(find.text('plano.pdf'), findsOneWidget);
      expect(controller.buildCalls, 1);
      expect(controller.recommendationCalls, 0);
    },
  );

  testWidgets('web browser back is not intercepted by focused input', (
    tester,
  ) async {
    if (!kIsWeb) {
      return;
    }
    final controller = _FakeCareClaimController(_claimState());

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [careClaimControllerProvider.overrideWith(() => controller)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CareClaimPage(),
                        ),
                      );
                    },
                    child: const Text('open claim'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open claim'));
    await tester.pumpAndSettle();

    final guidanceField = find.byType(TextField).last;
    tester.view.viewInsets = FakeViewPadding(bottom: 320);
    await tester.ensureVisible(guidanceField);
    await tester.tap(guidanceField);
    await tester.enterText(guidanceField, 'orientacao mantida');
    await tester.pump(const Duration(milliseconds: 320));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('open claim'), findsOneWidget);
    expect(find.byType(CareClaimPage), findsNothing);
    expect(controller.buildCalls, 1);
    expect(controller.recommendationCalls, 0);
  });

  testWidgets(
    'keeps loaded form state during transient claim loading after keyboard metrics',
    (tester) async {
      final picker = _installFakeFilePicker();
      final controller = _FakeCareClaimController(_claimState());
      picker.nextResult = FilePickerResult([
        PlatformFile(
          name: 'plano.pdf',
          size: 128,
          bytes: Uint8List.fromList(List.filled(128, 1)),
        ),
      ]);

      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            careClaimControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(home: CareClaimPage()),
        ),
      );
      await tester.pumpAndSettle();

      final microActionField = find.byType(TextField).at(2);
      await tester.ensureVisible(microActionField);
      tester.view.viewInsets = FakeViewPadding(bottom: 320);
      await tester.tap(microActionField);
      await tester.enterText(microActionField, 'respirar antes de mensagens');
      await tester.pump(const Duration(milliseconds: 320));

      final guidanceField = find.byType(TextField).last;
      await tester.ensureVisible(guidanceField);
      await tester.enterText(guidanceField, 'orientacao mantida');

      await tester.ensureVisible(find.text('Adicionar anexos'));
      await tester.tap(find.text('Adicionar anexos'));
      await tester.pumpAndSettle();
      expect(find.text('plano.pdf'), findsOneWidget);

      tester.view.resetViewInsets();
      controller.showTransientLoading();
      await tester.pump();

      expect(find.text('Abrindo acesso seguro...'), findsNothing);
      expect(find.text('Prescrever ritual personalizado'), findsOneWidget);
      expect(find.text('respirar antes de mensagens'), findsOneWidget);
      expect(find.text('orientacao mantida'), findsOneWidget);
      expect(find.text('plano.pdf'), findsOneWidget);
      expect(controller.buildCalls, 1);
      expect(controller.recommendationCalls, 0);
    },
  );

  testWidgets('valid attachment appears and can be removed', (tester) async {
    final picker = _installFakeFilePicker();

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    picker.nextResult = FilePickerResult([
      PlatformFile(
        name: 'plano.pdf',
        size: 128,
        bytes: Uint8List.fromList(List.filled(128, 1)),
      ),
    ]);

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

    await tester.ensureVisible(find.text('Adicionar anexos'));
    await tester.tap(find.text('Adicionar anexos'));
    await tester.pumpAndSettle();

    expect(find.text('plano.pdf'), findsOneWidget);
    expect(find.textContaining('Aguardando envio'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover anexo'));
    await tester.pumpAndSettle();

    expect(find.text('plano.pdf'), findsNothing);
  });

  testWidgets('invalid attachments show friendly messages and are not listed', (
    tester,
  ) async {
    final picker = _installFakeFilePicker();

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

    picker.nextResult = FilePickerResult([
      PlatformFile(
        name: 'notas.txt',
        size: 10,
        bytes: Uint8List.fromList(List.filled(10, 1)),
      ),
    ]);
    await tester.ensureVisible(find.text('Adicionar anexos'));
    await tester.tap(find.text('Adicionar anexos'));
    await tester.pump();

    expect(
      find.text('Formato não suportado. Envie uma imagem ou PDF.'),
      findsOneWidget,
    );
    expect(find.text('notas.txt'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    picker.nextResult = FilePickerResult([
      PlatformFile(
        name: 'foto.png',
        size: 10 * 1024 * 1024 + 1,
        bytes: Uint8List(1),
      ),
    ]);
    await tester.ensureVisible(find.text('Adicionar anexos'));
    await tester.tap(find.text('Adicionar anexos'));
    await tester.pumpAndSettle();

    expect(find.text('foto.png'), findsNothing);
  });

  testWidgets('attachment submit shows loading and blocks duplicate submit', (
    tester,
  ) async {
    final picker = _installFakeFilePicker();

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final gate = Completer<void>();
    final controller = _FakeCareClaimController(
      _claimState(),
      recommendationGate: gate,
    );
    picker.nextResult = FilePickerResult([
      PlatformFile(
        name: 'orientacao.pdf',
        size: 256,
        bytes: Uint8List.fromList(List.filled(256, 2)),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [careClaimControllerProvider.overrideWith(() => controller)],
        child: const MaterialApp(home: CareClaimPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Adicionar anexos'));
    await tester.tap(find.text('Adicionar anexos'));
    await tester.pumpAndSettle();
    final submitButton = find.textContaining('Enviar orient');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(controller.recommendationCalls, 1);
    expect(find.textContaining('Enviando...'), findsWidgets);

    gate.complete();
    await tester.pumpAndSettle();

    expect(controller.recommendationCalls, 1);
    expect(find.text('orientacao.pdf'), findsNothing);
  });

  testWidgets('attachment failure preserves text and retry state', (
    tester,
  ) async {
    final picker = _installFakeFilePicker();

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _FakeCareClaimController(
      _claimState(),
      failRecommendation: true,
    );
    picker.nextResult = FilePickerResult([
      PlatformFile(
        name: 'relatorio.webp',
        size: 64,
        bytes: Uint8List.fromList(List.filled(64, 3)),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [careClaimControllerProvider.overrideWith(() => controller)],
        child: const MaterialApp(home: CareClaimPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Adicionar anexos'));
    await tester.tap(find.text('Adicionar anexos'));
    await tester.pumpAndSettle();

    final guidanceField = find.byType(TextField).last;
    await tester.ensureVisible(guidanceField);
    await tester.enterText(guidanceField, 'orientacao mantida');
    final submitButton = find.textContaining('Enviar orient');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(controller.recommendationCalls, 1);
    expect(find.text('orientacao mantida'), findsOneWidget);
    expect(find.text('relatorio.webp'), findsOneWidget);
    expect(find.textContaining('Falha no envio'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}

class _FakeCareClaimController extends CareClaimController {
  _FakeCareClaimController(
    this._state, {
    this.failRecommendation = false,
    this.recommendationGate,
  });

  final CareClaimState _state;
  final bool failRecommendation;
  final Completer<void>? recommendationGate;
  int buildCalls = 0;
  int recommendationCalls = 0;

  @override
  Future<CareClaimState> build() async {
    buildCalls += 1;
    return _state;
  }

  void showTransientLoading() {
    state = const AsyncLoading();
  }

  @override
  Future<void> sendPrescription({
    required String type,
    required DateTime localDate,
    required String emotionalState,
    required String intention,
    required String microAction,
  }) async {}

  @override
  Future<void> sendRecommendation({
    required String guidanceText,
    required List<PlatformFile> attachments,
  }) async {
    recommendationCalls += 1;
    await recommendationGate?.future;
    if (failRecommendation) {
      throw Exception('upload failed');
    }
  }
}

_FakeFilePicker _installFakeFilePicker() {
  final picker = _FakeFilePicker();
  FilePicker.platform = picker;
  return picker;
}

class _FakeFilePicker extends FilePicker {
  FilePickerResult? nextResult;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return nextResult;
  }
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
