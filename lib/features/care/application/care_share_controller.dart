import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/application/care_prescription_handler.dart';
import 'package:evolua_frontend/features/care/application/care_qr_payload.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_event.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_service.dart';
import 'package:evolua_frontend/features/care/application/care_repository_provider.dart';
import 'package:evolua_frontend/features/care/application/care_secret_store.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_access_status.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_share_session.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
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
  });

  const CareShareState.idle()
    : status = CareAccessStatus.idle,
      session = null,
      qrPayload = null,
      numericCode = null,
      friendlyMessage = null;

  const CareShareState.generating()
    : status = CareAccessStatus.generating,
      session = null,
      qrPayload = null,
      numericCode = null,
      friendlyMessage = null;

  final CareAccessStatus status;
  final CareShareSession? session;
  final CareQrPayload? qrPayload;
  final String? numericCode;
  final String? friendlyMessage;

  String? get shareId => session?.shareId;
  DateTime? get expiresAt => session?.expiresAt;
  bool get hasActiveAccess =>
      status == CareAccessStatus.active || status == CareAccessStatus.connected;

  factory CareShareState.fromSession(
    CareShareSession session, {
    CareQrPayload? qrPayload,
    String? friendlyMessage,
  }) {
    return CareShareState(
      status: session.status,
      session: session,
      qrPayload: qrPayload,
      numericCode: session.numericCode,
      friendlyMessage: friendlyMessage,
    );
  }

  CareShareState copyWith({
    CareAccessStatus? status,
    CareShareSession? session,
    CareQrPayload? qrPayload,
    String? numericCode,
    String? friendlyMessage,
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
    unawaited(_applyPendingPrescriptions());
    return CareShareState.fromSession(
      current,
      qrPayload: secret == null
          ? null
          : CareQrPayload(
              shareId: current.shareId,
              numericCode: current.numericCode,
              secretBase64: secret,
            ),
    );
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
      await ref.read(careSecretStoreProvider).delete(shareId);
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
      await ref.read(careSecretStoreProvider).delete(event.shareId);
      await _realtimeSubscription?.cancel();
      await ref.read(careRealtimeServiceProvider).disconnect();
      state = AsyncData(current.copyWith(status: status, clearQrPayload: true));
      return;
    }

    if (event.isPrescriptionCreated) {
      await ref.read(carePrescriptionHandlerProvider).applyRealtimeEvent(event);
    }
  }

  Future<void> _applyPendingPrescriptions() async {
    try {
      final pending = await ref
          .read(careRepositoryProvider)
          .pendingPrescriptions();
      final handler = ref.read(carePrescriptionHandlerProvider);
      for (final envelope in pending) {
        await handler.applyEnvelope(envelope);
      }
    } catch (_) {
      return;
    }
  }

  List<int> _secureRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
