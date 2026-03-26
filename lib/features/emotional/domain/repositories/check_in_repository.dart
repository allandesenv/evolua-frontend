import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';

abstract class CheckInRepository {
  Future<List<CheckIn>> list();

  Future<CheckIn> create({
    required String mood,
    required String reflection,
    required int energyLevel,
    required String recommendedPractice,
  });
}
