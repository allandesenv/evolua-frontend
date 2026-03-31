import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/network/pagination_query.dart';
import 'package:evolua_frontend/features/chat/data/models/chat_message_dto.dart';
import 'package:evolua_frontend/features/chat/domain/entities/chat_message.dart';
import 'package:evolua_frontend/features/chat/domain/repositories/chat_message_repository.dart';

class ChatMessageRepositoryImpl implements ChatMessageRepository {
  const ChatMessageRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<PaginatedResponse<ChatMessage>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? recipientId,
  }) async {
    final query = PaginationQuery(
      page: page,
      size: size,
      search: search,
      sortBy: sortBy,
      sortDir: sortDir,
    );

    final response = await _dio.get<dynamic>(
      '/v1/messages',
      queryParameters: query.toQueryParameters({
        'recipientId': recipientId,
      }),
    );

    return ApiPayloadParser.paginatedData(
      response.data,
      (item) => ChatMessageDto.fromJson(item).toEntity(),
    );
  }

  @override
  Future<ChatMessage> create({
    required String recipientId,
    required String content,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/messages',
      data: {
        'recipientId': recipientId,
        'content': content,
      },
    );

    return ChatMessageDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }
}
