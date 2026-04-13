import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/content/data/repositories/journey_chat_repository_impl.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_message.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_reply.dart';
import 'package:evolua_frontend/features/content/domain/repositories/journey_chat_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final journeyChatRepositoryProvider = Provider<JourneyChatRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.aiBaseUrl));
  return JourneyChatRepositoryImpl(dio);
});

final journeyChatControllerProvider = Provider<JourneyChatController>((ref) {
  return JourneyChatController(ref.watch(journeyChatRepositoryProvider));
});

class JourneyChatController {
  const JourneyChatController(this._repository);

  final JourneyChatRepository _repository;

  Future<JourneyChatReply> send({
    required String message,
    required List<JourneyChatMessage> conversationHistory,
    int? trailId,
  }) {
    return _repository.send(
      message: message,
      conversationHistory: conversationHistory.take(6).toList(),
      trailId: trailId,
    );
  }
}
