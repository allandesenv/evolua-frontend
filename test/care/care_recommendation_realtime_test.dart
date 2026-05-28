import 'dart:convert';

import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/application/care_recommendation_handler.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_event.dart';
import 'package:evolua_frontend/features/care/application/care_repository_provider.dart';
import 'package:evolua_frontend/features/care/application/care_secret_store.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_access_status.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_prescription_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_recommendation_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_share_session.dart';
import 'package:evolua_frontend/features/care/domain/repositories/care_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'realtime recommendation event fetches pending guidance and refreshes list',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secret = base64UrlEncode(
        List<int>.generate(32, (index) => index + 7),
      );
      final repository = _FakeCareRepository();
      final container = ProviderContainer(
        overrides: [
          careSecretStoreProvider.overrideWithValue(
            _FakeCareSecretStore({'share-1': secret}),
          ),
          careRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final envelope = await _encryptedRecommendation(
        container: container,
        secretBase64: secret,
      );
      repository.pending = [envelope];
      repository.all = [envelope];

      final applied = await container
          .read(careRecommendationHandlerProvider)
          .applyRealtimeEvent(
            CareRealtimeEvent(
              type: CareRealtimeEventType.recommendationCreated,
              shareId: 'share-1',
              recommendationId: 'rec-1',
              occurredAt: DateTime(2026, 5, 27, 10),
            ),
          );
      final recommendations = await container.read(
        careRecommendationsProvider.future,
      );

      expect(applied, isTrue);
      expect(recommendations, hasLength(1));
      expect(
        recommendations.single.guidanceText,
        'Observe pausas curtas ao longo do dia.',
      );
      expect(
        recommendations.single.attachments.single.displayName,
        'orientacao.pdf',
      );

      final repeated = await container
          .read(careRecommendationHandlerProvider)
          .applyRealtimeEvent(
            CareRealtimeEvent(
              type: CareRealtimeEventType.recommendationCreated,
              shareId: 'share-1',
              recommendationId: 'rec-1',
              occurredAt: DateTime(2026, 5, 27, 10),
            ),
          );

      expect(repeated, isFalse);
    },
  );

  test(
    'invalid recommendation payload is ignored without breaking controller',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = _FakeCareRepository();
      repository.pending = [
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
      final container = ProviderContainer(
        overrides: [
          careSecretStoreProvider.overrideWithValue(
            _FakeCareSecretStore({
              'share-1': base64UrlEncode(List<int>.filled(32, 1)),
            }),
          ),
          careRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final applied = await container
          .read(careRecommendationHandlerProvider)
          .applyPending();

      expect(applied, isFalse);
    },
  );

  test(
    'pending recommendations apply valid envelopes after decrypt failures',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secret = base64UrlEncode(
        List<int>.generate(32, (index) => index + 7),
      );
      final repository = _FakeCareRepository();
      final container = ProviderContainer(
        overrides: [
          careSecretStoreProvider.overrideWithValue(
            _FakeCareSecretStore({'share-1': secret}),
          ),
          careRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final envelope = await _encryptedRecommendation(
        container: container,
        secretBase64: secret,
      );
      repository.pending = [
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
        envelope,
      ];
      repository.all = [envelope];

      final result = await container
          .read(careRecommendationHandlerProvider)
          .applyPendingDetailed();
      final recommendations = await container.read(
        careRecommendationsProvider.future,
      );

      expect(result.applied, isTrue);
      expect(result.hasFailures, isTrue);
      expect(recommendations.single.recommendationId, 'rec-1');
    },
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
      'guidanceText': 'Observe pausas curtas ao longo do dia.',
      'attachments': [
        {
          'attachmentId': 'att-1',
          'displayName': 'orientacao.pdf',
          'contentType': 'application/pdf',
          'sizeBytes': 120,
        },
      ],
    },
  );
  return CareRecommendationEnvelope(
    recommendationId: 'rec-1',
    shareId: shareId,
    encryptedPayload: payload,
    attachments: [
      CareRecommendationAttachmentEnvelope(
        attachmentId: 'att-1',
        encryptedMetadata: payload,
        sizeBytes: 120,
        contentType: 'application/pdf',
      ),
    ],
    createdAt: DateTime(2026, 5, 27, 10),
    therapistLabel: 'Terapeuta',
  );
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

class _FakeCareRepository implements CareRepository {
  List<CareRecommendationEnvelope> pending = const [];
  List<CareRecommendationEnvelope> all = const [];

  @override
  Future<void> acknowledgePrescription(String prescriptionId) async {}

  @override
  Future<void> acknowledgeRecommendation(String recommendationId) async {}

  @override
  Future<CareShareSession?> currentShare() async => null;

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
  Future<List<CarePrescriptionEnvelope>> pendingPrescriptions() async =>
      const [];

  @override
  Future<List<CareRecommendationEnvelope>> pendingRecommendations() async =>
      pending;

  @override
  Future<List<CareRecommendationEnvelope>> recommendations() async => all;

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
    return CareShareSession(
      shareId: 'share-1',
      numericCode: '123456',
      status: CareAccessStatus.active,
      createdAt: DateTime(2026, 5, 27),
      expiresAt: DateTime(2026, 5, 27, 10),
    );
  }
}
