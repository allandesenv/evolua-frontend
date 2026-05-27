import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';

class CarePrescriptionEnvelope {
  const CarePrescriptionEnvelope({
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
}
