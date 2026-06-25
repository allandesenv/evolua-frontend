import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_repository_provider.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message_ready_summary.dart';
import 'package:evolua_frontend/features/future_message/domain/repositories/future_message_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final futureMessageReadySummaryControllerProvider =
    FutureProvider.autoDispose<FutureMessageReadySummary>((ref) async {
      final session = await ref.watch(authControllerProvider.future);
      final userId = session?.userId;
      if (userId == null) {
        return const FutureMessageReadySummary.empty();
      }

      final repository = ref.watch(futureMessageRepositoryProvider);
      final summary = await loadFutureMessageReadySummaryWithFallback(
        repository,
      );
      final currentUserId = (await ref.read(
        authControllerProvider.future,
      ))?.userId;
      if (currentUserId != userId) {
        return const FutureMessageReadySummary.empty();
      }
      return summary;
    });

Future<FutureMessageReadySummary> loadFutureMessageReadySummaryWithFallback(
  FutureMessageRepository repository,
) async {
  try {
    return await repository.readySummary();
  } on DioException catch (error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != 404 && statusCode != 405 && statusCode != 501) {
      rethrow;
    }
    final delivered = await repository.delivered(page: 0, size: 20);
    return _summaryFromDelivered(delivered);
  }
}

FutureMessageReadySummary _summaryFromDelivered(
  PaginatedResponse<FutureMessage> delivered,
) {
  final ready = delivered.items.where((item) => !item.isRead).firstOrNull;
  if (ready == null) {
    return const FutureMessageReadySummary.empty();
  }
  return FutureMessageReadySummary(hasReady: true, firstMessageId: ready.id);
}
