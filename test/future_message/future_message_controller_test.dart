import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_controller.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_ready_summary_controller.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message_ready_summary.dart';
import 'package:evolua_frontend/features/future_message/domain/repositories/future_message_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loads, refreshes and mutates future messages without heartbeat',
    () async {
      final repository = _CountingFutureMessageRepository(
        throwOnHeartbeat: true,
      );
      final container = ProviderContainer(
        overrides: [
          futureMessageRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final initialState = await container.read(
        futureMessageControllerProvider.future,
      );

      expect(repository.listCalls, 1);
      expect(repository.deliveredCalls, 1);
      expect(repository.readySummaryCalls, 0);
      expect(repository.heartbeatCalls, 0);
      expect(initialState.delivered.items, repository.deliveredMessages);
      expect(initialState.readyToRead.map((message) => message.id), [2]);

      repository.resetCounters();
      final notifier = container.read(futureMessageControllerProvider.notifier);

      await notifier.refresh();
      expect(repository.listCalls, 1);
      expect(repository.deliveredCalls, 1);
      expect(repository.heartbeatCalls, 0);

      repository.resetCounters();
      final fetched = await notifier.get(42);
      expect(fetched.id, 42);
      expect(repository.getCalls, 1);
      expect(repository.getIds, [42]);
      expect(repository.listCalls, 0);
      expect(repository.deliveredCalls, 0);
      expect(repository.heartbeatCalls, 0);

      repository.resetCounters();
      await notifier.create(_draft());
      expect(repository.createCalls, 1);
      expect(repository.listCalls, 1);
      expect(repository.deliveredCalls, 1);
      expect(repository.heartbeatCalls, 0);

      repository.resetCounters();
      await notifier.markRead(2);
      expect(repository.markReadCalls, 1);
      expect(repository.markReadIds, [2]);
      expect(repository.listCalls, 1);
      expect(repository.deliveredCalls, 1);
      expect(repository.readySummaryCalls, 0);
      expect(repository.heartbeatCalls, 0);

      repository.resetCounters();
      await notifier.react(3, 'heart');
      expect(repository.reactCalls, 1);
      expect(repository.reactIds, [3]);
      expect(repository.reactions, ['heart']);
      expect(repository.listCalls, 1);
      expect(repository.deliveredCalls, 1);
      expect(repository.heartbeatCalls, 0);
    },
  );

  test('ready summary does not request without authenticated user', () async {
    final repository = _CountingFutureMessageRepository();
    final container = ProviderContainer(
      overrides: [
        authSessionStorageProvider.overrideWithValue(
          _MemoryAuthSessionStorage(null),
        ),
        futureMessageRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final summary = await _readSummary(container);

    expect(summary.hasReady, isFalse);
    expect(summary.firstMessageId, isNull);
    expect(repository.readySummaryCalls, 0);
    expect(repository.deliveredCalls, 0);
  });

  test(
    'ready summary falls back only for unsupported endpoint responses',
    () async {
      for (final statusCode in [404, 405, 501]) {
        final repository = _CountingFutureMessageRepository(
          readySummaryError: _dioStatus(statusCode),
          deliveredMessages: [
            _message(id: 1, status: 'READ'),
            _message(id: 2, status: 'DELIVERED'),
          ],
        );
        final summary = await loadFutureMessageReadySummaryWithFallback(
          repository,
        );

        expect(summary.hasReady, isTrue);
        expect(summary.firstMessageId, 2);
        expect(repository.readySummaryCalls, 1);
        expect(repository.deliveredCalls, 1);
      }
    },
  );

  test('ready summary empty fallback keeps hasReady false', () async {
    final repository = _CountingFutureMessageRepository(
      readySummaryError: _dioStatus(404),
      deliveredMessages: [_message(id: 1, status: 'READ')],
    );
    final summary = await loadFutureMessageReadySummaryWithFallback(repository);

    expect(summary.hasReady, isFalse);
    expect(summary.firstMessageId, isNull);
    expect(repository.readySummaryCalls, 1);
    expect(repository.deliveredCalls, 1);
  });

  test('ready summary does not fall back for other errors', () async {
    for (final statusCode in [401, 403, 500]) {
      final repository = _CountingFutureMessageRepository(
        readySummaryError: _dioStatus(statusCode),
      );
      await expectLater(
        loadFutureMessageReadySummaryWithFallback(repository),
        throwsA(isA<DioException>()),
      );

      expect(repository.readySummaryCalls, 1);
      expect(repository.deliveredCalls, 0);
    }
  });
}

Future<FutureMessageReadySummary> _readSummary(ProviderContainer container) {
  final subscription = container.listen(
    futureMessageReadySummaryControllerProvider,
    (_, _) {},
  );
  addTearDown(subscription.close);
  return container.read(futureMessageReadySummaryControllerProvider.future);
}

FutureMessageDraft _draft() {
  return const FutureMessageDraft(
    title: 'Future me',
    body: 'Keep going',
    triggerType: 'DAYS_FROM_NOW',
    triggerConfig: {'days': 30},
  );
}

class _CountingFutureMessageRepository implements FutureMessageRepository {
  _CountingFutureMessageRepository({
    this.throwOnHeartbeat = false,
    this.readySummaryError,
    List<FutureMessage>? deliveredMessages,
  }) : deliveredMessages =
           deliveredMessages ??
           [
             _message(id: 2, status: 'DELIVERED'),
             _message(id: 3, status: 'READ'),
           ];

  final bool throwOnHeartbeat;
  final Object? readySummaryError;

  int listCalls = 0;
  int deliveredCalls = 0;
  int readySummaryCalls = 0;
  int heartbeatCalls = 0;
  int createCalls = 0;
  int getCalls = 0;
  int markReadCalls = 0;
  int reactCalls = 0;

  final List<int> getIds = [];
  final List<int> markReadIds = [];
  final List<int> reactIds = [];
  final List<String> reactions = [];

  final List<FutureMessage> deliveredMessages;

  void resetCounters() {
    listCalls = 0;
    deliveredCalls = 0;
    readySummaryCalls = 0;
    heartbeatCalls = 0;
    createCalls = 0;
    getCalls = 0;
    markReadCalls = 0;
    reactCalls = 0;
    getIds.clear();
    markReadIds.clear();
    reactIds.clear();
    reactions.clear();
  }

  @override
  Future<PaginatedResponse<FutureMessage>> list({
    required int page,
    required int size,
    List<String>? statuses,
  }) async {
    listCalls += 1;
    return PaginatedResponse<FutureMessage>.empty(
      page: page,
      size: size,
    ).copyWith(items: [_message(id: 1, status: 'SCHEDULED')]);
  }

  @override
  Future<PaginatedResponse<FutureMessage>> delivered({
    required int page,
    required int size,
  }) async {
    deliveredCalls += 1;
    return PaginatedResponse<FutureMessage>.empty(
      page: page,
      size: size,
    ).copyWith(items: deliveredMessages);
  }

  @override
  Future<FutureMessageReadySummary> readySummary() async {
    readySummaryCalls += 1;
    final error = readySummaryError;
    if (error != null) {
      throw error;
    }
    return const FutureMessageReadySummary.empty();
  }

  @override
  Future<void> heartbeat() async {
    heartbeatCalls += 1;
    if (throwOnHeartbeat) {
      throw StateError('heartbeat should not be called');
    }
  }

  @override
  Future<FutureMessage> create(FutureMessageDraft draft) async {
    createCalls += 1;
    return _message(id: 10, status: 'SCHEDULED');
  }

  @override
  Future<FutureMessage> get(int id) async {
    getCalls += 1;
    getIds.add(id);
    return _message(id: id, status: 'DELIVERED');
  }

  @override
  Future<FutureMessage> markRead(int id) async {
    markReadCalls += 1;
    markReadIds.add(id);
    return _message(id: id, status: 'READ');
  }

  @override
  Future<FutureMessage> react(int id, String reaction) async {
    reactCalls += 1;
    reactIds.add(id);
    reactions.add(reaction);
    return _message(id: id, status: 'READ', reaction: reaction);
  }
}

FutureMessage _message({
  required int id,
  required String status,
  String? reaction,
}) {
  return FutureMessage(
    id: id,
    title: 'Message $id',
    body: 'Body $id',
    bodyPreview: 'Body $id',
    triggerType: 'DAYS_FROM_NOW',
    triggerConfig: const {'days': 30},
    triggerLabel: 'Em 30 dias',
    status: status,
    createdContext: const {},
    deliveredContext: const {},
    createdAt: DateTime(2026, 6, 1),
    deliveredAt: status == 'SCHEDULED' ? null : DateTime(2026, 6, 2),
    readAt: status == 'READ' ? DateTime(2026, 6, 3) : null,
    reaction: reaction,
  );
}

DioException _dioStatus(int statusCode) {
  final requestOptions = RequestOptions(
    path: '/v1/future-messages/ready-summary',
  );
  return DioException(
    requestOptions: requestOptions,
    response: Response<dynamic>(
      requestOptions: requestOptions,
      statusCode: statusCode,
    ),
  );
}

class _MemoryAuthSessionStorage implements AuthSessionStorage {
  _MemoryAuthSessionStorage(this.value);

  String? value;

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
