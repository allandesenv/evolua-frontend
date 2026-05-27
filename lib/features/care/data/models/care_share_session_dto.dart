import 'package:evolua_frontend/features/care/domain/entities/care_access_status.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_share_session.dart';

class CareShareSessionDto {
  const CareShareSessionDto({
    required this.shareId,
    required this.numericCode,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.claimedAt,
    this.revokedAt,
    this.updatedAt,
  });

  factory CareShareSessionDto.fromJson(Map<String, dynamic> json) {
    return CareShareSessionDto(
      shareId: json['shareId']?.toString() ?? '',
      numericCode: json['numericCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'IDLE',
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
      expiresAt:
          _date(json['expiresAt']) ??
          DateTime.now().add(const Duration(minutes: 15)),
      claimedAt: _date(json['claimedAt']),
      revokedAt: _date(json['revokedAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  final String shareId;
  final String numericCode;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? claimedAt;
  final DateTime? revokedAt;
  final DateTime? updatedAt;

  CareShareSession toEntity() {
    return CareShareSession(
      shareId: shareId,
      numericCode: numericCode,
      status: CareAccessStatus.fromApi(status),
      createdAt: createdAt,
      expiresAt: expiresAt,
      claimedAt: claimedAt,
      revokedAt: revokedAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
