import 'dart:async';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hydrates latest created check-in from initial history', () async {
    final latest = _checkIn(
      id: 10,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: _insight(),
    );
    final previous = _checkIn(
      id: 9,
      createdAt: DateTime(2026, 5, 4, 10),
      aiInsight: null,
    );
    final container = _container(
      _FakeCheckInRepository(
        lists: [
          [latest, previous],
        ],
      ),
    );
    addTearDown(container.dispose);

    final state = await container.read(checkInControllerProvider.future);

    expect(state.latestCreatedCheckIn, same(latest));
    expect(state.latestCreatedCheckIn?.aiInsight?.insight, 'Leitura salva.');
  });

  test('create reconciles partial response with listed insight', () async {
    final createdWithoutInsight = _checkIn(
      id: 99,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: null,
    );
    final listedWithInsight = _checkIn(
      id: 99,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: _insight(insight: 'Leitura enriquecida.'),
    );
    final repository = _FakeCheckInRepository(
      createResult: createdWithoutInsight,
      lists: [
        const <CheckIn>[],
        [listedWithInsight],
      ],
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(checkInControllerProvider.future);

    await container
        .read(checkInControllerProvider.notifier)
        .create(mood: 'calmo', reflection: null, energyLevel: 7);

    final state = container.read(checkInControllerProvider).asData?.value;
    expect(state?.latestCreatedCheckIn?.id, 99);
    expect(
      state?.latestCreatedCheckIn?.aiInsight?.insight,
      'Leitura enriquecida.',
    );
    expect(repository.getByIdCalls, 0);
  });

  test('create with ready insight does not start polling', () async {
    final createdWithInsight = _checkIn(
      id: 98,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: _insight(insight: 'Leitura pronta no POST.'),
    );
    final listedWithoutInsight = _checkIn(
      id: 98,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: null,
    );
    final repository = _FakeCheckInRepository(
      createResult: createdWithInsight,
      lists: [
        const <CheckIn>[],
        [listedWithoutInsight],
      ],
    );
    final container = _container(
      repository,
      pollingConfig: const CheckInInsightPollingConfig(
        delays: [Duration(milliseconds: 1)],
      ),
    );
    addTearDown(container.dispose);
    await container.read(checkInControllerProvider.future);

    await container
        .read(checkInControllerProvider.notifier)
        .create(mood: 'calmo', reflection: null, energyLevel: 7);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(checkInControllerProvider).asData?.value;
    expect(
      state?.latestCreatedCheckIn?.aiInsight?.insight,
      'Leitura pronta no POST.',
    );
    expect(repository.getByIdCalls, 0);
  });

  test('create succeeds when refresh after saved check-in fails', () async {
    final created = _checkIn(
      id: 100,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: null,
    );
    final requestOptions = RequestOptions(path: '/v1/check-ins');
    final repository = _FakeCheckInRepository(
      createResult: created,
      lists: [const <CheckIn>[]],
      listErrors: [
        DioException(
          requestOptions: requestOptions,
          response: Response(requestOptions: requestOptions, statusCode: 503),
        ),
      ],
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(checkInControllerProvider.future);

    await container
        .read(checkInControllerProvider.notifier)
        .create(mood: 'calmo', reflection: 'salvo', energyLevel: 7);

    final state = container.read(checkInControllerProvider).asData?.value;
    expect(repository.createCalls, 1);
    expect(state?.latestCreatedCheckIn?.id, 100);
    expect(state?.result.items.first.id, 100);
    expect(state?.isCreatingCheckIn, isFalse);
    expect(container.read(checkInControllerProvider).hasError, isFalse);
  });

  test(
    'create ignores parallel duplicate submissions while in flight',
    () async {
      final gate = Completer<void>();
      final initial = _checkIn(
        id: 60,
        createdAt: DateTime(2026, 5, 4, 10),
        aiInsight: _insight(insight: 'Leitura anterior.'),
      );
      final created = _checkIn(
        id: 61,
        createdAt: DateTime(2026, 5, 5, 10),
        aiInsight: _insight(insight: 'Leitura nova.'),
      );
      final repository = _FakeCheckInRepository(
        createGate: gate,
        createResult: created,
        lists: [
          [initial],
          [created, initial],
        ],
      );
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(checkInControllerProvider.future);

      final first = container
          .read(checkInControllerProvider.notifier)
          .create(mood: 'calmo', reflection: 'um', energyLevel: 7);
      final second = container
          .read(checkInControllerProvider.notifier)
          .create(mood: 'calmo', reflection: 'dois', energyLevel: 7);
      await Future<void>.delayed(Duration.zero);

      expect(repository.createCalls, 1);
      expect(
        container.read(checkInControllerProvider).value?.isCreatingCheckIn,
        isTrue,
      );

      gate.complete();
      await Future.wait([first, second]);

      final state = container.read(checkInControllerProvider).asData?.value;
      expect(repository.createCalls, 1);
      expect(state?.isCreatingCheckIn, isFalse);
      expect(state?.latestCreatedCheckIn?.id, 61);
    },
  );

  test('create releases duplicate guard after failure', () async {
    final requestOptions = RequestOptions(path: '/v1/check-ins');
    final repository = _FakeCheckInRepository(
      lists: [const <CheckIn>[], const <CheckIn>[]],
      createErrors: [
        DioException(
          requestOptions: requestOptions,
          response: Response(requestOptions: requestOptions, statusCode: 503),
        ),
      ],
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(checkInControllerProvider.future);

    await expectLater(
      container
          .read(checkInControllerProvider.notifier)
          .create(mood: 'calmo', reflection: null, energyLevel: 7),
      throwsA(isA<DioException>()),
    );

    await container
        .read(checkInControllerProvider.notifier)
        .create(mood: 'calmo', reflection: null, energyLevel: 7);

    expect(repository.createCalls, 2);
    expect(
      container.read(checkInControllerProvider).value?.isCreatingCheckIn,
      isFalse,
    );
  });

  test(
    'polling updates latest created check-in when insight arrives later',
    () async {
      final createdWithoutInsight = _checkIn(
        id: 40,
        createdAt: DateTime(2026, 5, 5, 10),
        aiInsight: null,
      );
      final listedWithInsight = _checkIn(
        id: 40,
        createdAt: DateTime(2026, 5, 5, 10),
        aiInsight: _insight(insight: 'Leitura chegou depois.'),
      );
      final repository = _FakeCheckInRepository(
        createResult: createdWithoutInsight,
        getByIdResults: [
          createdWithoutInsight,
          createdWithoutInsight,
          listedWithInsight,
        ],
        lists: [const <CheckIn>[], const <CheckIn>[]],
      );
      final container = _container(
        repository,
        pollingConfig: const CheckInInsightPollingConfig(
          delays: [
            Duration(milliseconds: 1),
            Duration(milliseconds: 1),
            Duration(milliseconds: 1),
          ],
        ),
      );
      addTearDown(container.dispose);
      await container.read(checkInControllerProvider.future);

      await container
          .read(checkInControllerProvider.notifier)
          .create(mood: 'calmo', reflection: null, energyLevel: 7);

      var state = container.read(checkInControllerProvider).asData?.value;
      expect(state?.latestCreatedCheckIn?.id, 40);
      expect(state?.latestCreatedCheckIn?.aiInsight, isNull);
      expect(state?.isLatestInsightPending, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 120));

      state = container.read(checkInControllerProvider).asData?.value;
      expect(repository.getByIdCalls, 3);
      expect(repository.listCalls, 2);
      expect(
        state?.latestCreatedCheckIn?.aiInsight?.insight,
        'Leitura chegou depois.',
      );
      expect(state?.isLatestInsightPending, isFalse);
    },
  );

  test(
    'polling marks insight unavailable after attempts are exhausted',
    () async {
      final createdWithoutInsight = _checkIn(
        id: 41,
        createdAt: DateTime(2026, 5, 5, 10),
        aiInsight: null,
      );
      final repository = _FakeCheckInRepository(
        createResult: createdWithoutInsight,
        getByIdResults: [createdWithoutInsight],
        lists: [
          const <CheckIn>[],
          [createdWithoutInsight],
        ],
      );
      final container = _container(
        repository,
        pollingConfig: const CheckInInsightPollingConfig(
          delays: [Duration(milliseconds: 1)],
        ),
      );
      addTearDown(container.dispose);
      await container.read(checkInControllerProvider.future);

      await container
          .read(checkInControllerProvider.notifier)
          .create(mood: 'calmo', reflection: null, energyLevel: 7);

      var state = container.read(checkInControllerProvider).asData?.value;
      expect(state?.isLatestInsightPending, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      state = container.read(checkInControllerProvider).asData?.value;
      expect(repository.getByIdCalls, 1);
      expect(state?.pendingInsightCheckInId, isNull);
      expect(state?.unavailableInsightCheckInId, 41);
      expect(state?.isLatestInsightPending, isFalse);
      expect(state?.isLatestInsightUnavailable, isTrue);
    },
  );

  test(
    'polling keeps state visible across transient errors before ready',
    () async {
      final createdWithoutInsight = _checkIn(
        id: 43,
        createdAt: DateTime(2026, 5, 5, 10),
        aiInsight: null,
      );
      final ready = _checkIn(
        id: 43,
        createdAt: DateTime(2026, 5, 5, 10),
        aiInsight: _insight(insight: 'Leitura depois de instabilidade.'),
      );
      final repository = _FakeCheckInRepository(
        createResult: createdWithoutInsight,
        getByIdErrors: [
          DioException.connectionTimeout(
            requestOptions: RequestOptions(path: '/v1/check-ins/43'),
            timeout: const Duration(seconds: 1),
          ),
          DioException.badResponse(
            statusCode: 503,
            requestOptions: RequestOptions(path: '/v1/check-ins/43'),
            response: Response<void>(
              requestOptions: RequestOptions(path: '/v1/check-ins/43'),
              statusCode: 503,
            ),
          ),
        ],
        getByIdResults: [createdWithoutInsight, createdWithoutInsight, ready],
        lists: [
          const <CheckIn>[],
          [createdWithoutInsight],
        ],
      );
      final container = _container(
        repository,
        pollingConfig: const CheckInInsightPollingConfig(
          delays: [
            Duration(milliseconds: 1),
            Duration(milliseconds: 1),
            Duration(milliseconds: 1),
          ],
        ),
      );
      addTearDown(container.dispose);
      await container.read(checkInControllerProvider.future);

      await container
          .read(checkInControllerProvider.notifier)
          .create(mood: 'calmo', reflection: null, energyLevel: 7);

      await Future<void>.delayed(const Duration(milliseconds: 120));

      final state = container.read(checkInControllerProvider);
      expect(state.hasError, isFalse);
      expect(repository.getByIdCalls, 3);
      expect(repository.listCalls, 2);
      expect(
        state.asData?.value.latestCreatedCheckIn?.aiInsight?.insight,
        'Leitura depois de instabilidade.',
      );
    },
  );

  test('dispose cancels pending polling before the next getById', () async {
    final createdWithoutInsight = _checkIn(
      id: 44,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: null,
    );
    final repository = _FakeCheckInRepository(
      createResult: createdWithoutInsight,
      lists: [
        const <CheckIn>[],
        [createdWithoutInsight],
      ],
    );
    final container = _container(
      repository,
      pollingConfig: const CheckInInsightPollingConfig(
        delays: [Duration(milliseconds: 50)],
      ),
    );
    await container.read(checkInControllerProvider.future);

    await container
        .read(checkInControllerProvider.notifier)
        .create(mood: 'calmo', reflection: null, energyLevel: 7);
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(repository.getByIdCalls, 0);
  });

  test('multiple listeners share a single polling sequence', () async {
    final createdWithoutInsight = _checkIn(
      id: 45,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: null,
    );
    final ready = _checkIn(
      id: 45,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: _insight(insight: 'Uma sequencia compartilhada.'),
    );
    final repository = _FakeCheckInRepository(
      createResult: createdWithoutInsight,
      getByIdResults: [ready],
      lists: [
        const <CheckIn>[],
        [createdWithoutInsight],
      ],
    );
    final container = _container(
      repository,
      pollingConfig: const CheckInInsightPollingConfig(
        delays: [Duration(milliseconds: 1)],
      ),
    );
    addTearDown(container.dispose);
    final subA = container.listen(checkInControllerProvider, (_, _) {});
    final subB = container.listen(checkInControllerProvider, (_, _) {});
    addTearDown(subA.close);
    addTearDown(subB.close);
    await container.read(checkInControllerProvider.future);

    await container
        .read(checkInControllerProvider.notifier)
        .create(mood: 'calmo', reflection: null, energyLevel: 7);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(repository.getByIdCalls, 1);
    expect(
      container
          .read(checkInControllerProvider)
          .asData
          ?.value
          .latestCreatedCheckIn
          ?.aiInsight
          ?.insight,
      'Uma sequencia compartilhada.',
    );
  });

  test('session change ignores delayed polling response', () async {
    final createdWithoutInsight = _checkIn(
      id: 46,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: null,
    );
    final ready = _checkIn(
      id: 46,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: _insight(insight: 'Resposta antiga.'),
    );
    final getByIdGate = Completer<CheckIn>();
    final repository = _FakeCheckInRepository(
      createResult: createdWithoutInsight,
      getByIdCompleters: [getByIdGate],
      lists: [
        const <CheckIn>[],
        [createdWithoutInsight],
      ],
    );
    final container = _container(
      repository,
      pollingConfig: const CheckInInsightPollingConfig(
        delays: [Duration(milliseconds: 1)],
      ),
    );
    addTearDown(container.dispose);
    await container.read(checkInControllerProvider.future);

    await container
        .read(checkInControllerProvider.notifier)
        .create(mood: 'calmo', reflection: null, energyLevel: 7);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    (container.read(authControllerProvider.notifier) as _FakeAuthController)
        .setSession(_session(userId: 'user-456'));
    container.read(authSessionGenerationProvider.notifier).bump();
    getByIdGate.complete(ready);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(checkInControllerProvider).asData?.value;
    expect(repository.getByIdCalls, 1);
    expect(state?.latestCreatedCheckIn?.aiInsight, isNull);
    expect(state?.isLatestInsightPending, isTrue);
  });

  test(
    'refresh replaces partial latest check-in with listed full version',
    () async {
      final partial = _checkIn(
        id: 20,
        createdAt: DateTime(2026, 5, 5, 10),
        aiInsight: null,
      );
      final complete = _checkIn(
        id: 20,
        createdAt: DateTime(2026, 5, 5, 10),
        aiInsight: _insight(insight: 'Leitura depois do refresh.'),
      );
      final repository = _FakeCheckInRepository(
        createResult: partial,
        lists: [
          const <CheckIn>[],
          [partial],
          [complete],
        ],
      );
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(checkInControllerProvider.future);
      await container
          .read(checkInControllerProvider.notifier)
          .create(mood: 'calmo', reflection: null, energyLevel: 7);

      await container.read(checkInControllerProvider.notifier).refresh();

      final state = container.read(checkInControllerProvider).asData?.value;
      expect(
        state?.latestCreatedCheckIn?.aiInsight?.insight,
        'Leitura depois do refresh.',
      );
    },
  );

  test(
    'filters keep canonical latest check-in when filtered list omits it',
    () async {
      final latest = _checkIn(
        id: 30,
        createdAt: DateTime(2026, 5, 5, 10),
        aiInsight: _insight(insight: 'Leitura preservada.'),
      );
      final filtered = _checkIn(
        id: 29,
        createdAt: DateTime(2026, 5, 4, 10),
        aiInsight: null,
      );
      final repository = _FakeCheckInRepository(
        lists: [
          [latest],
          [filtered],
        ],
      );
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(checkInControllerProvider.future);

      await container
          .read(checkInControllerProvider.notifier)
          .applyFilters(mood: 'ansioso');

      final state = container.read(checkInControllerProvider).asData?.value;
      expect(state?.result.items.single.id, 29);
      expect(state?.latestCreatedCheckIn?.id, 30);
      expect(
        state?.latestCreatedCheckIn?.aiInsight?.insight,
        'Leitura preservada.',
      );
    },
  );

  test('create failure keeps previous check-in history visible', () async {
    final latest = _checkIn(
      id: 50,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: _insight(insight: 'Leitura que nao deve sumir.'),
    );
    final requestOptions = RequestOptions(path: '/v1/check-ins');
    final repository = _FakeCheckInRepository(
      lists: [
        [latest],
      ],
      createError: DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 402,
          data: const {'message': 'Limite diario atingido.'},
        ),
      ),
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(checkInControllerProvider.future);

    await expectLater(
      container
          .read(checkInControllerProvider.notifier)
          .create(mood: 'calmo', reflection: null, energyLevel: 7),
      throwsA(isA<DioException>()),
    );

    final state = container.read(checkInControllerProvider).asData?.value;
    expect(state?.latestCreatedCheckIn?.id, 50);
    expect(
      state?.latestCreatedCheckIn?.aiInsight?.insight,
      'Leitura que nao deve sumir.',
    );
  });

  test(
    'deep reading style refreshes latest check-in and preserves metadata',
    () async {
      final original = _checkIn(
        id: 70,
        createdAt: DateTime(2026, 5, 5, 10),
        aiInsight: _insight(insight: 'Leitura original.'),
      );
      final refreshed = _checkIn(
        id: 70,
        createdAt: DateTime(2026, 5, 5, 10),
        aiInsight: _insight(insight: 'Leitura pratica.'),
      );
      final repository = _FakeCheckInRepository(
        lists: [
          [original],
          [refreshed],
        ],
        deepReadingResult: refreshed,
      );
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(checkInControllerProvider.future);

      final result = await container
          .read(checkInControllerProvider.notifier)
          .generateDeepReadingForLatest(style: 'practical');

      expect(repository.deepReadingStyles, ['practical']);
      expect(result?.aiInsight?.insight, 'Leitura pratica.');
      expect(
        container
            .read(checkInControllerProvider)
            .asData
            ?.value
            .latestCreatedCheckIn
            ?.aiInsight
            ?.insight,
        'Leitura pratica.',
      );
    },
  );

  test('deep reading failure keeps current check-in visible', () async {
    final original = _checkIn(
      id: 71,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: _insight(insight: 'Leitura original.'),
    );
    final requestOptions = RequestOptions(
      path: '/v1/check-ins/71/deep-reading',
    );
    final repository = _FakeCheckInRepository(
      lists: [
        [original],
      ],
      deepReadingError: DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 503),
      ),
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(checkInControllerProvider.future);

    await expectLater(
      container
          .read(checkInControllerProvider.notifier)
          .generateDeepReadingForLatest(style: 'deep'),
      throwsA(isA<DioException>()),
    );

    final state = container.read(checkInControllerProvider).asData?.value;
    expect(state?.latestCreatedCheckIn?.id, 71);
    expect(
      state?.latestCreatedCheckIn?.aiInsight?.insight,
      'Leitura original.',
    );
  });

  test('save reading updates latest saved flag', () async {
    final original = _checkIn(
      id: 80,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: _insight(),
    );
    final saved = _checkIn(
      id: 80,
      createdAt: DateTime(2026, 5, 5, 10),
      aiInsight: _insight(),
      savedReading: true,
    );
    final repository = _FakeCheckInRepository(
      lists: [
        [original],
        [saved],
      ],
      savedReadingResult: saved,
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(checkInControllerProvider.future);

    await container.read(checkInControllerProvider.notifier).saveReading(80);

    expect(repository.savedReadingIds, [80]);
    expect(
      container
          .read(checkInControllerProvider)
          .asData
          ?.value
          .latestCreatedCheckIn
          ?.savedReading,
      isTrue,
    );
  });
}

ProviderContainer _container(
  CheckInRepository repository, {
  CheckInInsightPollingConfig pollingConfig = const CheckInInsightPollingConfig(
    delays: [],
  ),
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(
        () => _FakeAuthController(_session(userId: 'user-123')),
      ),
      checkInRepositoryProvider.overrideWithValue(repository),
      checkInInsightPollingConfigProvider.overrideWithValue(pollingConfig),
      trailRepositoryProvider.overrideWithValue(_FakeTrailRepository()),
    ],
  );
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._session);

  AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;

  void setSession(AuthSession session) {
    _session = session;
    state = AsyncData(session);
  }
}

AuthSession _session({required String userId}) {
  return AuthSession(
    userId: userId,
    email: '$userId@evolua.test',
    roles: const ['ROLE_USER'],
    accessToken: 'fake.$userId.token',
    refreshToken: 'refresh-$userId',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
}

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository({
    required List<List<CheckIn>> lists,
    this.createResult,
    this.createError,
    this.createErrors = const [],
    this.listErrors = const [],
    this.getByIdResults = const [],
    this.getByIdErrors = const [],
    this.getByIdCompleters = const [],
    this.createGate,
    this.deepReadingResult,
    this.deepReadingError,
    this.savedReadingResult,
  }) : _lists = List<List<CheckIn>>.from(lists);

  final List<List<CheckIn>> _lists;
  final CheckIn? createResult;
  final Object? createError;
  final List<Object> createErrors;
  final List<Object> listErrors;
  final List<CheckIn> getByIdResults;
  final List<Object> getByIdErrors;
  final List<Completer<CheckIn>> getByIdCompleters;
  final Completer<void>? createGate;
  final CheckIn? deepReadingResult;
  final Object? deepReadingError;
  final CheckIn? savedReadingResult;
  final List<String> deepReadingStyles = [];
  final List<int> savedReadingIds = [];
  final List<int> ritualReadingIds = [];
  int createCalls = 0;
  int listCalls = 0;
  int getByIdCalls = 0;

  @override
  Future<PaginatedResponse<CheckIn>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? mood,
    String? energyRange,
    DateTime? from,
    DateTime? to,
  }) async {
    listCalls++;
    if (_lists.isEmpty && listErrors.isNotEmpty) {
      final error = listErrors.first;
      throw error;
    }
    final items = _lists.isEmpty ? const <CheckIn>[] : _lists.removeAt(0);
    return PaginatedResponse(
      items: items,
      page: page,
      size: size,
      totalItems: items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<CheckIn> getById(int checkInId) async {
    getByIdCalls++;
    if (getByIdCompleters.length >= getByIdCalls) {
      return getByIdCompleters[getByIdCalls - 1].future;
    }
    if (getByIdErrors.length >= getByIdCalls) {
      throw getByIdErrors[getByIdCalls - 1];
    }
    if (getByIdResults.length >= getByIdCalls) {
      return getByIdResults[getByIdCalls - 1];
    }
    return createResult ??
        _checkIn(
          id: checkInId,
          createdAt: DateTime(2026, 5, 5, 10),
          aiInsight: null,
        );
  }

  @override
  Future<CheckIn> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) async {
    createCalls++;
    await createGate?.future;
    final error = createError;
    if (error != null) {
      throw error;
    }
    if (createErrors.length >= createCalls) {
      throw createErrors[createCalls - 1];
    }
    return createResult ??
        _checkIn(id: 99, createdAt: DateTime(2026, 5, 5, 10), aiInsight: null);
  }

  @override
  Future<CheckIn> generateDeepReading(
    int checkInId, {
    String style = 'deep',
  }) async {
    deepReadingStyles.add(style);
    final error = deepReadingError;
    if (error != null) {
      throw error;
    }
    return deepReadingResult ??
        (_lists.isNotEmpty && _lists.first.isNotEmpty
            ? _lists.first.first
            : createResult ??
                  _checkIn(
                    id: checkInId,
                    createdAt: DateTime(2026, 5, 5, 10),
                    aiInsight: null,
                  ));
  }

  @override
  Future<CheckIn> saveReading(int checkInId) async {
    savedReadingIds.add(checkInId);
    return savedReadingResult ??
        _checkIn(
          id: checkInId,
          createdAt: DateTime(2026, 5, 5, 10),
          aiInsight: _insight(),
          savedReading: true,
        );
  }

  @override
  Future<void> createRitualFromReading(
    int checkInId, {
    required DateTime localDate,
    required String type,
  }) async {
    ritualReadingIds.add(checkInId);
  }
}

class _FakeTrailRepository implements TrailRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CheckIn _checkIn({
  required int id,
  required DateTime createdAt,
  required CheckInAiInsight? aiInsight,
  bool savedReading = false,
}) {
  return CheckIn(
    id: id,
    userId: 'user-123',
    mood: 'calmo',
    reflection: '',
    energyLevel: 7,
    recommendedPractice: '',
    aiInsight: aiInsight,
    createdAt: createdAt,
    savedReading: savedReading,
  );
}

CheckInAiInsight _insight({String insight = 'Leitura salva.'}) {
  return CheckInAiInsight(
    insight: insight,
    suggestedAction: 'Respire por dois minutos.',
    riskLevel: 'low',
    suggestedTrailId: null,
    suggestedTrailTitle: null,
    suggestedTrailReason: '',
    suggestedSpace: null,
    journeyPlan: null,
    generatedTrailDraft: null,
    fallbackUsed: false,
  );
}
