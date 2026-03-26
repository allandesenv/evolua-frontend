import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/chat/data/models/chat_message_dto.dart';
import 'package:evolua_frontend/features/chat/domain/entities/chat_message.dart';
import 'package:evolua_frontend/features/chat/domain/repositories/chat_message_repository.dart';

class ChatMessageRepositoryImpl implements ChatMessageRepository {
  const ChatMessageRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<ChatMessage>> list() async {
    final response = await _dio.get<dynamic>('/v1/messages');

    return ApiPayloadParser.dataList(response.data)
        .map(ChatMessageDto.fromJson)
        .map((item) => item.toEntity())
        .toList();
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
