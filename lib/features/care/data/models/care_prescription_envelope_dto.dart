import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_prescription_envelope.dart';

class CarePrescriptionEnvelopeDto {
  const CarePrescriptionEnvelopeDto({
    required this.prescriptionId,
    required this.shareId,
    required this.encryptedPayload,
    required this.createdAt,
    this.therapistLabel,
  });

  final String prescriptionId;
  final String shareId;
  final CareEncryptedPayload encryptedPayload;
  final DateTime createdAt;
  final String? therapistLabel;

  factory CarePrescriptionEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['encryptedPayload'];
    return CarePrescriptionEnvelopeDto(
      prescriptionId: json['prescriptionId']?.toString() ?? '',
      shareId: json['shareId']?.toString() ?? '',
      encryptedPayload: rawPayload is Map<String, dynamic>
          ? CareEncryptedPayload.fromJson(rawPayload)
          : const CareEncryptedPayload(
              algorithm: '',
              nonceBase64: '',
              cipherTextBase64: '',
              macBase64: '',
            ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      therapistLabel: json['therapistLabel']?.toString(),
    );
  }

  CarePrescriptionEnvelope toEntity() {
    return CarePrescriptionEnvelope(
      prescriptionId: prescriptionId,
      shareId: shareId,
      encryptedPayload: encryptedPayload,
      createdAt: createdAt,
      therapistLabel: therapistLabel,
    );
  }
}
