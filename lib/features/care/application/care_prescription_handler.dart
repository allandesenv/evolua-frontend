import 'dart:convert';

import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/application/care_repository_provider.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_event.dart';
import 'package:evolua_frontend/features/care/application/care_secret_store.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_prescription_envelope.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
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

  Future<bool> applyRealtimeEvent(CareRealtimeEvent event) async {
    final prescriptionId = event.prescriptionId;
    final payload = event.encryptedPayload;
    if (prescriptionId == null || payload == null) return false;

    return applyEnvelope(
      CarePrescriptionEnvelope(
        prescriptionId: prescriptionId,
        shareId: event.shareId,
        encryptedPayload: payload,
        createdAt: event.occurredAt,
      ),
    );
  }

  Future<bool> applyEnvelope(CarePrescriptionEnvelope envelope) async {
    try {
      final secretBase64 = await _ref
          .read(careSecretStoreProvider)
          .read(envelope.shareId);
      if (secretBase64 == null || secretBase64.isEmpty) return false;

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
      _ref.read(carePrescriptionAppliedEventProvider.notifier).emit();
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Care prescription ignored (${error.runtimeType}).');
      }
      return false;
    }
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
