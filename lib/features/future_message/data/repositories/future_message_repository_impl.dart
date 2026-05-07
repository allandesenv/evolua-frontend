import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/network/pagination_query.dart';
import 'package:evolua_frontend/features/future_message/data/models/future_message_dto.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:evolua_frontend/features/future_message/domain/repositories/future_message_repository.dart';

class FutureMessageRepositoryImpl implements FutureMessageRepository {
  const FutureMessageRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<PaginatedResponse<FutureMessage>> list({
    required int page,
    required int size,
    List<String>? statuses,
  }) async {
    final query = PaginationQuery(page: page, size: size);
    final response = await _dio.get<dynamic>(
      '/v1/future-messages',
      queryParameters: query.toQueryParameters({
        if (statuses != null && statuses.isNotEmpty) 'status': statuses,
      }),
    );
    return ApiPayloadParser.paginatedData(
      response.data,
      (item) => FutureMessageDto.fromJson(item).toEntity(),
    );
  }

  @override
  Future<PaginatedResponse<FutureMessage>> delivered({
    required int page,
    required int size,
  }) async {
    final query = PaginationQuery(page: page, size: size);
    final response = await _dio.get<dynamic>(
      '/v1/future-messages/delivered',
      queryParameters: query.toQueryParameters(),
    );
    return ApiPayloadParser.paginatedData(
      response.data,
      (item) => FutureMessageDto.fromJson(item).toEntity(),
    );
  }

  @override
  Future<FutureMessage> get(int id) async {
    final response = await _dio.get<dynamic>('/v1/future-messages/$id');
    return FutureMessageDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<FutureMessage> create(FutureMessageDraft draft) async {
    final response = await _dio.post<dynamic>(
      '/v1/future-messages',
      data: draft.toJson(),
    );
    return FutureMessageDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<FutureMessage> markRead(int id) async {
    final response = await _dio.post<dynamic>('/v1/future-messages/$id/read');
    return FutureMessageDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<FutureMessage> react(int id, String reaction) async {
    final response = await _dio.post<dynamic>(
      '/v1/future-messages/$id/reaction',
      data: {'reaction': reaction},
    );
    return FutureMessageDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<void> heartbeat() async {
    await _dio.post<dynamic>('/v1/future-messages/activity');
  }
}
