import 'dart:async';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_speech_transcription_service.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:evolua_frontend/features/emotional/presentation/pages/check_in_quick_page.dart';
import 'package:evolua_frontend/features/notification/application/local_check_in_reminder_controller.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((field) => field.textCapitalization),
        everyElement(TextCapitalization.sentences),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descreva com suas palavras'),
        'saudade tranquila',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.createdMood, 'saudade tranquila');
    });

    testWidgets('saves check-in even when intelligent reading is pending', (
      tester,
    ) async {
      var completed = false;
      final repository = _FakeCheckInRepository(createWithoutInsight: true);

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          onCompleted: () => completed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'quero registrar antes da leitura',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.createCalls, 1);
      expect(repository.createdReflection, 'quero registrar antes da leitura');
      expect(completed, isTrue);
      expect(find.textContaining('leitura aparecer'), findsOneWidget);
    });

    testWidgets('network failure shows friendly server message', (
      tester,
    ) async {
      final repository = _FakeCheckInRepository(failCreateCallWithNetwork: 1);

      await tester.pumpWidget(_testApp(checkInRepository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fazer check-in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining('temporariamente indisponível'),
        findsOneWidget,
      );
    });

    testWidgets('blocks repeated save taps and back while saving', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repository = _FakeCheckInRepository(createGate: gate);
      var completed = false;
      var canceled = false;

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          onCompleted: () => completed = true,
          onCancel: () => canceled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'preciso registrar sem duplicar',
      );

      await tester.tap(find.text('Fazer check-in'));
      await tester.tap(find.text('Fazer check-in'), warnIfMissed: false);
      await tester.tap(find.text('Fazer check-in'), warnIfMissed: false);
      await tester.pump();

      expect(repository.createCalls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.textContaining('Agora'), warnIfMissed: false);
      await tester.pump();
      expect(canceled, isFalse);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
        find.textContaining('Estamos salvando seu check-in'),
        findsOneWidget,
      );
      expect(completed, isFalse);

      gate.complete();
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(completed, isTrue);
      expect(canceled, isFalse);
    });

    testWidgets('free text fields start sentences with capitalization', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      final reflectionField = tester.widget<TextField>(find.byType(TextField));

      expect(reflectionField.textCapitalization, TextCapitalization.sentences);
    });

    testWidgets('microphone fills reflection without auto-saving', (
      tester,
    ) async {
      final repository = _FakeCheckInRepository();
      final speech = _FakeCheckInSpeechTranscriptionService();

      await tester.pumpWidget(
        _testApp(checkInRepository: repository, speechService: speech),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Usar microfone'), findsOneWidget);

      await tester.tap(find.byTooltip('Usar microfone'));
      await tester.pumpAndSettle();

      expect(speech.initializeCalls, 1);
      expect(speech.listenCalls, 1);
      expect(find.byTooltip('Parar ditado'), findsOneWidget);

      speech.emitResult('preciso de calma');
      await tester.pump();

      expect(find.text('preciso de calma'), findsOneWidget);
      expect(repository.createCalls, 0);

      await tester.enterText(
        find.byType(TextFormField).first,
        'texto revisado',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.createdReflection, 'texto revisado');
    });

    testWidgets('microphone unavailable shows friendly snackbar', (
      tester,
    ) async {
      final speech = _FakeCheckInSpeechTranscriptionService(available: false);

      await tester.pumpWidget(_testApp(speechService: speech));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Usar microfone'));
      await tester.pumpAndSettle();

      expect(speech.initializeCalls, 1);
      expect(speech.listenCalls, 0);
      expect(
        find.textContaining('O microfone não está disponível'),
        findsOneWidget,
      );
      expect(find.byTooltip('Usar microfone'), findsOneWidget);
    });

    testWidgets(
      'active dictation is cancelled when check-in view is disposed',
      (tester) async {
        final speech = _FakeCheckInSpeechTranscriptionService();

        await tester.pumpWidget(_testApp(speechService: speech));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Usar microfone'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        expect(speech.cancelCalls, 1);
      },
    );

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(
        find.byType(TextFormField),
        'preciso organizar o dia',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.createdMood, 'calma');
      expect(repository.createdReflection, 'preciso organizar o dia');
      expect(repository.createdEnergy, 7);
      expect(completed, isTrue);
    });

    testWidgets('invites daily reminder after first compact check-in', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final scheduler = _FakeDailyReminderScheduler();
      var completed = false;
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _testApp(
          sharedPreferences: preferences,
          reminderScheduler: scheduler,
          onCompleted: () => completed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fazer check-in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('lembrete leve'), findsOneWidget);

      await tester.tap(find.text('Ativar lembrete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(scheduler.permissionRequests, 1);
      expect(scheduler.scheduledTimes, ['08:00']);
      expect(completed, isTrue);
    });

    testWidgets('dismisses daily reminder invite only once', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final scheduler = _FakeDailyReminderScheduler();
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _testApp(sharedPreferences: preferences, reminderScheduler: scheduler),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fazer check-in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Agora não').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(scheduler.scheduledTimes, isEmpty);
      expect(
        preferences.getString(dailyCheckInReminderStorageKey),
        contains('"promptAnswered":true'),
      );
    });

    testWidgets(
      'unlocks extra free check-in with rewarded ad and retries submit',
      (tester) async {
        final repository = _FakeCheckInRepository(
          blockFirstCreateWith402: true,
        );
        final rewarded = _FakeRewardedAdService(
          result: true,
          delay: const Duration(milliseconds: 700),
        );

        await tester.pumpWidget(
          _testApp(
            checkInRepository: repository,
            rewardedAdService: rewarded,
            subscriptionRepository: _FakeSubscriptionRepository(
              accessAllowed: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          'preciso registrar outro momento',
        );
        await tester.tap(find.text('Fazer check-in'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Desbloquear novo check-in hoje'), findsOneWidget);

        await tester.tap(find.text('Assistir anúncio'));
        await tester.pump();
        expect(find.textContaining('Carregando'), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Assinar Premium'),
              )
              .onPressed,
          isNull,
        );

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(rewarded.rewardType, 'DEEP_EMOTIONAL_READING');
        expect(rewarded.allowClientOpenedFallback, isTrue);
        expect(repository.createCalls, 2);
        expect(repository.createdReflection, 'preciso registrar outro momento');
        expect(find.text('Desbloquear novo check-in hoje'), findsNothing);
      },
    );

    testWidgets('keeps unlock flow until rewarded result completes', (
      tester,
    ) async {
      final repository = _FakeCheckInRepository(blockFirstCreateWith402: true);
      final rewarded = _FakeRewardedAdService(
        result: true,
        delay: const Duration(milliseconds: 800),
        closeAfter: Duration.zero,
      );

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          rewardedAdService: rewarded,
          subscriptionRepository: _FakeSubscriptionRepository(
            accessAllowed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'preciso registrar outro momento',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pumpAndSettle();

      expect(find.text('Desbloquear novo check-in hoje'), findsOneWidget);

      await tester.tap(find.text('Assistir anúncio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(rewarded.adClosedCallbacks, 1);
      expect(find.text('Desbloquear novo check-in hoje'), findsOneWidget);
      expect(repository.createCalls, 1);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Desbloquear novo check-in hoje'), findsNothing);
      expect(repository.createCalls, 2);
    });

    testWidgets('keeps rewarded button loading during automatic submit', (
      tester,
    ) async {
      final submitGate = Completer<void>();
      final repository = _FakeCheckInRepository(
        blockFirstCreateWith402: true,
        createGate: submitGate,
      );
      final rewarded = _FakeRewardedAdService(result: true);

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          rewardedAdService: rewarded,
          subscriptionRepository: _FakeSubscriptionRepository(
            accessAllowed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'preciso registrar outro momento',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assistir anúncio'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Desbloquear novo check-in hoje'), findsOneWidget);
      expect(find.textContaining('Carregando'), findsOneWidget);
      expect(find.text('Assistir anúncio'), findsNothing);
      expect(repository.createCalls, 2);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Assinar Premium'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.textContaining('Carregando'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.createCalls, 2);

      submitGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Desbloquear novo check-in hoje'), findsNothing);
    });

    testWidgets('restores rewarded button after automatic submit failure', (
      tester,
    ) async {
      final repository = _FakeCheckInRepository(
        blockFirstCreateWith402: true,
        failCreateCallWithNetwork: 2,
      );
      final rewarded = _FakeRewardedAdService(result: true);

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          rewardedAdService: rewarded,
          subscriptionRepository: _FakeSubscriptionRepository(
            accessAllowed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'preciso registrar outro momento',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assistir anúncio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 2);
      expect(find.text('Desbloquear novo check-in hoje'), findsOneWidget);
      if (find.text('Entendi').evaluate().isNotEmpty) {
        await tester.tap(find.text('Entendi'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Assistir anúncio'), findsOneWidget);
      await tester.tap(find.text('Assistir anúncio'));
      await tester.pumpAndSettle();
      expect(repository.createCalls, 3);
    });

    testWidgets('reward failure follows existing retry flow', (tester) async {
      final repository = _FakeCheckInRepository(blockFirstCreateWith402: true);
      final rewarded = _FakeRewardedAdService(
        result: false,
        delay: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          rewardedAdService: rewarded,
          subscriptionRepository: _FakeSubscriptionRepository(
            accessAllowed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'preciso registrar outro momento',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assistir anúncio'));
      await tester.pump();
      expect(find.textContaining('Carregando'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Desbloquear novo check-in hoje'), findsNothing);
      expect(repository.createCalls, 2);
    });

    testWidgets('second 402 after reward shows friendly confirmation message', (
      tester,
    ) async {
      final repository = _FakeCheckInRepository(blockCreateCountWith402: 2);
      final rewarded = _FakeRewardedAdService(result: true);

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          rewardedAdService: rewarded,
          subscriptionRepository: _FakeSubscriptionRepository(
            accessAllowed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'preciso registrar outro momento',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assistir anúncio'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 2);
    });

    testWidgets(
      'after daily rewarded credit is used only shows premium action',
      (tester) async {
        final repository = _FakeCheckInRepository(
          blockFirstCreateWith402: true,
        );

        await tester.pumpWidget(
          _testApp(
            checkInRepository: repository,
            subscriptionRepository: _FakeSubscriptionRepository(
              accessAllowed: false,
              rewardedAdAvailable: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          'mais um registro do dia',
        );
        await tester.tap(find.text('Fazer check-in'));
        await tester.pumpAndSettle();

        expect(find.text('Desbloquear novo check-in hoje'), findsOneWidget);
        expect(find.textContaining('desbloqueio por'), findsOneWidget);
        expect(find.textContaining('Assistir'), findsNothing);
        expect(find.text('Assinar Premium'), findsOneWidget);
      },
    );
  });
}

Widget _testApp({
  CheckInRepository? checkInRepository,
  RewardedAdService? rewardedAdService,
  SubscriptionRepository? subscriptionRepository,
  DailyCheckInReminderScheduler? reminderScheduler,
  SharedPreferences? sharedPreferences,
  CheckInSpeechTranscriptionService? speechService,
  VoidCallback? onCompleted,
  VoidCallback? onCancel,
}) {
  return ProviderScope(
    overrides: [
      if (sharedPreferences != null)
        sharedPreferencesProvider.overrideWith(
          (ref) async => sharedPreferences,
        ),
      checkInRepositoryProvider.overrideWithValue(
        checkInRepository ?? _FakeCheckInRepository(),
      ),
      if (rewardedAdService != null)
        rewardedAdServiceProvider.overrideWithValue(rewardedAdService),
      if (subscriptionRepository != null)
        subscriptionRepositoryProvider.overrideWithValue(
          subscriptionRepository,
        ),
      if (reminderScheduler != null)
        dailyCheckInReminderSchedulerProvider.overrideWithValue(
          reminderScheduler,
        ),
      if (speechService != null)
        checkInSpeechTranscriptionServiceProvider.overrideWithValue(
          speechService,
        ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CheckInQuickView(onCompleted: onCompleted, onCancel: onCancel),
        ),
      ),
    ),
  );
}

class _FakeDailyReminderScheduler implements DailyCheckInReminderScheduler {
  int permissionRequests = 0;
  final List<String> scheduledTimes = [];

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> consumePendingCheckInPayload() async => false;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduledTimes.add(
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    );
  }
}

class _FakeCheckInSpeechTranscriptionService
    implements CheckInSpeechTranscriptionService {
  _FakeCheckInSpeechTranscriptionService({this.available = true});

  final bool available;
  int initializeCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  bool _isListening = false;
  void Function(String text)? _onResult;
  void Function(String status)? _onStatus;
  void Function(Object error)? _onError;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> initialize({
    required String localeId,
    required void Function(String status) onStatus,
    required void Function(Object error) onError,
  }) async {
    initializeCalls++;
    _onStatus = onStatus;
    _onError = onError;
    return available;
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String text) onResult,
  }) async {
    listenCalls++;
    _onResult = onResult;
    _isListening = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _isListening = false;
    _onStatus?.call('notListening');
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    _isListening = false;
  }

  void emitResult(String text) {
    _onResult?.call(text);
  }

  void emitError(Object error) {
    _onError?.call(error);
  }
}

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository({
    List<CheckIn>? items,
    this.blockFirstCreateWith402 = false,
    this.blockCreateCountWith402 = 0,
    this.createGate,
    this.failCreateCallWithNetwork,
    this.createWithoutInsight = false,
  }) : items = items ?? _checkIns();

  final List<CheckIn> items;
  final bool blockFirstCreateWith402;
  final int blockCreateCountWith402;
  final Completer<void>? createGate;
  final int? failCreateCallWithNetwork;
  final bool createWithoutInsight;
  int createCalls = 0;
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
    createCalls++;
    if ((blockFirstCreateWith402 && createCalls == 1) ||
        createCalls <= blockCreateCountWith402) {
      final requestOptions = RequestOptions(path: '/v1/check-ins');
      throw DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 402,
          data: const {
            'message':
                'Você já fez o check-in gratuito de hoje. Assista a um anúncio, assine Premium ou volte amanhã.',
          },
        ),
      );
    }
    final shouldWaitForGate =
        createGate != null &&
        ((blockFirstCreateWith402 && createCalls == 2) ||
            (blockCreateCountWith402 > 0 &&
                createCalls == blockCreateCountWith402 + 1) ||
            (!blockFirstCreateWith402 &&
                blockCreateCountWith402 == 0 &&
                createCalls == 1));
    if (shouldWaitForGate) {
      await createGate?.future;
    }
    if (createCalls == failCreateCallWithNetwork) {
      final requestOptions = RequestOptions(path: '/v1/check-ins');
      throw DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 503,
          data: const {'message': 'Falha temporaria.'},
        ),
      );
    }
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
      aiInsight: createWithoutInsight ? null : _insight(),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<CheckIn> generateDeepReading(
    int checkInId, {
    String style = 'deep',
  }) async {
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

  @override
  Future<CheckIn> saveReading(int checkInId) async {
    return generateDeepReading(checkInId);
  }

  @override
  Future<void> createRitualFromReading(
    int checkInId, {
    required DateTime localDate,
    required String type,
  }) async {}
}

class _FakeRewardedAdService implements RewardedAdService {
  _FakeRewardedAdService({
    required this.result,
    this.delay = Duration.zero,
    this.closeAfter,
  });

  final bool result;
  final Duration delay;
  final Duration? closeAfter;
  String? rewardType;
  bool? allowClientOpenedFallback;
  int adClosedCallbacks = 0;

  @override
  Future<bool> showRewardedAd({
    required String rewardType,
    String? contextId,
    bool allowClientOpenedFallback = false,
    void Function()? onAdClosed,
  }) async {
    this.rewardType = rewardType;
    this.allowClientOpenedFallback = allowClientOpenedFallback;
    final closeAfter = this.closeAfter;
    if (closeAfter != null) {
      await Future<void>.delayed(closeAfter);
      adClosedCallbacks++;
      onAdClosed?.call();
      final remainingDelay = delay - closeAfter;
      if (remainingDelay > Duration.zero) {
        await Future<void>.delayed(remainingDelay);
      }
      return result;
    }
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return result;
  }
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({
    required this.accessAllowed,
    bool? rewardedAdAvailable,
  }) : rewardedAdAvailable = rewardedAdAvailable ?? !accessAllowed;

  final bool accessAllowed;
  final bool rewardedAdAvailable;

  @override
  Future<CurrentSubscription?> cancel() async => null;

  @override
  Future<CheckoutSession> checkoutStatus(String checkoutId) {
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
  Future<CurrentSubscription?> current() async => null;

  @override
  Future<AdRewardSession> grantTestReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> grantClientOpenedReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<PlanView>> listPlans() async => const [];

  @override
  Future<MonetizationAccessStatus> monetizationAccess({
    required String resource,
    String? contextId,
  }) async {
    return MonetizationAccessStatus(
      resource: resource,
      contextId: contextId,
      allowed: accessAllowed,
      premium: false,
      rewardedAdAvailable: rewardedAdAvailable,
      upgradeRecommended: !accessAllowed,
      entitlementExpiresAt: accessAllowed
          ? DateTime.now().add(const Duration(hours: 2))
          : null,
    );
  }

  @override
  Future<CheckoutSession> startCheckout({
    required String planCode,
    required String frontendBaseUrl,
  }) {
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
