import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/repositories/daily_ritual_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyRitualController', () {
    test(
      'loads daily rituals with one list request and no today requests',
      () async {
        final today = _today();
        final repository = _FakeDailyRitualRepository(
          items: [
            _ritual(
              id: 2,
              type: DailyRitualType.evening,
              localDate: DateTime(today.year, today.month, today.day, 22),
            ),
            _ritual(
              id: 1,
              type: DailyRitualType.morning,
              localDate: DateTime(today.year, today.month, today.day, 8),
            ),
          ],
        );
        final container = _container(repository);
        addTearDown(container.dispose);

        final state = await container.read(
          dailyRitualControllerProvider.future,
        );

        expect(repository.listCalls, 1);
        expect(repository.todayCalls, 0);
        expect(state.morning?.id, 1);
        expect(state.evening?.id, 2);
      },
    );

    test('keeps missing morning and evening as null', () async {
      final repository = _FakeDailyRitualRepository(items: const []);
      final container = _container(repository);
      addTearDown(container.dispose);

      final state = await container.read(dailyRitualControllerProvider.future);

      expect(state.morning, isNull);
      expect(state.evening, isNull);
    });

    test('ignores other days and unknown types', () async {
      final today = _today();
      final repository = _FakeDailyRitualRepository(
        items: [
          _ritual(
            id: 1,
            type: DailyRitualType.morning,
            localDate: today.subtract(const Duration(days: 1)),
          ),
          _ritual(id: 3, type: 'NOON', localDate: today),
          _ritual(
            id: 2,
            type: DailyRitualType.evening,
            localDate: DateTime(today.year, today.month, today.day, 23, 59),
          ),
        ],
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      final state = await container.read(dailyRitualControllerProvider.future);

      expect(state.morning, isNull);
      expect(state.evening?.id, 2);
    });

    test('refresh normalizes requested date and lists once', () async {
      final repository = _FakeDailyRitualRepository(items: const []);
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(dailyRitualControllerProvider.future);
      repository.resetCalls();

      await container
          .read(dailyRitualControllerProvider.notifier)
          .refresh(localDate: DateTime(2026, 5, 9, 21, 45));

      expect(repository.listCalls, 1);
      expect(repository.todayCalls, 0);
      expect(repository.listStarts.single, DateTime(2026, 5, 9));
      expect(repository.listEnds.single, DateTime(2026, 5, 9));
    });

    test('create reloads the draft date with one list request', () async {
      final repository = _FakeDailyRitualRepository(items: const []);
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(dailyRitualControllerProvider.future);
      repository.resetCalls();

      final created = await container
          .read(dailyRitualControllerProvider.notifier)
          .create(
            DailyRitualDraft(
              localDate: DateTime(2026, 5, 10, 14),
              type: DailyRitualType.morning,
              emotionalState: 'calmo',
              dayNeed: 'clareza',
              intention: 'agir com calma',
              microAction: 'pausar',
            ),
          );

      final state = container.read(dailyRitualControllerProvider).value!;
      expect(repository.createCalls, 1);
      expect(repository.listCalls, 1);
      expect(repository.todayCalls, 0);
      expect(repository.listStarts.single, DateTime(2026, 5, 10));
      expect(created.id, state.morning?.id);
      expect(state.morning?.localDate.day, 10);
    });

    test('create failure does not reload', () async {
      final repository = _FakeDailyRitualRepository(
        items: const [],
        createError: StateError('create failed'),
      );
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(dailyRitualControllerProvider.future);
      repository.resetCalls();

      await expectLater(
        container
            .read(dailyRitualControllerProvider.notifier)
            .create(
              DailyRitualDraft(
                localDate: DateTime(2026, 5, 10),
                type: DailyRitualType.morning,
                emotionalState: 'calmo',
                dayNeed: 'clareza',
                intention: 'agir',
                microAction: 'pausar',
              ),
            ),
        throwsStateError,
      );

      expect(repository.createCalls, 1);
      expect(repository.listCalls, 0);
      expect(repository.todayCalls, 0);
    });

    test(
      'refresh failure after create is stored in controller state',
      () async {
        final repository = _FakeDailyRitualRepository(
          items: const [],
          listErrorAfterCreate: StateError('refresh failed'),
        );
        final container = _container(repository);
        addTearDown(container.dispose);
        await container.read(dailyRitualControllerProvider.future);
        repository.resetCalls();

        final created = await container
            .read(dailyRitualControllerProvider.notifier)
            .create(
              DailyRitualDraft(
                localDate: DateTime(2026, 5, 10),
                type: DailyRitualType.evening,
                emotionalState: 'calmo',
                dayNeed: 'descanso',
                intention: 'fechar o dia',
                microAction: 'respirar',
              ),
            );

        expect(created.type, DailyRitualType.evening);
        expect(repository.createCalls, 1);
        expect(repository.listCalls, 1);
        expect(container.read(dailyRitualControllerProvider).hasError, isTrue);
      },
    );
  });
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

ProviderContainer _container(_FakeDailyRitualRepository repository) {
  return ProviderContainer(
    overrides: [dailyRitualRepositoryProvider.overrideWithValue(repository)],
  );
}

class _FakeDailyRitualRepository implements DailyRitualRepository {
  _FakeDailyRitualRepository({
    required List<DailyRitual> items,
    this.createError,
    this.listErrorAfterCreate,
  }) : _items = List<DailyRitual>.of(items);

  final Object? createError;
  final Object? listErrorAfterCreate;
  final listStarts = <DateTime>[];
  final listEnds = <DateTime>[];
  final createdDrafts = <DailyRitualDraft>[];
  List<DailyRitual> _items;
  int listCalls = 0;
  int todayCalls = 0;
  int createCalls = 0;

  void resetCalls() {
    listCalls = 0;
    todayCalls = 0;
    createCalls = 0;
    listStarts.clear();
    listEnds.clear();
  }

  @override
  Future<DailyRitual?> today({
    required String type,
    required DateTime localDate,
  }) async {
    todayCalls++;
    return null;
  }

  @override
  Future<List<DailyRitual>> list({
    required DateTime start,
    required DateTime end,
  }) async {
    listCalls++;
    listStarts.add(start);
    listEnds.add(end);
    final error = listErrorAfterCreate;
    if (error != null && createCalls > 0) {
      throw error;
    }
    return _items;
  }

  @override
  Future<DailyRitual> create(DailyRitualDraft draft) async {
    createCalls++;
    createdDrafts.add(draft);
    final error = createError;
    if (error != null) {
      throw error;
    }
    final created = _ritual(
      id: 100 + createCalls,
      type: draft.type,
      localDate: draft.localDate,
      emotionalState: draft.emotionalState,
      dayNeed: draft.dayNeed,
      intention: draft.intention,
      microAction: draft.microAction,
    );
    _items = [created];
    return created;
  }
}

DailyRitual _ritual({
  required int id,
  required String type,
  required DateTime localDate,
  String emotionalState = 'calmo',
  String dayNeed = 'clareza',
  String intention = 'agir com calma',
  String microAction = 'pausar',
}) {
  return DailyRitual(
    id: id,
    localDate: localDate,
    type: type,
    emotionalState: emotionalState,
    dayNeed: dayNeed,
    intention: intention,
    microAction: microAction,
    createdAt: DateTime(2026, 5, 7, 8),
  );
}
