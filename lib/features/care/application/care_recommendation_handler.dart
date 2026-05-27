import 'dart:convert';

import 'package:evolua_frontend/features/care/application/care_attachment_opener.dart';
import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/application/care_repository_provider.dart';
import 'package:evolua_frontend/features/care/application/care_realtime_event.dart';
import 'package:evolua_frontend/features/care/application/care_secret_store.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_recommendation_envelope.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final careRecommendationHandlerProvider = Provider<CareRecommendationHandler>((
  ref,
) {
  return CareRecommendationHandler(ref);
});

final careRecommendationReceivedEventProvider =
    NotifierProvider<CareRecommendationReceivedEvent, int>(
      CareRecommendationReceivedEvent.new,
    );

class CareRecommendationReceivedEvent extends Notifier<int> {
  @override
  int build() => 0;

  void emit() => state = state + 1;
}

final careRecommendationsProvider = FutureProvider<List<CareRecommendation>>((
  ref,
) async {
  final handler = ref.read(careRecommendationHandlerProvider);
  final envelopes = await ref.read(careRepositoryProvider).recommendations();
  final items = <CareRecommendation>[];
  for (final envelope in envelopes) {
    final item = await handler.decryptEnvelope(envelope);
    if (item != null) items.add(item);
  }
  return items;
});

class CareRecommendationHandler {
  CareRecommendationHandler(this._ref);

  static const _seenRecommendationsKey =
      'evolua.care.recommendations.seen_notifications';

  final Ref _ref;
  final Set<String> _receivedRecommendationIds = <String>{};

  Future<bool> applyRealtimeEvent(CareRealtimeEvent event) async {
    if (event.recommendationId == null) return false;
    return applyPending();
  }

  Future<bool> applyPending() async {
    try {
      final pending = await _ref
          .read(careRepositoryProvider)
          .pendingRecommendations();
      final seen = await _loadSeenRecommendationIds();
      var applied = false;
      for (final envelope in pending) {
        final recommendation = await decryptEnvelope(envelope);
        if (recommendation != null) {
          final isNewInMemory = _receivedRecommendationIds.add(
            recommendation.recommendationId,
          );
          final isNewPersisted = seen.add(recommendation.recommendationId);
          applied = isNewInMemory && isNewPersisted || applied;
        }
      }
      if (applied) {
        await _saveSeenRecommendationIds(seen);
        _ref.invalidate(careRecommendationsProvider);
        _ref.read(careRecommendationReceivedEventProvider.notifier).emit();
      }
      return applied;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Care recommendation ignored (${error.runtimeType}).');
      }
      return false;
    }
  }

  Future<Set<String>> _loadSeenRecommendationIds() async {
    final preferences = await _ref.read(sharedPreferencesProvider.future);
    return preferences.getStringList(_seenRecommendationIdsKey())?.toSet() ??
        <String>{};
  }

  Future<void> _saveSeenRecommendationIds(Set<String> ids) async {
    final preferences = await _ref.read(sharedPreferencesProvider.future);
    await preferences.setStringList(
      _seenRecommendationIdsKey(),
      ids.take(100).toList(),
    );
  }

  String _seenRecommendationIdsKey() {
    final userId =
        _ref.read(authControllerProvider).asData?.value?.userId ?? 'anonymous';
    return '$_seenRecommendationsKey.$userId';
  }

  Future<CareRecommendation?> decryptEnvelope(
    CareRecommendationEnvelope envelope,
  ) async {
    try {
      final secretBase64 = await _ref
          .read(careSecretStoreProvider)
          .read(envelope.shareId);
      if (secretBase64 == null || secretBase64.isEmpty) return null;
      final secret = base64Url.decode(base64.normalize(secretBase64));
      final crypto = _ref.read(careCryptoServiceProvider);
      final key = await crypto.deriveSessionKey(
        shareSecret: secret,
        shareId: envelope.shareId,
        purpose: 'care-guidance-v1',
      );
      final json = await crypto.decryptJson(
        key: key,
        shareId: envelope.shareId,
        payload: envelope.encryptedPayload,
        purpose: CareCryptoPayloadPurpose.guidance,
      );
      return CareRecommendation(
        recommendationId: envelope.recommendationId,
        shareId: envelope.shareId,
        guidanceText: json['guidanceText']?.toString().trim() ?? '',
        therapistLabel: envelope.therapistLabel,
        createdAt: envelope.createdAt,
        attachments: (json['attachments'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => _attachmentFromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Care recommendation decrypt failed (${error.runtimeType}).',
        );
      }
      return null;
    }
  }

  Future<void> openAttachment({
    required CareRecommendation recommendation,
    required CareRecommendationAttachment attachment,
  }) async {
    final envelope = (await _ref.read(careRepositoryProvider).recommendations())
        .where(
          (item) => item.recommendationId == recommendation.recommendationId,
        )
        .firstOrNull;
    if (envelope == null) return;
    final attachmentEnvelope = envelope.attachments
        .where((item) => item.attachmentId == attachment.attachmentId)
        .firstOrNull;
    if (attachmentEnvelope == null) return;

    final secretBase64 = await _ref
        .read(careSecretStoreProvider)
        .read(envelope.shareId);
    if (secretBase64 == null || secretBase64.isEmpty) return;
    final secret = base64Url.decode(base64.normalize(secretBase64));
    final crypto = _ref.read(careCryptoServiceProvider);
    final key = await crypto.deriveSessionKey(
      shareSecret: secret,
      shareId: envelope.shareId,
      purpose: 'care-attachment-v1',
    );
    final encryptedBytes = await _ref
        .read(careRepositoryProvider)
        .downloadRecommendationAttachment(
          recommendationId: recommendation.recommendationId,
          attachmentId: attachment.attachmentId,
        );
    final decrypted = await crypto.decryptBytes(
      key: key,
      shareId: envelope.shareId,
      payload: CareEncryptedPayload(
        algorithm: attachmentEnvelope.encryptedMetadata.algorithm,
        nonceBase64: attachmentEnvelope.encryptedMetadata.nonceBase64,
        cipherTextBase64: base64UrlEncode(encryptedBytes),
        macBase64: attachmentEnvelope.encryptedMetadata.macBase64,
      ),
      purpose: CareCryptoPayloadPurpose.attachment,
    );
    await _ref
        .read(careRepositoryProvider)
        .acknowledgeRecommendation(recommendation.recommendationId);
    await openCareAttachmentFile(
      decrypted,
      _safeFileName(attachment.displayName),
    );
    _ref.invalidate(careRecommendationsProvider);
  }

  Future<void> acknowledge(CareRecommendation recommendation) async {
    await _ref
        .read(careRepositoryProvider)
        .acknowledgeRecommendation(recommendation.recommendationId);
    _ref.invalidate(careRecommendationsProvider);
  }

  CareRecommendationAttachment _attachmentFromJson(Map<String, dynamic> json) {
    return CareRecommendationAttachment(
      attachmentId: json['attachmentId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Anexo seguro',
      contentType:
          json['contentType']?.toString() ?? 'application/octet-stream',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'anexo-evolua-care' : sanitized;
  }
}
