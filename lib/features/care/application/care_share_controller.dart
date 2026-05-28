import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/application/care_pending_processing_result.dart';
import 'package:evolua_frontend/features/care/application/care_recommendation_handler.dart';
import 'package:evolua_frontend/features/care/application/care_prescription_handler.dart';
import 'package:evolua_frontend/features/care/application/care_qr_payload.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_event.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_service.dart';
import 'package:evolua_frontend/features/care/application/care_repository_provider.dart';
import 'package:evolua_frontend/features/care/application/care_secret_store.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_access_status.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_share_session.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'care_repository_provider.dart';

final careShareControllerProvider =
    AsyncNotifierProvider<CareShareController, CareShareState>(
      CareShareController.new,
    );

final careShareHistoryProvider = FutureProvider<List<CareShareSession>>((
  ref,
) async {
  return ref.read(careRepositoryProvider).shareHistory();
});

class CareShareState {
  const CareShareState({
    required this.status,
    this.session,
    this.qrPayload,
    this.numericCode,
    this.friendlyMessage,
    this.isSyncing = false,
  });

  const CareShareState.idle()
    : status = CareAccessStatus.idle,
      session = null,
      qrPayload = null,
      numericCode = null,
      friendlyMessage = null,
      isSyncing = false;

  const CareShareState.generating()
    : status = CareAccessStatus.generating,
      session = null,
      qrPayload = null,
      numericCode = null,
      friendlyMessage = null,
      isSyncing = false;

  final CareAccessStatus status;
  final CareShareSession? session;
  final CareQrPayload? qrPayload;
  final String? numericCode;
  final String? friendlyMessage;
  final bool isSyncing;

  String? get shareId => session?.shareId;
  DateTime? get expiresAt => session?.expiresAt;
  bool get hasActiveAccess =>
      status == CareAccessStatus.active || status == CareAccessStatus.connected;

  factory CareShareState.fromSession(
    CareShareSession session, {
    CareQrPayload? qrPayload,
    String? friendlyMessage,
    bool isSyncing = false,
  }) {
    return CareShareState(
      status: session.status,
      session: session,
      qrPayload: qrPayload,
      numericCode: session.numericCode,
      friendlyMessage: friendlyMessage,
      isSyncing: isSyncing,
    );
  }

  CareShareState copyWith({
    CareAccessStatus? status,
    CareShareSession? session,
    CareQrPayload? qrPayload,
    String? numericCode,
    String? friendlyMessage,
    bool? isSyncing,
    bool clearQrPayload = false,
    bool clearFriendlyMessage = false,
  }) {
    return CareShareState(
      status: status ?? this.status,
      session: session ?? this.session,
      qrPayload: clearQrPayload ? null : qrPayload ?? this.qrPayload,
      numericCode: numericCode ?? this.numericCode,
      friendlyMessage: clearFriendlyMessage
          ? null
          : friendlyMessage ?? this.friendlyMessage,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  CareShareState copyWithSession(CareShareSession next) {
    return copyWith(
      status: next.status,
      session: next,
      numericCode: next.numericCode,
    );
  }
}

class CareShareController extends AsyncNotifier<CareShareState> {
  StreamSubscription<CareRealtimeEvent>? _realtimeSubscription;
  Future<CarePendingProcessingResult>? _pendingCareSync;

  @override
  Future<CareShareState> build() async {
    final realtimeService = ref.read(careRealtimeServiceProvider);
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
      unawaited(realtimeService.disconnect());
    });
    final current = await ref.read(careRepositoryProvider).currentShare();
    if (current == null) {
      return const CareShareState.idle();
    }
    final secret = await ref
        .read(careSecretStoreProvider)
        .read(current.shareId);
    _connectRealtime();
    final next = CareShareState.fromSession(
      current,
      qrPayload: secret == null
          ? null
          : CareQrPayload(
              shareId: current.shareId,
              numericCode: current.numericCode,
              secretBase64: secret,
            ),
    );
    Future<void>.microtask(() {
      unawaited(syncPendingCare());
    });
    return next;
  }

  Future<void> generateAccess() async {
    await _realtimeSubscription?.cancel();
    state = const AsyncData(CareShareState.generating());

    state = await AsyncValue.guard(() async {
      final secret = _secureRandomBytes(32);
      final secretBase64 = base64UrlEncode(secret);
      final repository = ref.read(careRepositoryProvider);
      final crypto = ref.read(careCryptoServiceProvider);
      final session = await repository.createShareSession();
      final source = await repository.loadCareReportSource();
      final key = await crypto.deriveSessionKey(
        shareSecret: secret,
        shareId: session.shareId,
        purpose: 'clinical-report-v1',
      );
      final encrypted = await crypto.encryptJson(
        key: key,
        shareId: session.shareId,
        json: source,
      );
      final updated = await repository.uploadEncryptedReport(
        shareId: session.shareId,
        payload: encrypted,
      );
      await ref
          .read(careSecretStoreProvider)
          .save(updated.shareId, secretBase64);
      _connectRealtime();
      ref.invalidate(careShareHistoryProvider);
      return CareShareState.fromSession(
        updated,
        qrPayload: CareQrPayload(
          shareId: updated.shareId,
          numericCode: updated.numericCode,
          secretBase64: secretBase64,
        ),
      );
    });
  }

  Future<void> refreshStatus() async {
    final current = state.asData?.value;
    final shareId = current?.shareId;
    if (shareId == null) {
      return;
    }
    final previous = current!;
    try {
      final session = await ref
          .read(careRepositoryProvider)
          .getShareStatus(shareId);
      state = AsyncData(previous.copyWithSession(session));
      if (session.status.isTerminal) {
        await _realtimeSubscription?.cancel();
        await ref.read(careRealtimeServiceProvider).disconnect();
      }
    } catch (_) {
      state = AsyncData(
        previous.copyWith(
          friendlyMessage:
              'Não foi possível atualizar o status agora. Tentaremos novamente em instantes.',
        ),
      );
    }
  }

  Future<CarePendingProcessingResult> syncPendingCare({bool manual = false}) {
    final running = _pendingCareSync;
    if (running != null) {
      return running;
    }

    final current = state.asData?.value;
    if (current == null) {
      return Future.value(const CarePendingProcessingResult.empty());
    }

    final operation = _syncPendingCare(current, manual: manual);
    _pendingCareSync = operation;
    return operation.whenComplete(() {
      _pendingCareSync = null;
    });
  }

  Future<CarePendingProcessingResult> _syncPendingCare(
    CareShareState initialState, {
    required bool manual,
  }) async {
    state = AsyncData(
      initialState.copyWith(isSyncing: true, clearFriendlyMessage: manual),
    );
    var result = const CarePendingProcessingResult.empty();

    try {
      final prescriptionResult = await ref
          .read(carePrescriptionHandlerProvider)
          .applyPendingDetailed();
      final recommendationResult = await ref
          .read(careRecommendationHandlerProvider)
          .applyPendingDetailed();
      result = prescriptionResult.merge(recommendationResult);

      if (result.applied || manual) {
        ref.invalidate(dailyRitualControllerProvider);
        ref.invalidate(careRecommendationsProvider);
        ref.invalidate(careShareHistoryProvider);
      }

      final shareId = initialState.shareId;
      if (shareId != null) {
        try {
          final session = await ref
              .read(careRepositoryProvider)
              .getShareStatus(shareId);
          state = AsyncData(
            (state.asData?.value ?? initialState)
                .copyWithSession(session)
                .copyWith(isSyncing: false),
          );
          if (session.status.isTerminal) {
            await _realtimeSubscription?.cancel();
            await ref.read(careRealtimeServiceProvider).disconnect();
          }
        } catch (_) {
          state = AsyncData(
            (state.asData?.value ?? initialState).copyWith(isSyncing: false),
          );
        }
      } else {
        state = AsyncData(
          (state.asData?.value ?? initialState).copyWith(isSyncing: false),
        );
      }
      return result;
    } catch (_) {
      state = AsyncData(
        (state.asData?.value ?? initialState).copyWith(isSyncing: false),
      );
      return result.merge(
        const CarePendingProcessingResult(
          applied: false,
          failed: true,
          attempted: true,
        ),
      );
    }
  }

  Future<void> revokeAccess() async {
    final current = state.asData?.value;
    final shareId = current?.shareId;
    if (current == null || shareId == null) {
      return;
    }
    state = AsyncData(current.copyWith(status: CareAccessStatus.revoking));
    try {
      final revoked = await ref
          .read(careRepositoryProvider)
          .revokeShare(shareId);
      await _realtimeSubscription?.cancel();
      await ref.read(careRealtimeServiceProvider).disconnect();
      state = AsyncData(
        current.copyWithSession(revoked).copyWith(clearQrPayload: true),
      );
      ref.invalidate(careShareHistoryProvider);
    } catch (_) {
      state = AsyncData(
        current.copyWith(
          status: current.session?.status ?? CareAccessStatus.active,
          friendlyMessage: 'Não foi possível revogar agora. Tente novamente.',
        ),
      );
    }
  }

  void _connectRealtime() {
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) return;

    unawaited(_realtimeSubscription?.cancel());
    final stream = ref
        .read(careRealtimeServiceProvider)
        .connect(userId: session.userId, accessToken: session.accessToken);
    _realtimeSubscription = stream.listen(_handleRealtimeEvent);
  }

  Future<void> _handleRealtimeEvent(CareRealtimeEvent event) async {
    final current = state.asData?.value;
    if (current == null || event.shareId != current.shareId) return;

    if (event.isClaimed) {
      state = AsyncData(current.copyWith(status: CareAccessStatus.connected));
      return;
    }

    if (event.isRevoked || event.isExpired) {
      final status = event.isRevoked
          ? CareAccessStatus.revoked
          : CareAccessStatus.expired;
      await _realtimeSubscription?.cancel();
      await ref.read(careRealtimeServiceProvider).disconnect();
      state = AsyncData(current.copyWith(status: status, clearQrPayload: true));
      return;
    }

    if (event.isPrescriptionCreated) {
      final applied = await ref
          .read(carePrescriptionHandlerProvider)
          .applyRealtimeEvent(event);
      if (applied) {
        ref.invalidate(dailyRitualControllerProvider);
      }
      return;
    }

    if (event.isRecommendationCreated) {
      final applied = await ref
          .read(careRecommendationHandlerProvider)
          .applyRealtimeEvent(event);
      if (applied) {
        ref.invalidate(careRecommendationsProvider);
      }
    }
  }

  List<int> _secureRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
