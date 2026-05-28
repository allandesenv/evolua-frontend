import 'dart:convert';

import 'package:evolua_frontend/features/care/application/care_attachment_opener.dart';
import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/application/care_pending_processing_result.dart';
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
  return handler.visibleRecommendations(envelopes);
});

class CareRecommendationHandler {
  CareRecommendationHandler(this._ref);

  static const _seenRecommendationsKey =
      'evolua.care.recommendations.seen_notifications';
  static const _hiddenRecommendationsKey =
      'evolua.care.recommendations.hidden_history';

  final Ref _ref;
  final Set<String> _receivedRecommendationIds = <String>{};
  final Set<String> _acknowledgedRecommendationIds = <String>{};
  final Map<String, CareRecommendation> _recommendationCache =
      <String, CareRecommendation>{};
  final Map<String, CareRecommendationEnvelope> _envelopeCache =
      <String, CareRecommendationEnvelope>{};

  Iterable<CareRecommendationEnvelope> visibleEnvelopes(
    Iterable<CareRecommendationEnvelope> envelopes,
    Set<String> hiddenIds,
  ) {
    final minCreatedAt = DateTime.now().subtract(const Duration(days: 30));
    return envelopes.where(
      (item) =>
          !item.createdAt.isBefore(minCreatedAt) &&
          !hiddenIds.contains(item.recommendationId),
    );
  }

  Future<List<CareRecommendation>> visibleRecommendations(
    Iterable<CareRecommendationEnvelope> envelopes,
  ) async {
    final hiddenIds = await _loadHiddenRecommendationIds();
    final itemsById = <String, CareRecommendation>{};
    for (final envelope in visibleEnvelopes(envelopes, hiddenIds)) {
      _rememberEnvelope(envelope);
      final item = await decryptEnvelope(envelope);
      if (item != null) {
        itemsById[item.recommendationId] = item;
      }
    }

    for (final item in _recommendationCache.values) {
      if (_isRecent(item.createdAt) &&
          !hiddenIds.contains(item.recommendationId)) {
        itemsById.putIfAbsent(item.recommendationId, () => item);
      }
    }
    final items = itemsById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<bool> applyRealtimeEvent(CareRealtimeEvent event) async {
    if (event.recommendationId == null) return false;
    return applyPending();
  }

  Future<bool> applyPending() async {
    return (await applyPendingDetailed()).applied;
  }

  Future<CarePendingProcessingResult> applyPendingDetailed() async {
    try {
      final pending = await _ref
          .read(careRepositoryProvider)
          .pendingRecommendations();
      final seen = await _loadSeenRecommendationIds();
      var applied = false;
      var failed = false;
      var attempted = false;
      for (final envelope in pending) {
        attempted = true;
        final recommendation = await decryptEnvelope(envelope);
        if (recommendation != null) {
          final isNewInMemory = _receivedRecommendationIds.add(
            recommendation.recommendationId,
          );
          final isNewPersisted = seen.add(recommendation.recommendationId);
          applied = isNewInMemory && isNewPersisted || applied;
        } else {
          failed = true;
        }
      }
      if (applied || attempted) {
        await _saveSeenRecommendationIds(seen);
        _ref.invalidate(careRecommendationsProvider);
        if (applied) {
          _ref.read(careRecommendationReceivedEventProvider.notifier).emit();
        }
      }
      return CarePendingProcessingResult(
        applied: applied,
        failed: failed,
        attempted: attempted,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Care recommendation ignored (${error.runtimeType}).');
      }
      return const CarePendingProcessingResult(
        applied: false,
        failed: true,
        attempted: true,
      );
    }
  }

  Future<Set<String>> _loadSeenRecommendationIds() async {
    final preferences = await _ref.read(sharedPreferencesProvider.future);
    return preferences.getStringList(_seenRecommendationIdsKey())?.toSet() ??
        <String>{};
  }

  Future<Set<String>> _loadHiddenRecommendationIds() async {
    final preferences = await _ref.read(sharedPreferencesProvider.future);
    return preferences.getStringList(_hiddenRecommendationIdsKey())?.toSet() ??
        <String>{};
  }

  Future<void> hideFromHistory(String recommendationId) async {
    final ids = await _loadHiddenRecommendationIds();
    ids.add(recommendationId);
    _recommendationCache.remove(recommendationId);
    _envelopeCache.remove(recommendationId);
    final preferences = await _ref.read(sharedPreferencesProvider.future);
    await preferences.setStringList(
      _hiddenRecommendationIdsKey(),
      ids.take(200).toList(),
    );
    _ref.invalidate(careRecommendationsProvider);
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

  String _hiddenRecommendationIdsKey() {
    final userId =
        _ref.read(authControllerProvider).asData?.value?.userId ?? 'anonymous';
    return '$_hiddenRecommendationsKey.$userId';
  }

  Future<CareRecommendation?> decryptEnvelope(
    CareRecommendationEnvelope envelope,
  ) async {
    try {
      _rememberEnvelope(envelope);
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
      final recommendation = CareRecommendation(
        recommendationId: envelope.recommendationId,
        shareId: envelope.shareId,
        guidanceText: json['guidanceText']?.toString().trim() ?? '',
        therapistLabel: envelope.therapistLabel,
        createdAt: envelope.createdAt,
        status:
            _acknowledgedRecommendationIds.contains(envelope.recommendationId)
            ? 'READ'
            : envelope.status,
        readAt:
            envelope.readAt ??
            (_acknowledgedRecommendationIds.contains(envelope.recommendationId)
                ? DateTime.now()
                : null),
        attachments: (json['attachments'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => _attachmentFromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
      _rememberRecommendation(recommendation);
      return recommendation;
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
    final envelope = await _findEnvelope(recommendation.recommendationId);
    if (envelope == null) {
      throw const CareAttachmentOpenException();
    }
    final attachmentEnvelope = envelope.attachments
        .where((item) => item.attachmentId == attachment.attachmentId)
        .firstOrNull;
    if (attachmentEnvelope == null) {
      throw const CareAttachmentOpenException();
    }

    final secretBase64 = await _ref
        .read(careSecretStoreProvider)
        .read(envelope.shareId);
    try {
      if (secretBase64 == null || secretBase64.isEmpty) {
        throw const CareAttachmentMissingSecretException();
      }
      final secret = _decodeAttachmentSecret(secretBase64);
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
      await openCareAttachmentFile(
        decrypted,
        _safeFileName(attachment.displayName),
      );
      _acknowledgedRecommendationIds.add(recommendation.recommendationId);
      _rememberRecommendation(
        _asReadRecommendation(recommendation, readAt: DateTime.now()),
      );
      await _ref
          .read(careRepositoryProvider)
          .acknowledgeRecommendation(recommendation.recommendationId);
      _ref.invalidate(careRecommendationsProvider);
    } catch (error) {
      _acknowledgedRecommendationIds.remove(recommendation.recommendationId);
      if (error is CareAttachmentOpenException ||
          error is CareAttachmentMissingSecretException) {
        rethrow;
      }
      throw const CareAttachmentOpenException();
    }
  }

  Future<void> acknowledge(CareRecommendation recommendation) async {
    _acknowledgedRecommendationIds.add(recommendation.recommendationId);
    _ref.invalidate(careRecommendationsProvider);
    try {
      await _ref
          .read(careRepositoryProvider)
          .acknowledgeRecommendation(recommendation.recommendationId);
    } catch (_) {
      _acknowledgedRecommendationIds.remove(recommendation.recommendationId);
      rethrow;
    } finally {
      _ref.invalidate(careRecommendationsProvider);
    }
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

  Future<CareRecommendationEnvelope?> _findEnvelope(
    String recommendationId,
  ) async {
    try {
      final envelopes = await _ref
          .read(careRepositoryProvider)
          .recommendations();
      for (final envelope in envelopes) {
        _rememberEnvelope(envelope);
        if (envelope.recommendationId == recommendationId) {
          return envelope;
        }
      }
    } catch (_) {
      // Keep the local cache as a fallback for temporary API inconsistencies.
    }
    return _envelopeCache[recommendationId];
  }

  void _rememberEnvelope(CareRecommendationEnvelope envelope) {
    if (_isRecent(envelope.createdAt)) {
      _envelopeCache[envelope.recommendationId] = envelope;
    } else {
      _envelopeCache.remove(envelope.recommendationId);
    }
  }

  void _rememberRecommendation(CareRecommendation recommendation) {
    if (_isRecent(recommendation.createdAt)) {
      _recommendationCache[recommendation.recommendationId] = recommendation;
    } else {
      _recommendationCache.remove(recommendation.recommendationId);
    }
  }

  CareRecommendation _asReadRecommendation(
    CareRecommendation recommendation, {
    required DateTime readAt,
  }) {
    return CareRecommendation(
      recommendationId: recommendation.recommendationId,
      shareId: recommendation.shareId,
      guidanceText: recommendation.guidanceText,
      attachments: recommendation.attachments,
      createdAt: recommendation.createdAt,
      status: 'READ',
      readAt: recommendation.readAt ?? readAt,
      therapistLabel: recommendation.therapistLabel,
    );
  }

  bool _isRecent(DateTime createdAt) {
    final minCreatedAt = DateTime.now().subtract(const Duration(days: 30));
    return !createdAt.isBefore(minCreatedAt);
  }

  List<int> _decodeAttachmentSecret(String secretBase64) {
    try {
      return base64Url.decode(base64.normalize(secretBase64));
    } catch (_) {
      throw const CareAttachmentMissingSecretException();
    }
  }
}

class CareAttachmentOpenException implements Exception {
  const CareAttachmentOpenException();
}

class CareAttachmentMissingSecretException implements Exception {
  const CareAttachmentMissingSecretException();
}
