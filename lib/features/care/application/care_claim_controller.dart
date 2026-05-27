import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final careClaimControllerProvider =
    AsyncNotifierProvider<CareClaimController, CareClaimState>(
      CareClaimController.new,
    );

class CareClaimState {
  const CareClaimState({
    required this.shareId,
    required this.numericCode,
    required this.secretBase64,
    required this.report,
    this.sessionExpiresAt,
    this.isSendingPrescription = false,
    this.successMessage,
  });

  final String shareId;
  final String numericCode;
  final String secretBase64;
  final CareClinicalReport report;
  final DateTime? sessionExpiresAt;
  final bool isSendingPrescription;
  final String? successMessage;

  CareClaimState copyWith({
    bool? isSendingPrescription,
    String? successMessage,
    bool clearSuccessMessage = false,
  }) {
    return CareClaimState(
      shareId: shareId,
      numericCode: numericCode,
      secretBase64: secretBase64,
      report: report,
      sessionExpiresAt: sessionExpiresAt,
      isSendingPrescription:
          isSendingPrescription ?? this.isSendingPrescription,
      successMessage: clearSuccessMessage
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}

class CareClinicalReport {
  const CareClinicalReport({
    required this.generatedAt,
    required this.checkIns,
    required this.rituals,
  });

  final DateTime? generatedAt;
  final List<CareClinicalCheckIn> checkIns;
  final List<CareClinicalRitual> rituals;

  String get latestInsight {
    for (final item in checkIns) {
      final insight = item.aiInsight;
      if (insight != null && insight.isNotEmpty) return insight;
    }
    return 'Ainda não há um insight consolidado neste relatório.';
  }

  int get completedRituals => rituals.length;
}

class CareClinicalCheckIn {
  const CareClinicalCheckIn({
    required this.mood,
    required this.energyLevel,
    required this.createdAt,
    this.aiInsight,
  });

  final String mood;
  final int? energyLevel;
  final DateTime? createdAt;
  final String? aiInsight;
}

class CareClinicalRitual {
  const CareClinicalRitual({
    required this.type,
    required this.localDate,
    required this.intention,
    required this.microAction,
  });

  final String type;
  final DateTime? localDate;
  final String intention;
  final String microAction;
}

class CareClaimController extends AsyncNotifier<CareClaimState> {
  late final Dio _dio;

  @override
  Future<CareClaimState> build() async {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    final uri = Uri.base;
    final shareId = uri.queryParameters['sid']?.trim() ?? '';
    final code = uri.queryParameters['code']?.trim() ?? '';
    final secret = _secretFromFragment(uri.fragment);
    if (shareId.isEmpty || code.isEmpty || secret.isEmpty) {
      throw const FormatException('Link do Evolua Care incompleto.');
    }

    final claim = await _dio.post<dynamic>(
      '/v1/public/care/shares/$shareId/claim',
      data: {'numericCode': code},
    );
    final session = ApiPayloadParser.dataMap(claim.data);

    final reportResponse = await _dio.get<dynamic>(
      '/v1/public/care/shares/$shareId/encrypted-report',
      queryParameters: {'code': code},
    );
    final encryptedReport = CareEncryptedPayload.fromJson(
      ApiPayloadParser.dataMap(reportResponse.data),
    );
    final report = await _decryptClinicalReport(
      shareId: shareId,
      secretBase64: secret,
      payload: encryptedReport,
    );

    return CareClaimState(
      shareId: shareId,
      numericCode: code,
      secretBase64: secret,
      report: report,
      sessionExpiresAt: DateTime.tryParse(
        session['expiresAt']?.toString() ?? '',
      )?.toLocal(),
    );
  }

  Future<void> sendPrescription({
    required String type,
    required DateTime localDate,
    required String emotionalState,
    required String intention,
    required String microAction,
  }) async {
    final current = state.asData?.value;
    if (current == null || current.isSendingPrescription) return;
    state = AsyncData(
      current.copyWith(isSendingPrescription: true, clearSuccessMessage: true),
    );
    try {
      final secret = base64Url.decode(base64.normalize(current.secretBase64));
      final crypto = ref.read(careCryptoServiceProvider);
      final key = await crypto.deriveSessionKey(
        shareSecret: secret,
        shareId: current.shareId,
        purpose: 'custom-ritual-v1',
      );
      final payload = await crypto.encryptJson(
        key: key,
        shareId: current.shareId,
        purpose: CareCryptoPayloadPurpose.customRitual,
        json: DailyRitualDraft(
          localDate: localDate,
          type: type,
          emotionalState: emotionalState.trim().isEmpty
              ? 'contexto terapêutico'
              : emotionalState.trim(),
          dayNeed: 'prescrição terapêutica',
          intention: intention.trim(),
          microAction: microAction.trim(),
        ).toJson(),
      );
      await _dio.post<dynamic>(
        '/v1/public/care/shares/${current.shareId}/prescriptions',
        data: {
          'numericCode': current.numericCode,
          'therapistLabel': 'Terapeuta',
          'encryptedPayload': payload.toJson(),
        },
      );
      state = AsyncData(
        current.copyWith(
          isSendingPrescription: false,
          successMessage: 'Ritual enviado ao paciente com segurança.',
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isSendingPrescription: false));
      rethrow;
    }
  }

  Future<CareClinicalReport> _decryptClinicalReport({
    required String shareId,
    required String secretBase64,
    required CareEncryptedPayload payload,
  }) async {
    final secret = base64Url.decode(base64.normalize(secretBase64));
    final crypto = ref.read(careCryptoServiceProvider);
    final key = await crypto.deriveSessionKey(
      shareSecret: secret,
      shareId: shareId,
      purpose: 'clinical-report-v1',
    );
    final json = await crypto.decryptJson(
      key: key,
      shareId: shareId,
      payload: payload,
      purpose: CareCryptoPayloadPurpose.clinicalReport,
    );
    return _parseReport(json);
  }

  CareClinicalReport _parseReport(Map<String, dynamic> json) {
    final checkIns = (json['checkIns'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(_parseCheckIn)
        .toList();
    final rituals = (json['dailyRituals'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(_parseRitual)
        .toList();
    return CareClinicalReport(
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      checkIns: checkIns,
      rituals: rituals,
    );
  }

  CareClinicalCheckIn _parseCheckIn(Map<String, dynamic> json) {
    final rawInsight = json['aiInsight'];
    String? insight;
    if (rawInsight is Map) {
      insight = rawInsight['insight']?.toString();
    }
    return CareClinicalCheckIn(
      mood: json['mood']?.toString() ?? 'sem registro',
      energyLevel: (json['energyLevel'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      aiInsight: insight,
    );
  }

  CareClinicalRitual _parseRitual(Map<String, dynamic> json) {
    return CareClinicalRitual(
      type: json['type']?.toString() ?? '',
      localDate: DateTime.tryParse(json['localDate']?.toString() ?? ''),
      intention: json['intention']?.toString() ?? '',
      microAction: json['microAction']?.toString() ?? '',
    );
  }

  String _secretFromFragment(String fragment) {
    if (fragment.isEmpty) return '';
    final normalized = fragment.startsWith('#')
        ? fragment.substring(1)
        : fragment;
    return Uri.splitQueryString(normalized)['k']?.trim() ?? '';
  }
}
