import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/user/data/repositories/profile_repository_impl.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _cachedProfilePrefix = 'evolua.profile.cache.v1';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.userBaseUrl));
  return ProfileRepositoryImpl(dio);
});

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, Profile?>(ProfileController.new);

final currentProfileProvider = Provider<Profile?>((ref) {
  return ref.watch(profileControllerProvider).asData?.value;
});

class ProfileController extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final repository = ref.watch(profileRepositoryProvider);
    final cached = await _readCachedProfile();
    if (cached != null) {
      unawaited(_refreshRemote(repository));
      return cached;
    }
    final profile = await repository.getMe();
    if (profile != null) {
      await _writeCachedProfile(profile);
    }
    return profile;
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    if (current == null) {
      state = const AsyncLoading();
    }
    await _refreshRemote(ref.read(profileRepositoryProvider));
  }

  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  }) async {
    final repository = ref.read(profileRepositoryProvider);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await repository.upsertMe(
        displayName: displayName,
        birthDate: birthDate,
        gender: gender,
        customGender: customGender,
        bio: bio,
        journeyLevel: journeyLevel,
      );
      await _writeCachedProfile(profile);
      return profile;
    });

    return state.requireValue!;
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final repository = ref.read(profileRepositoryProvider);
    final avatarUrl = await repository.uploadAvatar(
      bytes: bytes,
      fileName: fileName,
    );
    await refresh();
    return avatarUrl;
  }

  Future<void> _refreshRemote(ProfileRepository repository) async {
    try {
      final profile = await repository.getMe();
      if (profile != null) {
        await _writeCachedProfile(profile);
      }
      state = AsyncData(profile);
    } catch (error, stackTrace) {
      final current = state.asData?.value;
      if (current != null) {
        state = AsyncData(current);
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  Future<Profile?> _readCachedProfile() async {
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) {
      return null;
    }
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final raw = preferences.getString(_cacheKey(session.userId));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return _profileFromJson(decoded);
    } catch (_) {
      await preferences.remove(_cacheKey(session.userId));
      return null;
    }
  }

  Future<void> _writeCachedProfile(Profile profile) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setString(
      _cacheKey(profile.userId),
      jsonEncode(_profileToJson(profile)),
    );
  }

  String _cacheKey(String userId) => '$_cachedProfilePrefix.$userId';

  Map<String, dynamic> _profileToJson(Profile profile) {
    return {
      'id': profile.id,
      'userId': profile.userId,
      'displayName': profile.displayName,
      'bio': profile.bio,
      'journeyLevel': profile.journeyLevel,
      'premium': profile.premium,
      'birthDate': profile.birthDate?.toIso8601String(),
      'gender': profile.gender,
      'customGender': profile.customGender,
      'avatarUrl': profile.avatarUrl,
      'createdAt': profile.createdAt.toIso8601String(),
      'personalGoals': profile.personalGoals,
    };
  }

  Profile _profileFromJson(Map<String, dynamic> json) {
    return Profile(
      id: (json['id'] as num).toInt(),
      userId: json['userId'].toString(),
      displayName: json['displayName'].toString(),
      bio: (json['bio'] ?? '').toString(),
      journeyLevel: (json['journeyLevel'] as num?)?.toInt() ?? 1,
      premium: json['premium'] == true,
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.tryParse(json['birthDate'].toString()),
      gender: json['gender']?.toString(),
      customGender: json['customGender']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      personalGoals: json['personalGoals']?.toString(),
    );
  }
}
