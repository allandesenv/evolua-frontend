import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/daily_ritual/data/repositories/daily_ritual_repository_impl.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/repositories/daily_ritual_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dailyRitualRepositoryProvider = Provider<DailyRitualRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.emotionalBaseUrl));
  return DailyRitualRepositoryImpl(dio);
});

final dailyRitualControllerProvider =
    AsyncNotifierProvider<DailyRitualController, DailyRitualState>(
      DailyRitualController.new,
    );

class DailyRitualState {
  const DailyRitualState({this.morning, this.evening});

  final DailyRitual? morning;
  final DailyRitual? evening;

  DailyRitual? byType(String type) {
    return type == DailyRitualType.evening ? evening : morning;
  }
}

class DailyRitualController extends AsyncNotifier<DailyRitualState> {
  @override
  Future<DailyRitualState> build() async {
    return _load(DateTime.now());
  }

  Future<DailyRitualState> _load(DateTime localDate) async {
    final repository = ref.read(dailyRitualRepositoryProvider);
    final day = DateTime(localDate.year, localDate.month, localDate.day);
    final items = await repository.list(start: day, end: day);
    DailyRitual? morning;
    DailyRitual? evening;
    for (final item in items) {
      if (!_isSameLocalDay(item.localDate, day)) {
        continue;
      }
      if (item.type == DailyRitualType.morning) {
        morning = item;
      } else if (item.type == DailyRitualType.evening) {
        evening = item;
      }
    }
    return DailyRitualState(morning: morning, evening: evening);
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> refresh({DateTime? localDate}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(localDate ?? DateTime.now()));
  }

  Future<DailyRitual> create(DailyRitualDraft draft) async {
    final created = await ref.read(dailyRitualRepositoryProvider).create(draft);
    await refresh(localDate: draft.localDate);
    return created;
  }
}
