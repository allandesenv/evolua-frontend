import 'dart:async';
import 'dart:convert';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/application/care_recommendation_handler.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_event.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_service.dart';
import 'package:evolua_frontend/features/care/application/care_secret_store.dart';
import 'package:evolua_frontend/features/care/application/care_share_controller.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_access_status.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_prescription_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_recommendation_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_share_session.dart';
import 'package:evolua_frontend/features/care/domain/repositories/care_repository.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/repositories/daily_ritual_repository.dart';
import 'package:evolua_frontend/features/notification/application/notification_controller.dart';
import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';
import 'package:evolua_frontend/features/notification/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CareShareController', () {
    test(
      'generates active access with encrypted report and QR payload',
      () async {
        final repository = _FakeCareRepository();
        final container = ProviderContainer(
          overrides: [
            careRepositoryProvider.overrideWithValue(repository),
            careSecretStoreProvider.overrideWithValue(_FakeCareSecretStore()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(careShareControllerProvider.future);
        await container
            .read(careShareControllerProvider.notifier)
            .generateAccess();

        final state = container.read(careShareControllerProvider).value!;
        expect(state.status, CareAccessStatus.active);
        expect(state.qrPayload, isNotNull);
        final qrUrl = state.qrPayload.toString();
        expect(qrUrl, contains('/evolua-frontend/#/care/claim'));
        expect(qrUrl, contains('sid=share-1'));
        expect(qrUrl, contains('code=123456'));
        expect(qrUrl, contains('k='));
        expect(qrUrl, isNot(contains('/evolua-care')));
        expect(state.numericCode, '123456');
        expect(repository.uploadedPayload, isNotNull);
        expect(
          repository.uploadedPayload!.cipherTextBase64,
          isNot(contains('ansiedade')),
        );
      },
    );

    test('updates connected and revoked states', () async {
      final repository = _FakeCareRepository();
      final secretStore = _FakeCareSecretStore();
      final container = ProviderContainer(
        overrides: [
          careRepositoryProvider.overrideWithValue(repository),
          careSecretStoreProvider.overrideWithValue(secretStore),
        ],
      );
      addTearDown(container.dispose);

      await container.read(careShareControllerProvider.future);
      await container
          .read(careShareControllerProvider.notifier)
          .generateAccess();
      final shareSecret = secretStore.values['share-1'];
      expect(shareSecret, isNotNull);

      repository.nextStatus = CareAccessStatus.connected;
      await container
          .read(careShareControllerProvider.notifier)
          .refreshStatus();
      expect(
        container.read(careShareControllerProvider).value!.status,
        CareAccessStatus.connected,
      );

      await container.read(careShareControllerProvider.notifier).revokeAccess();
      expect(
        container.read(careShareControllerProvider).value!.status,
        CareAccessStatus.revoked,
      );
      expect(secretStore.values['share-1'], shareSecret);
      expect(secretStore.deleteCount, 0);
    });

    test('terminal realtime events preserve local share secret', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = _FakeCareRepository()
        ..session = _shareSession(CareAccessStatus.active);
      final secretStore = _FakeCareSecretStore()
        ..values['share-1'] = base64UrlEncode(List<int>.filled(32, 2));
      final realtimeService = _FakeCareRealtimeService();
      final container = ProviderContainer(
        overrides: [
          careRepositoryProvider.overrideWithValue(repository),
          careSecretStoreProvider.overrideWithValue(secretStore),
          careRealtimeServiceProvider.overrideWithValue(realtimeService),
          authControllerProvider.overrideWith(
            () => _FakeAuthController(userId: 'user-a'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      await container.read(careShareControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      realtimeService.emit(
        CareRealtimeEvent(
          type: CareRealtimeEventType.shareExpired,
          shareId: 'share-1',
          occurredAt: DateTime(2026, 5, 27, 10),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(careShareControllerProvider).value!;
      expect(state.status, CareAccessStatus.expired);
      expect(secretStore.values['share-1'], isNotNull);
      expect(secretStore.deleteCount, 0);
      expect(realtimeService.disconnectCount, 1);
    });

    test(
      'syncPendingCare applies pending packets and prevents concurrent fetches',
      () async {
        SharedPreferences.setMockInitialValues({});
        final secret = base64UrlEncode(
          List<int>.generate(32, (index) => index + 9),
        );
        final repository = _FakeCareRepository()
          ..session = _shareSession(CareAccessStatus.active);
        final dailyRepository = _FakeDailyRitualRepository();
        final secretStore = _FakeCareSecretStore();
        secretStore.values['share-1'] = secret;
        final container = ProviderContainer(
          overrides: [
            careRepositoryProvider.overrideWithValue(repository),
            careSecretStoreProvider.overrideWithValue(secretStore),
            dailyRitualRepositoryProvider.overrideWithValue(dailyRepository),
            notificationRepositoryProvider.overrideWithValue(
              _FakeNotificationRepository(),
            ),
            authControllerProvider.overrideWith(
              () => _FakeAuthController(userId: 'user-a'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(careShareControllerProvider.future);
        await Future<void>.delayed(Duration.zero);
        final baselinePrescriptionFetches = repository.prescriptionFetches;

        repository.pendingPrescriptionResult = Completer<void>();
        final first = container
            .read(careShareControllerProvider.notifier)
            .syncPendingCare(manual: true);
        final second = container
            .read(careShareControllerProvider.notifier)
            .syncPendingCare(manual: true);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(careShareControllerProvider).value!.isSyncing,
          isTrue,
        );
        expect(repository.prescriptionFetches, baselinePrescriptionFetches + 1);

        repository.pendingPrescriptionsList = [
          await _encryptedPrescription(
            container: container,
            secretBase64: secret,
            prescriptionId: 'rx-sync',
          ),
        ];
        repository.pendingRecommendationsList = [
          await _encryptedRecommendation(
            container: container,
            secretBase64: secret,
          ),
        ];
        repository.allRecommendations = repository.pendingRecommendationsList;
        repository.pendingPrescriptionResult!.complete();

        final firstResult = await first;
        final secondResult = await second;
        final recommendations = await container.read(
          careRecommendationsProvider.future,
        );
        final rituals = await container.read(
          dailyRitualControllerProvider.future,
        );

        expect(firstResult.applied, isTrue);
        expect(secondResult.applied, isTrue);
        expect(firstResult.hasFailures, isFalse);
        expect(repository.prescriptionFetches, baselinePrescriptionFetches + 1);
        expect(repository.recommendationFetches, greaterThanOrEqualTo(1));
        expect(repository.acknowledgedPrescriptions, ['rx-sync']);
        expect(rituals.morning?.microAction, 'respirar por dois minutos');
        expect(recommendations.single.guidanceText, 'Hidrate-se hoje.');
        expect(
          container.read(careShareControllerProvider).value!.isSyncing,
          isFalse,
        );
      },
    );

    test('syncPendingCare reports safe failure when decrypt fails', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = _FakeCareRepository()
        ..session = _shareSession(CareAccessStatus.active)
        ..pendingRecommendationsList = [
          CareRecommendationEnvelope(
            recommendationId: 'bad-rec',
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
      final secretStore = _FakeCareSecretStore();
      secretStore.values['share-1'] = base64UrlEncode(List<int>.filled(32, 1));
      final container = ProviderContainer(
        overrides: [
          careRepositoryProvider.overrideWithValue(repository),
          careSecretStoreProvider.overrideWithValue(secretStore),
        ],
      );
      addTearDown(container.dispose);

      await container.read(careShareControllerProvider.future);
      final result = await container
          .read(careShareControllerProvider.notifier)
          .syncPendingCare(manual: true);

      expect(result.applied, isFalse);
      expect(result.hasFailures, isTrue);
      expect(
        container.read(careShareControllerProvider).value!.isSyncing,
        isFalse,
      );
    });
  });
}

Future<CarePrescriptionEnvelope> _encryptedPrescription({
  required ProviderContainer container,
  required String secretBase64,
  required String prescriptionId,
}) async {
  const shareId = 'share-1';
  final crypto = container.read(careCryptoServiceProvider);
  final secret = base64Url.decode(base64.normalize(secretBase64));
  final key = await crypto.deriveSessionKey(
    shareSecret: secret,
    shareId: shareId,
    purpose: 'custom-ritual-v1',
  );
  final payload = await crypto.encryptJson(
    key: key,
    shareId: shareId,
    purpose: CareCryptoPayloadPurpose.customRitual,
    json: DailyRitualDraft(
      localDate: DateTime(2026, 5, 27),
      type: DailyRitualType.morning,
      emotionalState: 'ansiedade',
      dayNeed: 'regular o comeco do dia',
      intention: 'comecar com presenca',
      microAction: 'respirar por dois minutos',
    ).toJson(),
  );
  return CarePrescriptionEnvelope(
    prescriptionId: prescriptionId,
    shareId: shareId,
    encryptedPayload: payload,
    createdAt: DateTime(2026, 5, 27, 9),
  );
}

Future<CareRecommendationEnvelope> _encryptedRecommendation({
  required ProviderContainer container,
  required String secretBase64,
}) async {
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
    json: {
      'guidanceText': 'Hidrate-se hoje.',
      'attachments': [
        {
          'attachmentId': 'att-1',
          'displayName': 'plano.pdf',
          'contentType': 'application/pdf',
          'sizeBytes': 99,
        },
      ],
    },
  );
  return CareRecommendationEnvelope(
    recommendationId: 'rec-sync',
    shareId: shareId,
    encryptedPayload: payload,
    attachments: [
      CareRecommendationAttachmentEnvelope(
        attachmentId: 'att-1',
        encryptedMetadata: payload,
        sizeBytes: 99,
        contentType: 'application/pdf',
      ),
    ],
    createdAt: DateTime(2026, 5, 27, 10),
    therapistLabel: 'Terapeuta',
  );
}

CareShareSession _shareSession(CareAccessStatus status) {
  final now = DateTime(2026, 5, 26, 9);
  return CareShareSession(
    shareId: 'share-1',
    numericCode: '123456',
    status: status,
    createdAt: now,
    expiresAt: now.add(const Duration(minutes: 15)),
  );
}

class _FakeCareRepository implements CareRepository {
  CareAccessStatus nextStatus = CareAccessStatus.active;
  CareEncryptedPayload? uploadedPayload;
  CareShareSession? session;
  Completer<void>? pendingPrescriptionResult;
  List<CarePrescriptionEnvelope> pendingPrescriptionsList = const [];
  List<CareRecommendationEnvelope> pendingRecommendationsList = const [];
  List<CareRecommendationEnvelope> allRecommendations = const [];
  final acknowledgedPrescriptions = <String>[];
  int prescriptionFetches = 0;
  int recommendationFetches = 0;

  @override
  Future<CareShareSession?> currentShare() async => session;

  @override
  Future<CareShareSession> createShareSession() async {
    session = _shareSession(CareAccessStatus.active);
    return session!;
  }

  @override
  Future<CareShareSession> getShareStatus(String shareId) async {
    session = _shareSession(nextStatus);
    return session!;
  }

  @override
  Future<Map<String, dynamic>> loadCareReportSource() async {
    return {
      'checkIns': [
        {'mood': 'ansiedade', 'reflection': 'sem expor texto claro'},
      ],
    };
  }

  @override
  Future<CareShareSession> revokeShare(String shareId) async {
    session = _shareSession(CareAccessStatus.revoked);
    return session!;
  }

  @override
  Future<CareShareSession> uploadEncryptedReport({
    required String shareId,
    required CareEncryptedPayload payload,
  }) async {
    uploadedPayload = payload;
    return session ?? _session(CareAccessStatus.active);
  }

  @override
  Future<void> acknowledgePrescription(String prescriptionId) async {
    acknowledgedPrescriptions.add(prescriptionId);
  }

  @override
  Future<void> acknowledgeRecommendation(String recommendationId) async {}

  @override
  Future<List<CarePrescriptionEnvelope>> pendingPrescriptions() async {
    prescriptionFetches++;
    await pendingPrescriptionResult?.future;
    return pendingPrescriptionsList;
  }

  @override
  Future<List<CareRecommendationEnvelope>> pendingRecommendations() async {
    recommendationFetches++;
    return pendingRecommendationsList;
  }

  @override
  Future<List<CareRecommendationEnvelope>> recommendations() async =>
      allRecommendations;

  @override
  Future<List<int>> downloadRecommendationAttachment({
    required String recommendationId,
    required String attachmentId,
  }) async => const [];

  @override
  Future<List<CareShareSession>> shareHistory() async => const [];

  CareShareSession _session(CareAccessStatus status) => _shareSession(status);
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
      accessToken:
          'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': userId, 'email': '$userId@evolua.test'})))}.signature',
    );
  }
}

class _FakeDailyRitualRepository implements DailyRitualRepository {
  DailyRitual? morning;

  @override
  Future<DailyRitual> create(DailyRitualDraft draft) async {
    final ritual = DailyRitual(
      id: 1,
      localDate: draft.localDate,
      type: draft.type,
      emotionalState: draft.emotionalState,
      dayNeed: draft.dayNeed,
      intention: draft.intention,
      microAction: draft.microAction,
      createdAt: DateTime(2026, 5, 27, 9),
    );
    morning = ritual;
    return ritual;
  }

  @override
  Future<DailyRitual?> today({
    required String type,
    required DateTime localDate,
  }) async {
    return type == DailyRitualType.morning ? morning : null;
  }
}

class _FakeNotificationRepository implements NotificationRepository {
  @override
  Future<NotificationJob> createAdmin({
    required String targetUserId,
    required String type,
    required String title,
    required String message,
    String? actionTarget,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<NotificationJob>> list({bool unreadOnly = false}) async =>
      const [];

  @override
  Future<int> markAllAsRead() async => 0;

  @override
  Future<NotificationJob> markAsRead(String id) {
    throw UnimplementedError();
  }

  @override
  Future<int> unreadCount() async => 0;
}

class _FakeCareRealtimeService implements CareRealtimeService {
  final StreamController<CareRealtimeEvent> _events =
      StreamController<CareRealtimeEvent>.broadcast();
  int disconnectCount = 0;

  @override
  Stream<CareRealtimeEvent> connect({
    required String userId,
    required String accessToken,
  }) {
    return _events.stream;
  }

  void emit(CareRealtimeEvent event) {
    _events.add(event);
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
  }
}

class _FakeCareSecretStore implements CareSecretStore {
  final Map<String, String> values = {};
  int deleteCount = 0;

  @override
  Future<void> delete(String shareId) async {
    deleteCount++;
    values.remove(shareId);
  }

  @override
  Future<String?> read(String shareId) async => values[shareId];

  @override
  Future<void> save(String shareId, String secretBase64) async {
    values[shareId] = secretBase64;
  }
}
