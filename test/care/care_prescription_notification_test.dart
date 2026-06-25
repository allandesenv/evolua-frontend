import 'dart:convert';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/application/care_prescription_handler.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_event.dart';
import 'package:evolua_frontend/features/care/application/care_repository_provider.dart';
import 'package:evolua_frontend/features/care/application/care_secret_store.dart';
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
  test(
    'applied care prescription creates private inbox notification once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secret = base64UrlEncode(
        List<int>.generate(32, (index) => index + 1),
      );
      final careRepository = _FakeCareRepository();
      final dailyRepository = _FakeDailyRitualRepository();
      final notificationRepository = _FakeNotificationRepository();
      final container = ProviderContainer(
        overrides: [
          careSecretStoreProvider.overrideWithValue(
            _FakeCareSecretStore({'share-1': secret}),
          ),
          careRepositoryProvider.overrideWithValue(careRepository),
          dailyRitualRepositoryProvider.overrideWithValue(dailyRepository),
          notificationRepositoryProvider.overrideWithValue(
            notificationRepository,
          ),
          authControllerProvider.overrideWith(
            () => _FakeAuthController(userId: 'user-a'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final envelope = await _encryptedEnvelope(
        container: container,
        secretBase64: secret,
        prescriptionId: 'rx-1',
      );

      final handler = container.read(carePrescriptionHandlerProvider);
      expect(await handler.applyEnvelope(envelope), isTrue);
      expect(await handler.applyEnvelope(envelope), isTrue);

      final notifications = await container
          .read(localCareNotificationServiceProvider)
          .load('user-a');

      expect(dailyRepository.created, hasLength(1));
      expect(careRepository.acknowledged, ['rx-1']);
      expect(notifications, hasLength(1));
      expect(notificationRepository.listCalls, 0);
      expect(notifications.single.id, 'care-prescription-rx-1');
      expect(notifications.single.userId, 'user-a');
      expect(notifications.single.title, 'Novo ritual do terapeuta');
      expect(
        notifications.single.message,
        'Seu terapeuta enviou um ritual personalizado para você.',
      );
      expect(notifications.single.actionTarget, '/daily-ritual?type=morning');
      expect(notifications.single.isRead, isFalse);
      expect(notifications.single.message, isNot(contains('respirar')));
      expect(notifications.single.message, isNot(contains('ansiedade')));
    },
  );

  test(
    'applied care prescription refreshes visible ritual with updated values',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secret = base64UrlEncode(
        List<int>.generate(32, (index) => index + 1),
      );
      final dailyRepository = _FakeDailyRitualRepository(
        initialMorning: DailyRitual(
          id: 7,
          localDate: _localDate,
          type: DailyRitualType.morning,
          emotionalState: 'antigo',
          dayNeed: 'necessidade antiga',
          intention: 'intenção antiga',
          microAction: 'micro antiga',
          createdAt: DateTime(2026, 5, 27, 8),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          careSecretStoreProvider.overrideWithValue(
            _FakeCareSecretStore({'share-1': secret}),
          ),
          careRepositoryProvider.overrideWithValue(_FakeCareRepository()),
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

      final initial = await container.read(
        dailyRitualControllerProvider.future,
      );
      expect(initial.morning?.intention, 'intenção antiga');

      final envelope = await _encryptedEnvelope(
        container: container,
        secretBase64: secret,
        prescriptionId: 'rx-2',
      );

      final applied = await container
          .read(carePrescriptionHandlerProvider)
          .applyEnvelope(envelope);
      final updated = await container.read(
        dailyRitualControllerProvider.future,
      );

      expect(applied, isTrue);
      expect(updated.morning?.intention, 'começar com presença');
      expect(updated.morning?.microAction, 'respirar por dois minutos');
    },
  );

  test(
    'care notification failure does not fail an applied prescription',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secret = base64UrlEncode(
        List<int>.generate(32, (index) => index + 1),
      );
      final careRepository = _FakeCareRepository();
      final dailyRepository = _FakeDailyRitualRepository();
      final container = ProviderContainer(
        overrides: [
          careSecretStoreProvider.overrideWithValue(
            _FakeCareSecretStore({'share-1': secret}),
          ),
          careRepositoryProvider.overrideWithValue(careRepository),
          dailyRitualRepositoryProvider.overrideWithValue(dailyRepository),
          notificationRepositoryProvider.overrideWithValue(
            _FakeNotificationRepository(),
          ),
          localCareNotificationServiceProvider.overrideWith(
            (ref) => _ThrowingLocalCareNotificationService(ref),
          ),
          authControllerProvider.overrideWith(
            () => _FakeAuthController(userId: 'user-a'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final envelope = await _encryptedEnvelope(
        container: container,
        secretBase64: secret,
        prescriptionId: 'rx-notification-fails',
      );

      final result = await container
          .read(carePrescriptionHandlerProvider)
          .applyEnvelopeDetailed(envelope);

      expect(result.applied, isTrue);
      expect(result.failed, isFalse);
      expect(dailyRepository.created, hasLength(1));
      expect(careRepository.acknowledged, ['rx-notification-fails']);
    },
  );

  test(
    'realtime event with id only fetches pending envelope and applies once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secret = base64UrlEncode(
        List<int>.generate(32, (index) => index + 1),
      );
      final careRepository = _FakeCareRepository();
      final dailyRepository = _FakeDailyRitualRepository();
      final container = ProviderContainer(
        overrides: [
          careSecretStoreProvider.overrideWithValue(
            _FakeCareSecretStore({'share-1': secret}),
          ),
          careRepositoryProvider.overrideWithValue(careRepository),
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

      careRepository.pending = [
        await _encryptedEnvelope(
          container: container,
          secretBase64: secret,
          prescriptionId: 'rx-pending',
        ),
      ];

      final applied = await container
          .read(carePrescriptionHandlerProvider)
          .applyRealtimeEvent(
            CareRealtimeEvent(
              type: CareRealtimeEventType.prescriptionCreated,
              shareId: 'share-1',
              prescriptionId: 'rx-pending',
              occurredAt: DateTime(2026, 5, 27, 9),
            ),
          );

      expect(applied, isTrue);
      expect(dailyRepository.created, hasLength(1));
      expect(careRepository.acknowledged, ['rx-pending']);
    },
  );

  test(
    'pending prescriptions continue after invalid encrypted envelope',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secret = base64UrlEncode(
        List<int>.generate(32, (index) => index + 1),
      );
      final careRepository = _FakeCareRepository();
      final dailyRepository = _FakeDailyRitualRepository();
      final container = ProviderContainer(
        overrides: [
          careSecretStoreProvider.overrideWithValue(
            _FakeCareSecretStore({'share-1': secret}),
          ),
          careRepositoryProvider.overrideWithValue(careRepository),
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

      careRepository.pending = [
        CarePrescriptionEnvelope(
          prescriptionId: 'rx-bad',
          shareId: 'share-1',
          encryptedPayload: const CareEncryptedPayload(
            algorithm: 'AES-256-GCM',
            nonceBase64: 'invalid',
            cipherTextBase64: 'invalid',
            macBase64: 'invalid',
          ),
          createdAt: DateTime(2026, 5, 27, 8),
        ),
        await _encryptedEnvelope(
          container: container,
          secretBase64: secret,
          prescriptionId: 'rx-good',
        ),
      ];

      final result = await container
          .read(carePrescriptionHandlerProvider)
          .applyPendingDetailed();
      final rituals = await container.read(
        dailyRitualControllerProvider.future,
      );

      expect(result.applied, isTrue);
      expect(result.hasFailures, isTrue);
      expect(careRepository.acknowledged, ['rx-good']);
      expect(rituals.morning?.microAction, 'respirar por dois minutos');
    },
  );

  test('local care notifications are scoped by authenticated user', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeNotificationRepository();

    final firstContainer = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(userId: 'user-a'),
        ),
      ],
    );
    addTearDown(firstContainer.dispose);
    await firstContainer.read(notificationInboxControllerProvider.future);
    await firstContainer
        .read(notificationInboxControllerProvider.notifier)
        .addCarePrescriptionNotification(
          prescriptionId: 'rx-user-a',
          ritualType: DailyRitualType.morning,
        );

    final secondContainer = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(userId: 'user-b'),
        ),
      ],
    );
    addTearDown(secondContainer.dispose);
    final secondUserItems = await secondContainer.read(
      notificationInboxControllerProvider.future,
    );

    expect(secondUserItems, isEmpty);

    final thirdContainer = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(userId: 'user-a'),
        ),
      ],
    );
    addTearDown(thirdContainer.dispose);
    final firstUserItems = await thirdContainer.read(
      notificationInboxControllerProvider.future,
    );

    expect(firstUserItems, hasLength(1));
    expect(firstUserItems.single.userId, 'user-a');
  });
}

Future<CarePrescriptionEnvelope> _encryptedEnvelope({
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
      localDate: _localDate,
      type: DailyRitualType.morning,
      emotionalState: 'ansiedade',
      dayNeed: 'regular o começo do dia',
      intention: 'começar com presença',
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

final _localDate = DateTime(2026, 5, 27);

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
  final acknowledged = <String>[];
  List<CarePrescriptionEnvelope> pending = const [];

  @override
  Future<void> acknowledgePrescription(String prescriptionId) async {
    acknowledged.add(prescriptionId);
  }

  @override
  Future<void> acknowledgeRecommendation(String recommendationId) async {}

  @override
  Future<CareShareSession?> currentShare() async => null;

  @override
  Future<CareShareSession> createShareSession() async => _session();

  @override
  Future<CareShareSession> getShareStatus(String shareId) async => _session();

  @override
  Future<Map<String, dynamic>> loadCareReportSource() async => const {};

  @override
  Future<List<CarePrescriptionEnvelope>> pendingPrescriptions() async =>
      pending;

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

class _FakeDailyRitualRepository implements DailyRitualRepository {
  _FakeDailyRitualRepository({DailyRitual? initialMorning})
    : _morning = initialMorning;

  final created = <DailyRitualDraft>[];
  DailyRitual? _morning;
  DailyRitual? _evening;

  @override
  Future<DailyRitual> create(DailyRitualDraft draft) async {
    created.add(draft);
    final current = draft.type == DailyRitualType.evening ? _evening : _morning;
    final ritual = DailyRitual(
      id: current?.id ?? created.length,
      localDate: draft.localDate,
      type: draft.type,
      emotionalState: draft.emotionalState,
      dayNeed: draft.dayNeed,
      intention: draft.intention,
      microAction: draft.microAction,
      createdAt: DateTime(2026, 5, 27, 9),
    );
    if (draft.type == DailyRitualType.evening) {
      _evening = ritual;
    } else {
      _morning = ritual;
    }
    return ritual;
  }

  @override
  Future<DailyRitual?> today({
    required String type,
    required DateTime localDate,
  }) async {
    return type == DailyRitualType.evening ? _evening : _morning;
  }
}

class _FakeNotificationRepository implements NotificationRepository {
  var listCalls = 0;

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
  Future<List<NotificationJob>> list({bool unreadOnly = false}) async {
    listCalls++;
    return const [];
  }

  @override
  Future<int> markAllAsRead() async => 0;

  @override
  Future<NotificationJob> markAsRead(String id) {
    throw UnimplementedError();
  }

  @override
  Future<int> unreadCount() async => 0;
}

class _ThrowingLocalCareNotificationService
    extends LocalCareNotificationService {
  const _ThrowingLocalCareNotificationService(super.ref);

  @override
  Future<LocalCareMutationResult> addPrescription({
    required String userId,
    required String prescriptionId,
    required String ritualType,
  }) {
    throw StateError('storage unavailable');
  }
}
