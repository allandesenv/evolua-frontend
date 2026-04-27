import 'package:dio/dio.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_message.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_reply.dart';
import 'package:evolua_frontend/features/content/domain/repositories/journey_chat_repository.dart';

class JourneyChatRepositoryImpl implements JourneyChatRepository {
  const JourneyChatRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<JourneyChatReply> send({
    required String message,
    required List<JourneyChatMessage> conversationHistory,
    int? trailId,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/ai/journey-chat',
      data: {
        'message': message,
        'trailId': trailId,
        'conversationHistory': conversationHistory
            .map((item) => item.toJson())
            .toList(),
      },
    );

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : Map<String, dynamic>.from(response.data as Map);
    return JourneyChatReply.fromJson(data);
  }
}
