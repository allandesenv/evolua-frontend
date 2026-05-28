import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
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
        lists: [
          const <CheckIn>[],
          const <CheckIn>[],
          const <CheckIn>[],
          [listedWithInsight],
        ],
      );
      final container = _container(
        repository,
        pollingConfig: const CheckInInsightPollingConfig(
          attempts: 3,
          delay: Duration(milliseconds: 1),
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
      expect(
        state?.latestCreatedCheckIn?.aiInsight?.insight,
        'Leitura chegou depois.',
      );
      expect(state?.isLatestInsightPending, isFalse);
    },
  );

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
    attempts: 0,
    delay: Duration.zero,
  ),
}) {
  return ProviderContainer(
    overrides: [
      checkInRepositoryProvider.overrideWithValue(repository),
      checkInInsightPollingConfigProvider.overrideWithValue(pollingConfig),
      trailRepositoryProvider.overrideWithValue(_FakeTrailRepository()),
    ],
  );
}

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository({
    required List<List<CheckIn>> lists,
    this.createResult,
    this.createError,
    this.deepReadingResult,
    this.savedReadingResult,
  }) : _lists = List<List<CheckIn>>.from(lists);

  final List<List<CheckIn>> _lists;
  final CheckIn? createResult;
  final Object? createError;
  final CheckIn? deepReadingResult;
  final CheckIn? savedReadingResult;
  final List<String> deepReadingStyles = [];
  final List<int> savedReadingIds = [];
  final List<int> ritualReadingIds = [];

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
  Future<CheckIn> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) async {
    final error = createError;
    if (error != null) {
      throw error;
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
