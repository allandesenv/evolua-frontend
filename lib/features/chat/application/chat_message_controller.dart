import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/chat/data/repositories/chat_message_repository_impl.dart';
import 'package:evolua_frontend/features/chat/domain/entities/chat_message.dart';
import 'package:evolua_frontend/features/chat/domain/repositories/chat_message_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatMessageRepositoryProvider = Provider<ChatMessageRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.chatBaseUrl));
  return ChatMessageRepositoryImpl(dio);
});

final chatMessageControllerProvider =
    AsyncNotifierProvider<ChatMessageController, List<ChatMessage>>(ChatMessageController.new);

class ChatMessageController extends AsyncNotifier<List<ChatMessage>> {
  @override
  Future<List<ChatMessage>> build() async {
    return ref.watch(chatMessageRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(chatMessageRepositoryProvider).list();
    });
  }

  Future<void> create({
    required String recipientId,
    required String content,
  }) async {
    final repository = ref.read(chatMessageRepositoryProvider);
    final currentItems = state.asData?.value ?? const <ChatMessage>[];

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final created = await repository.create(
        recipientId: recipientId,
        content: content,
      );

      return [created, ...currentItems];
    });
  }
}
