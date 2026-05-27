import 'package:evolua_frontend/features/care/application/care_secret_store.dart';
import 'package:evolua_frontend/features/care/application/care_share_controller.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_access_status.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_prescription_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_recommendation_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_share_session.dart';
import 'package:evolua_frontend/features/care/domain/repositories/care_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    });
  });
}

class _FakeCareRepository implements CareRepository {
  CareAccessStatus nextStatus = CareAccessStatus.active;
  CareEncryptedPayload? uploadedPayload;
  CareShareSession? session;

  @override
  Future<CareShareSession?> currentShare() async => null;

  @override
  Future<CareShareSession> createShareSession() async {
    session = _session(CareAccessStatus.active);
    return session!;
  }

  @override
  Future<CareShareSession> getShareStatus(String shareId) async {
    session = _session(nextStatus);
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
    session = _session(CareAccessStatus.revoked);
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
  Future<void> acknowledgePrescription(String prescriptionId) async {}

  @override
  Future<void> acknowledgeRecommendation(String recommendationId) async {}

  @override
  Future<List<CarePrescriptionEnvelope>> pendingPrescriptions() async =>
      const [];

  @override
  Future<List<CareRecommendationEnvelope>> pendingRecommendations() async =>
      const [];

  @override
  Future<List<CareRecommendationEnvelope>> recommendations() async => const [];

  @override
  Future<List<int>> downloadRecommendationAttachment({
    required String recommendationId,
    required String attachmentId,
  }) async => const [];

  @override
  Future<List<CareShareSession>> shareHistory() async => const [];

  CareShareSession _session(CareAccessStatus status) {
    final now = DateTime(2026, 5, 26, 9);
    return CareShareSession(
      shareId: 'share-1',
      numericCode: '123456',
      status: status,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
  }
}

class _FakeCareSecretStore implements CareSecretStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String shareId) async {
    values.remove(shareId);
  }

  @override
  Future<String?> read(String shareId) async => values[shareId];

  @override
  Future<void> save(String shareId, String secretBase64) async {
    values[shareId] = secretBase64;
  }
}
