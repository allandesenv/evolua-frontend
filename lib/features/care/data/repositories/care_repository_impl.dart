import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/care/data/models/care_prescription_envelope_dto.dart';
import 'package:evolua_frontend/features/care/data/models/care_recommendation_envelope_dto.dart';
import 'package:evolua_frontend/features/care/data/models/care_share_session_dto.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_prescription_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_recommendation_envelope.dart';
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
    final response = await _dio.get<dynamic>('/v1/care/report-source');
    return ApiPayloadParser.dataMap(response.data);
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

  @override
  Future<List<CareRecommendationEnvelope>> pendingRecommendations() async {
    final response = await _dio.get<dynamic>(
      '/v1/care/recommendations/pending',
    );
    return ApiPayloadParser.dataList(response.data)
        .map((item) => CareRecommendationEnvelopeDto.fromJson(item).toEntity())
        .toList();
  }

  @override
  Future<List<CareRecommendationEnvelope>> recommendations() async {
    final response = await _dio.get<dynamic>('/v1/care/recommendations');
    return ApiPayloadParser.dataList(response.data)
        .map((item) => CareRecommendationEnvelopeDto.fromJson(item).toEntity())
        .toList();
  }

  @override
  Future<List<int>> downloadRecommendationAttachment({
    required String recommendationId,
    required String attachmentId,
  }) async {
    final response = await _dio.get<List<int>>(
      '/v1/care/recommendations/$recommendationId/attachments/$attachmentId',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const [];
  }

  @override
  Future<void> acknowledgeRecommendation(String recommendationId) async {
    await _dio.post<dynamic>('/v1/care/recommendations/$recommendationId/ack');
  }
}
