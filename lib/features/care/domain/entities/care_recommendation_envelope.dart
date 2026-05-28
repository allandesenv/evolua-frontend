import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';

class CareRecommendationEnvelope {
  const CareRecommendationEnvelope({
    required this.recommendationId,
    required this.shareId,
    required this.encryptedPayload,
    required this.attachments,
    required this.createdAt,
    this.status = 'NEW',
    this.readAt,
    this.therapistLabel,
  });

  final String recommendationId;
  final String shareId;
  final CareEncryptedPayload encryptedPayload;
  final List<CareRecommendationAttachmentEnvelope> attachments;
  final DateTime createdAt;
  final String status;
  final DateTime? readAt;
  final String? therapistLabel;

  bool get isRead {
    final normalized = status.toUpperCase();
    return normalized == 'READ' || normalized == 'OPENED' || readAt != null;
  }
}

class CareRecommendationAttachmentEnvelope {
  const CareRecommendationAttachmentEnvelope({
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
}

class CareRecommendation {
  const CareRecommendation({
    required this.recommendationId,
    required this.shareId,
    required this.guidanceText,
    required this.attachments,
    required this.createdAt,
    this.status = 'NEW',
    this.readAt,
    this.therapistLabel,
  });

  final String recommendationId;
  final String shareId;
  final String guidanceText;
  final List<CareRecommendationAttachment> attachments;
  final DateTime createdAt;
  final String status;
  final DateTime? readAt;
  final String? therapistLabel;

  bool get isRead {
    final normalized = status.toUpperCase();
    return normalized == 'READ' || normalized == 'OPENED' || readAt != null;
  }
}

class CareRecommendationAttachment {
  const CareRecommendationAttachment({
    required this.attachmentId,
    required this.displayName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String attachmentId;
  final String displayName;
  final String contentType;
  final int sizeBytes;
}
