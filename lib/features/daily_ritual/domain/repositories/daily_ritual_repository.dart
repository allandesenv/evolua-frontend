import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';

abstract class DailyRitualRepository {
  Future<DailyRitual?> today({
    required String type,
    required DateTime localDate,
  });

  Future<DailyRitual> create(DailyRitualDraft draft);
}
