import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';

abstract class FutureMessageRepository {
  Future<PaginatedResponse<FutureMessage>> list({
    required int page,
    required int size,
    List<String>? statuses,
  });

  Future<PaginatedResponse<FutureMessage>> delivered({
    required int page,
    required int size,
  });

  Future<FutureMessage> get(int id);

  Future<FutureMessage> create(FutureMessageDraft draft);

  Future<FutureMessage> markRead(int id);

  Future<FutureMessage> react(int id, String reaction);

  Future<void> heartbeat();
}
