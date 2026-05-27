import 'dart:convert';

import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';

class CareRealtimeEvent {
  const CareRealtimeEvent({
    required this.type,
    required this.shareId,
    required this.occurredAt,
    this.status,
    this.prescriptionId,
    this.recommendationId,
    this.encryptedPayload,
  });

  final String type;
  final String shareId;
  final String? status;
  final String? prescriptionId;
  final String? recommendationId;
  final CareEncryptedPayload? encryptedPayload;
  final DateTime occurredAt;

  bool get isClaimed => type == CareRealtimeEventType.shareClaimed;
  bool get isRevoked => type == CareRealtimeEventType.shareRevoked;
  bool get isExpired => type == CareRealtimeEventType.shareExpired;
  bool get isPrescriptionCreated =>
      type == CareRealtimeEventType.prescriptionCreated;
  bool get isRecommendationCreated =>
      type == CareRealtimeEventType.recommendationCreated;

  factory CareRealtimeEvent.fromStompBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Evento Evolua Care inválido.');
    }
    return CareRealtimeEvent.fromJson(decoded);
  }

  factory CareRealtimeEvent.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['encryptedPayload'];
    return CareRealtimeEvent(
      type: json['type']?.toString() ?? '',
      shareId: json['shareId']?.toString() ?? '',
      status: json['status']?.toString(),
      prescriptionId: json['prescriptionId']?.toString(),
      recommendationId: json['recommendationId']?.toString(),
      encryptedPayload: rawPayload is Map<String, dynamic>
          ? CareEncryptedPayload.fromJson(rawPayload)
          : null,
      occurredAt:
          DateTime.tryParse(json['occurredAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class CareRealtimeEventType {
  const CareRealtimeEventType._();

  static const shareClaimed = 'CARE_SHARE_CLAIMED';
  static const shareRevoked = 'CARE_SHARE_REVOKED';
  static const shareExpired = 'CARE_SHARE_EXPIRED';
  static const prescriptionCreated = 'CARE_PRESCRIPTION_CREATED';
  static const recommendationCreated = 'CARE_RECOMMENDATION_CREATED';
}
