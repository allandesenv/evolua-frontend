import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/care/data/models/care_prescription_envelope_dto.dart';
import 'package:evolua_frontend/features/care/data/models/care_share_session_dto.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_prescription_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_share_session.dart';
import 'package:evolua_frontend/features/care/domain/repositories/care_repository.dart';

class CareRepositoryImpl implements CareRepository {
  const CareRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<CareShareSession?> currentShare() async {
    final response = await _dio.get<dynamic>('/v1/care/shares/current');
    final raw = response.data;
    if (raw is Map<String, dynamic> && raw['data'] == null) {
      return null;
    }
    return CareShareSessionDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<CareShareSession> createShareSession() async {
    final response = await _dio.post<dynamic>('/v1/care/shares');
    return CareShareSessionDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<CareShareSession> getShareStatus(String shareId) async {
    final response = await _dio.get<dynamic>('/v1/care/shares/$shareId');
    return CareShareSessionDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<CareShareSession> uploadEncryptedReport({
    required String shareId,
    required CareEncryptedPayload payload,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/care/shares/$shareId/encrypted-report',
      data: payload.toJson(),
    );
    return CareShareSessionDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<CareShareSession> revokeShare(String shareId) async {
    final response = await _dio.post<dynamic>(
      '/v1/care/shares/$shareId/revoke',
    );
    return CareShareSessionDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<Map<String, dynamic>> loadCareReportSource() async {
    final checkIns = await _dio.get<dynamic>(
      '/v1/check-ins',
      queryParameters: {
        'page': 0,
        'size': 30,
        'sortBy': 'createdAt',
        'sortDir': 'desc',
      },
    );
    final rituals = await _dio.get<dynamic>(
      '/v1/daily-rituals',
      queryParameters: {
        'start': _formatDate(DateTime.now().subtract(const Duration(days: 30))),
        'end': _formatDate(DateTime.now()),
      },
    );
    final payload = ApiPayloadParser.dataMap(checkIns.data);
    return {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'checkIns': payload['items'] ?? const [],
      'dailyRituals': ApiPayloadParser.dataList(rituals.data),
      'source': 'evolua-mobile',
      'version': 1,
    };
  }

  @override
  Future<List<CareShareSession>> shareHistory() async {
    final response = await _dio.get<dynamic>('/v1/care/shares/history');
    return ApiPayloadParser.dataList(
      response.data,
    ).map((item) => CareShareSessionDto.fromJson(item).toEntity()).toList();
  }

  @override
  Future<List<CarePrescriptionEnvelope>> pendingPrescriptions() async {
    final response = await _dio.get<dynamic>('/v1/care/prescriptions/pending');
    return ApiPayloadParser.dataList(response.data)
        .map((item) => CarePrescriptionEnvelopeDto.fromJson(item).toEntity())
        .toList();
  }

  @override
  Future<void> acknowledgePrescription(String prescriptionId) async {
    await _dio.post<dynamic>('/v1/care/prescriptions/$prescriptionId/ack');
  }

  String _formatDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }
}
