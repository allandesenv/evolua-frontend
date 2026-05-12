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
    final container = _container(_FakeCheckInRepository(lists: [[latest, previous]]));
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

    await container.read(checkInControllerProvider.notifier).create(
          mood: 'calmo',
          reflection: null,
          energyLevel: 7,
        );

    final state = container.read(checkInControllerProvider).asData?.value;
    expect(state?.latestCreatedCheckIn?.id, 99);
    expect(
      state?.latestCreatedCheckIn?.aiInsight?.insight,
      'Leitura enriquecida.',
    );
  });

  test('refresh replaces partial latest check-in with listed full version', () async {
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
    await container.read(checkInControllerProvider.notifier).create(
          mood: 'calmo',
          reflection: null,
          energyLevel: 7,
        );

    await container.read(checkInControllerProvider.notifier).refresh();

    final state = container.read(checkInControllerProvider).asData?.value;
    expect(
      state?.latestCreatedCheckIn?.aiInsight?.insight,
      'Leitura depois do refresh.',
    );
  });

  test('filters keep canonical latest check-in when filtered list omits it', () async {
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
  });
}

ProviderContainer _container(CheckInRepository repository) {
  return ProviderContainer(
    overrides: [
      checkInRepositoryProvider.overrideWithValue(repository),
      trailRepositoryProvider.overrideWithValue(_FakeTrailRepository()),
    ],
  );
}

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository({
    required List<List<CheckIn>> lists,
    this.createResult,
  }) : _lists = List<List<CheckIn>>.from(lists);

  final List<List<CheckIn>> _lists;
  final CheckIn? createResult;

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
    return createResult ??
        _checkIn(
          id: 99,
          createdAt: DateTime(2026, 5, 5, 10),
          aiInsight: null,
        );
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
