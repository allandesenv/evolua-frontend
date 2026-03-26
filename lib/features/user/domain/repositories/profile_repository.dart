import 'package:evolua_frontend/features/user/domain/entities/profile.dart';

abstract class ProfileRepository {
  Future<List<Profile>> list();

  Future<Profile> create({
    required String displayName,
    required String bio,
    required int journeyLevel,
    required bool premium,
  });
}
