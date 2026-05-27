import 'package:evolua_frontend/features/care/domain/entities/care_access_status.dart';

class CareShareSession {
  const CareShareSession({
    required this.shareId,
    required this.numericCode,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.claimedAt,
    this.revokedAt,
    this.updatedAt,
  });

  final String shareId;
  final String numericCode;
  final CareAccessStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? claimedAt;
  final DateTime? revokedAt;
  final DateTime? updatedAt;

  bool get isExpired =>
      status == CareAccessStatus.expired || expiresAt.isBefore(DateTime.now());
}
