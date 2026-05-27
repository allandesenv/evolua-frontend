import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_prescription_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_share_session.dart';

abstract class CareRepository {
  Future<CareShareSession?> currentShare();
  Future<CareShareSession> createShareSession();
  Future<CareShareSession> getShareStatus(String shareId);
  Future<CareShareSession> uploadEncryptedReport({
    required String shareId,
    required CareEncryptedPayload payload,
  });
  Future<CareShareSession> revokeShare(String shareId);
  Future<Map<String, dynamic>> loadCareReportSource();
  Future<List<CareShareSession>> shareHistory();
  Future<List<CarePrescriptionEnvelope>> pendingPrescriptions();
  Future<void> acknowledgePrescription(String prescriptionId);
}
