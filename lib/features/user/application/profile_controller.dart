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
const _profileCacheSchemaVersion = 2;
const _profileCacheTtl = Duration(minutes: 15);

final profileCacheClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

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
  _ProfileRefreshInFlight? _refreshInFlight;
  var _mutationGeneration = 0;

  @override
  Future<Profile?> build() async {
    final repository = ref.watch(profileRepositoryProvider);
    var context = _currentContext();
    if (context == null) {
      try {
        await ref.read(authControllerProvider.future);
      } catch (_) {
        return null;
      }
      context = _currentContext();
      if (context == null) {
        return null;
      }
    }

    final cached = await _readCachedProfile(context.userId);
    if (cached != null) {
      if (!cached.isFresh) {
        _scheduleSilentRefresh(repository, context);
      }
      return cached.profile;
    }

    final profile = await _refreshRemote(repository, context);
    if (!_canApplyContext(context)) {
      return null;
    }
    return profile;
  }

  Future<void> refresh() async {
    final context = _currentContext();
    if (context == null) {
      state = const AsyncData(null);
      return;
    }
    final current = state.asData?.value;
    if (current == null) {
      state = const AsyncLoading();
    }
    try {
      await _refreshRemote(ref.read(profileRepositoryProvider), context);
    } catch (error, stackTrace) {
      final latest = state.asData?.value;
      if (latest != null) {
        state = AsyncData(latest);
        return;
      }
      state = AsyncError(error, stackTrace);
    }
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
    _mutationGeneration++;
    final context = _currentContext();
    final previous = state.asData?.value;

    try {
      final profile = await repository.upsertMe(
        displayName: displayName,
        birthDate: birthDate,
        gender: gender,
        customGender: customGender,
        bio: bio,
        journeyLevel: journeyLevel,
      );
      if (context == null || _canApplyContext(context)) {
        await _writeCachedProfile(profile);
        if (context == null || _canApplyContext(context)) {
          state = AsyncData(profile);
        }
      }
      return profile;
    } catch (_) {
      if (previous != null) {
        state = AsyncData(previous);
      }
      rethrow;
    }
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final repository = ref.read(profileRepositoryProvider);
    _mutationGeneration++;
    final context = _currentContext();
    final previous = state.asData?.value;

    try {
      final avatarUrl = await repository.uploadAvatar(
        bytes: bytes,
        fileName: fileName,
      );
      if (previous != null &&
          (context == null ||
              (_canApplyContext(context) &&
                  previous.userId == context.userId))) {
        final updated = previous.copyWith(avatarUrl: avatarUrl);
        await _writeCachedProfile(updated);
        if (context == null || _canApplyContext(context)) {
          state = AsyncData(updated);
        }
      } else {
        await refresh();
      }
      return avatarUrl;
    } catch (_) {
      if (previous != null) {
        state = AsyncData(previous);
      }
      rethrow;
    }
  }

  void _scheduleSilentRefresh(
    ProfileRepository repository,
    _ProfileRefreshContext context,
  ) {
    Timer.run(() {
      if (!ref.mounted || !_canApplyContext(context)) {
        return;
      }
      unawaited(
        _refreshRemote(repository, context).catchError((Object _) => null),
      );
    });
  }

  Future<Profile?> _refreshRemote(
    ProfileRepository repository,
    _ProfileRefreshContext context,
  ) {
    final current = _refreshInFlight;
    if (current != null && current.matches(context)) {
      return current.future;
    }

    late final Future<Profile?> future;
    future = _fetchAndApplyRemote(repository, context).whenComplete(() {
      if (identical(_refreshInFlight?.future, future)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = _ProfileRefreshInFlight(
      context: context,
      future: future,
    );
    return future;
  }

  Future<Profile?> _fetchAndApplyRemote(
    ProfileRepository repository,
    _ProfileRefreshContext context,
  ) async {
    final profile = await repository.getMe();
    if (!_canApplyContext(context)) {
      return profile;
    }

    if (profile == null) {
      await _removeCachedProfile(context.userId);
      if (_canApplyContext(context)) {
        state = const AsyncData(null);
      }
      return null;
    }

    await _writeCachedProfile(profile);
    if (_canApplyContext(context)) {
      state = AsyncData(profile);
    }
    return profile;
  }

  Future<_CachedProfile?> _readCachedProfile(String userId) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final raw = preferences.getString(_cacheKey(userId));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await preferences.remove(_cacheKey(userId));
        return null;
      }

      final cacheEntry = _cacheEntryFromJson(decoded, userId);
      if (cacheEntry == null) {
        await preferences.remove(_cacheKey(userId));
      }
      return cacheEntry;
    } catch (_) {
      await preferences.remove(_cacheKey(userId));
      return null;
    }
  }

  Future<void> _writeCachedProfile(Profile profile) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setString(
      _cacheKey(profile.userId),
      jsonEncode({
        'schemaVersion': _profileCacheSchemaVersion,
        'cachedAtUtc': ref
            .read(profileCacheClockProvider)()
            .toUtc()
            .toIso8601String(),
        'payload': _profileToJson(profile),
      }),
    );
  }

  Future<void> _removeCachedProfile(String userId) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.remove(_cacheKey(userId));
  }

  _CachedProfile? _cacheEntryFromJson(
    Map<String, dynamic> json,
    String expectedUserId,
  ) {
    if (!json.containsKey('schemaVersion')) {
      final legacy = _tryProfileFromJson(json);
      if (legacy == null || legacy.userId != expectedUserId) {
        return null;
      }
      return _CachedProfile(profile: legacy, isFresh: false);
    }

    if (json['schemaVersion'] != _profileCacheSchemaVersion) {
      return null;
    }

    final payload = json['payload'];
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    final profile = _tryProfileFromJson(payload);
    if (profile == null || profile.userId != expectedUserId) {
      return null;
    }

    final cachedAt = DateTime.tryParse(json['cachedAtUtc']?.toString() ?? '');
    return _CachedProfile(
      profile: profile,
      isFresh: _isFreshCachedAt(cachedAt),
    );
  }

  bool _isFreshCachedAt(DateTime? cachedAt) {
    if (cachedAt == null) {
      return false;
    }
    final cachedAtUtc = cachedAt.toUtc();
    final nowUtc = ref.read(profileCacheClockProvider)().toUtc();
    if (cachedAtUtc.isAfter(nowUtc)) {
      return false;
    }
    return nowUtc.difference(cachedAtUtc) <= _profileCacheTtl;
  }

  _ProfileRefreshContext? _currentContext() {
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) {
      return null;
    }
    return _ProfileRefreshContext(
      userId: session.userId,
      sessionGeneration: ref.read(authSessionGenerationProvider),
      mutationGeneration: _mutationGeneration,
    );
  }

  bool _canApplyContext(_ProfileRefreshContext context) {
    if (!ref.mounted) {
      return false;
    }
    final session = ref.read(authControllerProvider).asData?.value;
    return session?.userId == context.userId &&
        ref.read(authSessionGenerationProvider) == context.sessionGeneration &&
        _mutationGeneration == context.mutationGeneration;
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

  Profile? _tryProfileFromJson(Map<String, dynamic> json) {
    try {
      return _profileFromJson(json);
    } catch (_) {
      return null;
    }
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

class _CachedProfile {
  const _CachedProfile({required this.profile, required this.isFresh});

  final Profile profile;
  final bool isFresh;
}

class _ProfileRefreshContext {
  const _ProfileRefreshContext({
    required this.userId,
    required this.sessionGeneration,
    required this.mutationGeneration,
  });

  final String userId;
  final int sessionGeneration;
  final int mutationGeneration;
}

class _ProfileRefreshInFlight {
  const _ProfileRefreshInFlight({required this.context, required this.future});

  final _ProfileRefreshContext context;
  final Future<Profile?> future;

  bool matches(_ProfileRefreshContext other) {
    return context.userId == other.userId &&
        context.sessionGeneration == other.sessionGeneration &&
        context.mutationGeneration == other.mutationGeneration;
  }
}
