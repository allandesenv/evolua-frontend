import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/chat/data/repositories/chat_message_repository_impl.dart';
import 'package:evolua_frontend/features/chat/domain/entities/chat_message.dart';
import 'package:evolua_frontend/features/chat/domain/repositories/chat_message_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatMessageRepositoryProvider = Provider<ChatMessageRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.chatBaseUrl));
  return ChatMessageRepositoryImpl(dio);
});

final chatMessageControllerProvider =
    AsyncNotifierProvider<ChatMessageController, PaginatedResponse<ChatMessage>>(ChatMessageController.new);

class ChatMessageController extends AsyncNotifier<PaginatedResponse<ChatMessage>> {
  static const _pageSize = 5;
  String? _search;
  String? _recipientId;

  @override
  Future<PaginatedResponse<ChatMessage>> build() async {
    return _fetch(page: 0);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: state.asData?.value.page ?? 0));
  }

  Future<void> applyFilters({
    String? search,
    String? recipientId,
  }) async {
    _search = search;
    _recipientId = recipientId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: 0));
  }

  Future<void> goToPage(int page) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetch(page: page));
  }

  Future<void> create({
    required String recipientId,
    required String content,
  }) async {
    final repository = ref.read(chatMessageRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.create(
        recipientId: recipientId,
        content: content,
      );

      return _fetch(page: 0);
    });
  }

  void prependRealtime(ChatMessage message) {
    final currentPage = state.asData?.value ?? PaginatedResponse<ChatMessage>.empty(size: _pageSize);
    final currentItems = currentPage.items;
    final alreadyPresent = currentItems.any((item) => item.id == message.id);

    if (alreadyPresent) {
      return;
    }

    final nextItems = [message, ...currentItems].take(currentPage.size).toList();
    state = AsyncData(
      currentPage.copyWith(
        items: nextItems,
        totalItems: currentPage.totalItems + 1,
      ),
    );
  }

  Future<PaginatedResponse<ChatMessage>> _fetch({required int page}) {
    return ref.read(chatMessageRepositoryProvider).list(
          page: page,
          size: _pageSize,
          search: _search,
          recipientId: _recipientId,
        );
  }
}
