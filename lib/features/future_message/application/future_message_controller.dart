import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_repository_provider.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_ready_summary_controller.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:evolua_frontend/features/future_message/application/future_message_repository_provider.dart';

final futureMessageControllerProvider =
    AsyncNotifierProvider<FutureMessageController, FutureMessageState>(
      FutureMessageController.new,
    );

class FutureMessageState {
  const FutureMessageState({required this.result, required this.delivered});

  final PaginatedResponse<FutureMessage> result;
  final PaginatedResponse<FutureMessage> delivered;

  List<FutureMessage> get readyToRead =>
      delivered.items.where((item) => !item.isRead).toList();
}

class FutureMessageController extends AsyncNotifier<FutureMessageState> {
  static const _pageSize = 20;

  @override
  Future<FutureMessageState> build() async {
    return _load();
  }

  Future<FutureMessageState> _load() async {
    final repository = ref.read(futureMessageRepositoryProvider);
    final result = await repository.list(page: 0, size: _pageSize);
    final delivered = await repository.delivered(page: 0, size: _pageSize);
    return FutureMessageState(result: result, delivered: delivered);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<FutureMessage> create(FutureMessageDraft draft) async {
    final repository = ref.read(futureMessageRepositoryProvider);
    final created = await repository.create(draft);
    await refresh();
    return created;
  }

  Future<FutureMessage> get(int id) {
    return ref.read(futureMessageRepositoryProvider).get(id);
  }

  Future<FutureMessage> markRead(int id) async {
    final updated = await ref
        .read(futureMessageRepositoryProvider)
        .markRead(id);
    ref.invalidate(futureMessageReadySummaryControllerProvider);
    await refresh();
    return updated;
  }

  Future<FutureMessage> react(int id, String reaction) async {
    final updated = await ref
        .read(futureMessageRepositoryProvider)
        .react(id, reaction);
    await refresh();
    return updated;
  }
}
