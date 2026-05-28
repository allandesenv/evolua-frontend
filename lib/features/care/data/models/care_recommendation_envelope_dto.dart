import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_recommendation_envelope.dart';

class CareRecommendationEnvelopeDto {
  const CareRecommendationEnvelopeDto({
    required this.recommendationId,
    required this.shareId,
    required this.encryptedPayload,
    required this.attachments,
    required this.createdAt,
    required this.status,
    this.readAt,
    this.therapistLabel,
  });

  final String recommendationId;
  final String shareId;
  final CareEncryptedPayload encryptedPayload;
  final List<CareRecommendationAttachmentEnvelopeDto> attachments;
  final DateTime createdAt;
  final String status;
  final DateTime? readAt;
  final String? therapistLabel;

  factory CareRecommendationEnvelopeDto.fromJson(Map<String, dynamic> json) {
    return CareRecommendationEnvelopeDto(
      recommendationId: json['recommendationId']?.toString() ?? '',
      shareId: json['shareId']?.toString() ?? '',
      encryptedPayload: CareEncryptedPayload.fromJson(
        Map<String, dynamic>.from(json['encryptedPayload'] as Map? ?? const {}),
      ),
      attachments: (json['attachments'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => CareRecommendationAttachmentEnvelopeDto.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      therapistLabel: json['therapistLabel']?.toString(),
      status: json['status']?.toString() ?? 'NEW',
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? '')?.toLocal(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  CareRecommendationEnvelope toEntity() => CareRecommendationEnvelope(
    recommendationId: recommendationId,
    shareId: shareId,
    encryptedPayload: encryptedPayload,
    attachments: attachments.map((item) => item.toEntity()).toList(),
    status: status,
    readAt: readAt,
    therapistLabel: therapistLabel,
    createdAt: createdAt,
  );
}

class CareRecommendationAttachmentEnvelopeDto {
  const CareRecommendationAttachmentEnvelopeDto({
    required this.attachmentId,
    required this.encryptedMetadata,
    required this.sizeBytes,
    this.contentType,
    this.createdAt,
  });

  final String attachmentId;
  final CareEncryptedPayload encryptedMetadata;
  final int sizeBytes;
  final String? contentType;
  final DateTime? createdAt;

  factory CareRecommendationAttachmentEnvelopeDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return CareRecommendationAttachmentEnvelopeDto(
      attachmentId: json['attachmentId']?.toString() ?? '',
      encryptedMetadata: CareEncryptedPayload(
        algorithm: json['algorithm']?.toString() ?? 'AES-256-GCM',
        nonceBase64: json['nonceBase64']?.toString() ?? '',
        cipherTextBase64: '',
        macBase64: json['macBase64']?.toString() ?? '',
      ),
      contentType: json['contentType']?.toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  CareRecommendationAttachmentEnvelope toEntity() =>
      CareRecommendationAttachmentEnvelope(
        attachmentId: attachmentId,
        encryptedMetadata: encryptedMetadata,
        contentType: contentType,
        sizeBytes: sizeBytes,
        createdAt: createdAt,
      );
}
