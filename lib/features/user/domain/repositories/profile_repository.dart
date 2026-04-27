import 'dart:typed_data';

import 'package:evolua_frontend/features/user/domain/entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile?> getMe();

  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  });

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  });
}
