import 'dart:convert';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/application/care_pending_processing_result.dart';
import 'package:evolua_frontend/features/care/application/care_repository_provider.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_event.dart';
import 'package:evolua_frontend/features/care/application/care_secret_store.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_prescription_envelope.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/notification/application/notification_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final carePrescriptionHandlerProvider = Provider<CarePrescriptionHandler>((
  ref,
) {
  return CarePrescriptionHandler(ref);
});

final carePrescriptionAppliedEventProvider =
    NotifierProvider<CarePrescriptionAppliedEvent, int>(
      CarePrescriptionAppliedEvent.new,
    );

class CarePrescriptionAppliedEvent extends Notifier<int> {
  @override
  int build() => 0;

  void emit() => state = state + 1;
}

class CarePrescriptionHandler {
  CarePrescriptionHandler(this._ref);

  final Ref _ref;
  final Set<String> _appliedPrescriptionIds = <String>{};

  Future<bool> applyRealtimeEvent(CareRealtimeEvent event) async {
    final prescriptionId = event.prescriptionId;
    final payload = event.encryptedPayload;
    if (prescriptionId == null || prescriptionId.isEmpty) return false;

    if (payload == null) {
      return applyPending(prescriptionId: prescriptionId);
    }

    return applyEnvelope(
      CarePrescriptionEnvelope(
        prescriptionId: prescriptionId,
        shareId: event.shareId,
        encryptedPayload: payload,
        createdAt: event.occurredAt,
      ),
    );
  }

  Future<bool> applyPending({String? prescriptionId}) async {
    return (await applyPendingDetailed(prescriptionId: prescriptionId)).applied;
  }

  Future<CarePendingProcessingResult> applyPendingDetailed({
    String? prescriptionId,
  }) async {
    try {
      final pending = await _ref
          .read(careRepositoryProvider)
          .pendingPrescriptions();
      var applied = false;
      var failed = false;
      var attempted = false;
      for (final envelope in pending) {
        if (prescriptionId != null &&
            prescriptionId.isNotEmpty &&
            envelope.prescriptionId != prescriptionId) {
          continue;
        }
        attempted = true;
        final result = await applyEnvelopeDetailed(envelope);
        applied = result.applied || applied;
        failed = result.failed || failed;
      }
      return CarePendingProcessingResult(
        applied: applied,
        failed: failed,
        attempted: attempted,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Care pending prescriptions ignored (${error.runtimeType}).',
        );
      }
      return const CarePendingProcessingResult(
        applied: false,
        failed: true,
        attempted: true,
      );
    }
  }

  Future<bool> applyEnvelope(CarePrescriptionEnvelope envelope) async {
    return (await applyEnvelopeDetailed(envelope)).applied;
  }

  Future<CarePendingProcessingResult> applyEnvelopeDetailed(
    CarePrescriptionEnvelope envelope,
  ) async {
    if (_appliedPrescriptionIds.contains(envelope.prescriptionId)) {
      return const CarePendingProcessingResult(
        applied: true,
        failed: false,
        attempted: true,
      );
    }
    try {
      final secretBase64 = await _ref
          .read(careSecretStoreProvider)
          .read(envelope.shareId);
      if (secretBase64 == null || secretBase64.isEmpty) {
        return const CarePendingProcessingResult(
          applied: false,
          failed: true,
          attempted: true,
        );
      }

      final secret = base64Url.decode(base64.normalize(secretBase64));
      final crypto = _ref.read(careCryptoServiceProvider);
      final key = await crypto.deriveSessionKey(
        shareSecret: secret,
        shareId: envelope.shareId,
        purpose: 'custom-ritual-v1',
      );
      final json = await crypto.decryptJson(
        key: key,
        shareId: envelope.shareId,
        payload: envelope.encryptedPayload,
        purpose: CareCryptoPayloadPurpose.customRitual,
      );
      final draft = _draftFromJson(json);
      await _ref.read(dailyRitualControllerProvider.notifier).create(draft);
      await _ref
          .read(careRepositoryProvider)
          .acknowledgePrescription(envelope.prescriptionId);
      _appliedPrescriptionIds.add(envelope.prescriptionId);
      await _tryAddCareNotification(
        prescriptionId: envelope.prescriptionId,
        ritualType: draft.type,
      );
      _ref.read(carePrescriptionAppliedEventProvider.notifier).emit();
      _ref.invalidate(dailyRitualControllerProvider);
      return const CarePendingProcessingResult(
        applied: true,
        failed: false,
        attempted: true,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Care prescription ignored (${error.runtimeType}).');
      }
      return const CarePendingProcessingResult(
        applied: false,
        failed: true,
        attempted: true,
      );
    }
  }

  Future<void> _tryAddCareNotification({
    required String prescriptionId,
    required String ritualType,
  }) async {
    final userId = await _resolveCurrentUserId();
    if (userId == null) {
      return;
    }
    try {
      final result = await _ref
          .read(localCareNotificationServiceProvider)
          .addPrescription(
            userId: userId,
            prescriptionId: prescriptionId,
            ritualType: ritualType,
          );
      if (result.changed && _currentUserId == userId) {
        _ref
            .read(notificationUnreadCountControllerProvider.notifier)
            .applyLocalCareDelta(userId, result.unreadDelta);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Care notification ignored (${error.runtimeType}).');
      }
    }
  }

  String? get _currentUserId {
    final userId = _ref.read(authControllerProvider).asData?.value?.userId;
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return userId;
  }

  Future<String?> _resolveCurrentUserId() async {
    final current = _currentUserId;
    if (current != null) {
      return current;
    }
    final userId = (await _ref.read(authControllerProvider.future))?.userId;
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return userId;
  }

  DailyRitualDraft _draftFromJson(Map<String, dynamic> json) {
    final type = _requiredString(json, 'type').toUpperCase();
    if (type != DailyRitualType.morning && type != DailyRitualType.evening) {
      throw const FormatException('Tipo de ritual inválido.');
    }

    final localDate = DateTime.tryParse(_requiredString(json, 'localDate'));
    if (localDate == null) {
      throw const FormatException('Data do ritual inválida.');
    }

    return DailyRitualDraft(
      localDate: localDate,
      type: type,
      emotionalState: _requiredString(json, 'emotionalState'),
      dayNeed: _requiredString(json, 'dayNeed'),
      intention: _requiredString(json, 'intention'),
      microAction: _requiredString(json, 'microAction'),
    );
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim();
    if (value == null || value.isEmpty) {
      throw FormatException('Campo obrigatório ausente: $key');
    }
    return value;
  }
}
