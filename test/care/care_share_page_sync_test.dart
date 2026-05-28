import 'dart:async';
import 'dart:convert';

import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/application/care_recommendation_handler.dart';
import 'package:evolua_frontend/features/care/application/care_secret_store.dart';
import 'package:evolua_frontend/features/care/application/care_share_controller.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_access_status.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_prescription_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_recommendation_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_share_session.dart';
import 'package:evolua_frontend/features/care/domain/repositories/care_repository.dart';
import 'package:evolua_frontend/features/care/presentation/pages/care_share_page.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('manual sync button shows progress and recovers guidance', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final secret = base64UrlEncode(
      List<int>.generate(32, (index) => index + 3),
    );
    final repository = _FakeCareRepository();
    final secretStore = _FakeCareSecretStore({'share-1': secret});

    await tester.pumpWidget(
      _careSharePage(repository: repository, secretStore: secretStore),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

    repository.pendingGate = Completer<void>();
    repository.pendingRecommendationsList = [
      await _encryptedRecommendation(tester: tester, secretBase64: secret),
    ];

    await tester.tap(find.byTooltip('Atualizar'));
    await tester.pump();

    expect(find.byIcon(Icons.sync_rounded), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    repository.pendingGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    expect(find.text('Alongue os ombros antes de dormir.'), findsOneWidget);
    expect(repository.pendingPrescriptionFetches, greaterThanOrEqualTo(2));
    expect(repository.pendingRecommendationFetches, greaterThanOrEqualTo(2));
  });

  testWidgets('manual pull refresh shows safe snackbar on decrypt failure', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeCareRepository();
    final secretStore = _FakeCareSecretStore({
      'share-1': base64UrlEncode(List<int>.filled(32, 1)),
    });

    await tester.pumpWidget(
      _careSharePage(repository: repository, secretStore: secretStore),
    );
    await tester.pumpAndSettle();

    repository.pendingRecommendationsList = [
      CareRecommendationEnvelope(
        recommendationId: 'rec-bad',
        shareId: 'share-1',
        encryptedPayload: const CareEncryptedPayload(
          algorithm: 'AES-256-GCM',
          nonceBase64: 'invalid',
          cipherTextBase64: 'invalid',
          macBase64: 'invalid',
        ),
        attachments: const [],
        createdAt: DateTime(2026, 5, 27, 10),
      ),
    ];

    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Não foi possível sincronizar agora. Tente novamente em instantes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'confirm reading acknowledges and moves recommendation to history',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final secret = base64UrlEncode(
        List<int>.generate(32, (index) => index + 3),
      );
      final repository = _FakeCareRepository();
      final secretStore = _FakeCareSecretStore({'share-1': secret});

      await tester.pumpWidget(
        _careSharePage(repository: repository, secretStore: secretStore),
      );
      await tester.pumpAndSettle();

      repository.allRecommendations = [
        await _encryptedRecommendation(tester: tester, secretBase64: secret),
      ];
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CareSharePage)),
      );
      await container.refresh(careRecommendationsProvider.future);
      await tester.pumpAndSettle();

      expect(find.text('Alongue os ombros antes de dormir.'), findsOneWidget);
      expect(find.text('Nova'), findsOneWidget);

      await tester.ensureVisible(find.text('Confirmar leitura'));
      await tester.tap(find.text('Confirmar leitura'));
      await tester.pumpAndSettle();

      expect(repository.acknowledgedRecommendations, ['rec-widget']);
      expect(find.text('Histórico de Orientações'), findsOneWidget);
      expect(find.text('Leitura confirmada'), findsOneWidget);
      expect(find.text('Alongue os ombros antes de dormir.'), findsOneWidget);
      expect(find.text('Nova'), findsNothing);
    },
  );

  testWidgets('renders read and opened recommendations in 30 day history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final secret = base64UrlEncode(
      List<int>.generate(32, (index) => index + 3),
    );
    final repository = _FakeCareRepository();
    final secretStore = _FakeCareSecretStore({'share-1': secret});

    await tester.pumpWidget(
      _careSharePage(repository: repository, secretStore: secretStore),
    );
    await tester.pumpAndSettle();

    repository.allRecommendations = [
      await _encryptedRecommendation(
        tester: tester,
        secretBase64: secret,
        recommendationId: 'rec-new',
        guidanceText: 'Mensagem nova para hoje.',
      ),
      await _encryptedRecommendation(
        tester: tester,
        secretBase64: secret,
        recommendationId: 'rec-read',
        guidanceText: 'Mensagem lida continua disponivel.',
        status: 'READ',
        readAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      await _encryptedRecommendation(
        tester: tester,
        secretBase64: secret,
        recommendationId: 'rec-opened',
        guidanceText: 'Mensagem aberta fica no historico.',
        status: 'OPENED',
      ),
      await _encryptedRecommendation(
        tester: tester,
        secretBase64: secret,
        recommendationId: 'rec-old',
        guidanceText: 'Mensagem antiga fora da janela.',
        status: 'READ',
        createdAt: DateTime.now().subtract(const Duration(days: 31)),
      ),
    ];
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CareSharePage)),
    );
    await container.refresh(careRecommendationsProvider.future);
    await tester.pumpAndSettle();

    expect(find.text('Mensagem nova para hoje.'), findsOneWidget);
    expect(find.text('Nova'), findsOneWidget);
    expect(find.text('Histórico de Orientações'), findsOneWidget);
    expect(find.text('Mensagem lida continua disponivel.'), findsOneWidget);
    expect(find.text('Mensagem aberta fica no historico.'), findsOneWidget);
    expect(find.text('Mensagem antiga fora da janela.'), findsNothing);
  });
}

Widget _careSharePage({
  required _FakeCareRepository repository,
  required _FakeCareSecretStore secretStore,
}) {
  return ProviderScope(
    overrides: [
      careRepositoryProvider.overrideWithValue(repository),
      careSecretStoreProvider.overrideWithValue(secretStore),
    ],
    child: const MaterialApp(
      locale: Locale('pt', 'BR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: CareSharePage()),
    ),
  );
}

Future<CareRecommendationEnvelope> _encryptedRecommendation({
  required WidgetTester tester,
  required String secretBase64,
  String recommendationId = 'rec-widget',
  String guidanceText = 'Alongue os ombros antes de dormir.',
  String status = 'NEW',
  DateTime? createdAt,
  DateTime? readAt,
}) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CareSharePage)),
  );
  const shareId = 'share-1';
  final crypto = container.read(careCryptoServiceProvider);
  final secret = base64Url.decode(base64.normalize(secretBase64));
  final key = await crypto.deriveSessionKey(
    shareSecret: secret,
    shareId: shareId,
    purpose: 'care-guidance-v1',
  );
  final payload = await crypto.encryptJson(
    key: key,
    shareId: shareId,
    purpose: CareCryptoPayloadPurpose.guidance,
    json: {'guidanceText': guidanceText, 'attachments': []},
  );
  return CareRecommendationEnvelope(
    recommendationId: recommendationId,
    shareId: shareId,
    encryptedPayload: payload,
    attachments: const [],
    createdAt: createdAt ?? DateTime.now(),
    status: status,
    readAt: readAt,
    therapistLabel: 'Terapeuta',
  );
}

class _FakeCareRepository implements CareRepository {
  Completer<void>? pendingGate;
  List<CareRecommendationEnvelope> pendingRecommendationsList = const [];
  List<CareRecommendationEnvelope> allRecommendations = const [];
  int pendingPrescriptionFetches = 0;
  int pendingRecommendationFetches = 0;
  final acknowledgedRecommendations = <String>[];

  @override
  Future<void> acknowledgePrescription(String prescriptionId) async {}

  @override
  Future<void> acknowledgeRecommendation(String recommendationId) async {
    acknowledgedRecommendations.add(recommendationId);
  }

  @override
  Future<CareShareSession?> currentShare() async => _session();

  @override
  Future<CareShareSession> createShareSession() async => _session();

  @override
  Future<List<int>> downloadRecommendationAttachment({
    required String recommendationId,
    required String attachmentId,
  }) async => const [];

  @override
  Future<CareShareSession> getShareStatus(String shareId) async => _session();

  @override
  Future<Map<String, dynamic>> loadCareReportSource() async => const {};

  @override
  Future<List<CarePrescriptionEnvelope>> pendingPrescriptions() async {
    pendingPrescriptionFetches++;
    await pendingGate?.future;
    return const [];
  }

  @override
  Future<List<CareRecommendationEnvelope>> pendingRecommendations() async {
    pendingRecommendationFetches++;
    allRecommendations = pendingRecommendationsList;
    return pendingRecommendationsList;
  }

  @override
  Future<List<CareRecommendationEnvelope>> recommendations() async {
    return allRecommendations;
  }

  @override
  Future<CareShareSession> revokeShare(String shareId) async => _session();

  @override
  Future<List<CareShareSession>> shareHistory() async => const [];

  @override
  Future<CareShareSession> uploadEncryptedReport({
    required String shareId,
    required CareEncryptedPayload payload,
  }) async => _session();

  CareShareSession _session() {
    final now = DateTime(2026, 5, 27, 9);
    return CareShareSession(
      shareId: 'share-1',
      numericCode: '123456',
      status: CareAccessStatus.active,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
  }
}

class _FakeCareSecretStore implements CareSecretStore {
  const _FakeCareSecretStore(this.values);

  final Map<String, String> values;

  @override
  Future<void> delete(String shareId) async {}

  @override
  Future<String?> read(String shareId) async => values[shareId];

  @override
  Future<void> save(String shareId, String secretBase64) async {}
}
