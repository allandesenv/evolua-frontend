import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cachePrefix = 'evolua.profile.cache.v1';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileController stale-while-revalidate cache', () {
    test(
      'first load without cache fetches remote and writes v2 envelope',
      () async {
        final now = DateTime.utc(2026, 6, 26, 10);
        final repository = _FakeProfileRepository(
          getMeResponses: [_profile(displayName: 'Remoto')],
        );
        final container = _container(repository: repository, now: now);
        addTearDown(container.dispose);

        final profile = await _readProfile(container);

        expect(profile?.displayName, 'Remoto');
        expect(repository.getMeCalls, 1);
        final preferences = await SharedPreferences.getInstance();
        final raw = preferences.getString(_cacheKey('user-a'));
        expect(raw, isNotNull);
        final decoded = jsonDecode(raw!) as Map<String, dynamic>;
        expect(decoded['schemaVersion'], 2);
        expect(decoded['cachedAtUtc'], now.toIso8601String());
        expect(
          (decoded['payload'] as Map<String, dynamic>)['displayName'],
          'Remoto',
        );
      },
    );

    test('fresh cache returns without GET', () async {
      final now = DateTime.utc(2026, 6, 26, 10);
      SharedPreferences.setMockInitialValues({
        _cacheKey('user-a'): _cacheEnvelope(
          _profile(displayName: 'Cache fresco'),
          cachedAtUtc: now.subtract(const Duration(minutes: 14)),
        ),
      });
      final repository = _FakeProfileRepository(
        getMeResponses: [_profile(displayName: 'Remoto')],
      );
      final container = _container(repository: repository, now: now);
      addTearDown(container.dispose);

      final profile = await _readProfile(container);
      await _flushTimers();

      expect(profile?.displayName, 'Cache fresco');
      expect(
        container.read(profileControllerProvider).asData?.value?.displayName,
        'Cache fresco',
      );
      expect(repository.getMeCalls, 0);
    });

    test('stale cache is published before silent revalidation', () async {
      final now = DateTime.utc(2026, 6, 26, 10);
      SharedPreferences.setMockInitialValues({
        _cacheKey('user-a'): _cacheEnvelope(
          _profile(displayName: 'Cache antigo'),
          cachedAtUtc: now.subtract(const Duration(minutes: 16)),
        ),
      });
      final repository = _FakeProfileRepository(
        getMeResponses: [_profile(displayName: 'Remoto rapido')],
      );
      final container = _container(repository: repository, now: now);
      addTearDown(container.dispose);

      final cached = await _readProfile(container);
      expect(cached?.displayName, 'Cache antigo');

      await _flushTimers();

      expect(repository.getMeCalls, 1);
      expect(
        container.read(profileControllerProvider).asData?.value?.displayName,
        'Remoto rapido',
      );
    });

    test('legacy cache is stale and migrates after revalidation', () async {
      final now = DateTime.utc(2026, 6, 26, 10);
      SharedPreferences.setMockInitialValues({
        _cacheKey('user-a'): jsonEncode(
          _profileJson(_profile(displayName: 'Legado')),
        ),
      });
      final repository = _FakeProfileRepository(
        getMeResponses: [_profile(displayName: 'Migrado')],
      );
      final container = _container(repository: repository, now: now);
      addTearDown(container.dispose);

      final cached = await _readProfile(container);
      expect(cached?.displayName, 'Legado');
      await _flushTimers();

      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_cacheKey('user-a'));
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], 2);
      expect(
        (decoded['payload'] as Map<String, dynamic>)['displayName'],
        'Migrado',
      );
    });

    test(
      'invalid cache envelope is removed and does not leak another user',
      () async {
        final now = DateTime.utc(2026, 6, 26, 10);
        SharedPreferences.setMockInitialValues({
          _cacheKey('user-a'): _cacheEnvelope(
            _profile(userId: 'user-b', displayName: 'Outro usuario'),
            cachedAtUtc: now,
          ),
        });
        final repository = _FakeProfileRepository(
          getMeResponses: [_profile(displayName: 'Usuario correto')],
        );
        final container = _container(repository: repository, now: now);
        addTearDown(container.dispose);

        final profile = await _readProfile(container);

        expect(profile?.displayName, 'Usuario correto');
        expect(repository.getMeCalls, 1);
      },
    );

    test('future timestamp is treated as stale', () async {
      final now = DateTime.utc(2026, 6, 26, 10);
      SharedPreferences.setMockInitialValues({
        _cacheKey('user-a'): _cacheEnvelope(
          _profile(displayName: 'Cache futuro'),
          cachedAtUtc: now.add(const Duration(minutes: 1)),
        ),
      });
      final repository = _FakeProfileRepository(
        getMeResponses: [_profile(displayName: 'Remoto')],
      );
      final container = _container(repository: repository, now: now);
      addTearDown(container.dispose);

      final profile = await _readProfile(container);
      expect(profile?.displayName, 'Cache futuro');
      await _flushTimers();

      expect(repository.getMeCalls, 1);
      expect(
        container.read(profileControllerProvider).asData?.value?.displayName,
        'Remoto',
      );
    });

    test('refreshes with the same context share the same GET', () async {
      final now = DateTime.utc(2026, 6, 26, 10);
      SharedPreferences.setMockInitialValues({
        _cacheKey('user-a'): _cacheEnvelope(
          _profile(displayName: 'Cache'),
          cachedAtUtc: now,
        ),
      });
      final completer = Completer<Profile?>();
      final repository = _FakeProfileRepository(
        getMeResponses: [completer.future],
      );
      final container = _container(repository: repository, now: now);
      addTearDown(container.dispose);
      await _readProfile(container);

      final first = container
          .read(profileControllerProvider.notifier)
          .refresh();
      final second = container
          .read(profileControllerProvider.notifier)
          .refresh();
      expect(repository.getMeCalls, 1);

      completer.complete(_profile(displayName: 'Remoto'));
      await Future.wait([first, second]);

      expect(repository.getMeCalls, 1);
      expect(
        container.read(profileControllerProvider).asData?.value?.displayName,
        'Remoto',
      );
    });

    test(
      'refresh after mutation generation changes does not reuse old GET',
      () async {
        final now = DateTime.utc(2026, 6, 26, 10);
        SharedPreferences.setMockInitialValues({
          _cacheKey('user-a'): _cacheEnvelope(
            _profile(displayName: 'Cache'),
            cachedAtUtc: now,
          ),
        });
        final oldGet = Completer<Profile?>();
        final newGet = Completer<Profile?>();
        final repository = _FakeProfileRepository(
          getMeResponses: [oldGet.future, newGet.future],
          upsertResult: _profile(displayName: 'Mutacao'),
        );
        final container = _container(repository: repository, now: now);
        addTearDown(container.dispose);
        await _readProfile(container);

        final firstRefresh = container
            .read(profileControllerProvider.notifier)
            .refresh();
        expect(repository.getMeCalls, 1);
        await container
            .read(profileControllerProvider.notifier)
            .upsertMe(
              displayName: 'Mutacao',
              birthDate: DateTime(2000, 1, 1),
              gender: 'CUSTOM',
              bio: 'bio',
              journeyLevel: 2,
            );
        final secondRefresh = container
            .read(profileControllerProvider.notifier)
            .refresh();

        expect(repository.getMeCalls, 2);
        oldGet.complete(_profile(displayName: 'GET antigo'));
        newGet.complete(_profile(displayName: 'GET novo'));
        await Future.wait([firstRefresh, secondRefresh]);

        expect(
          container.read(profileControllerProvider).asData?.value?.displayName,
          'GET novo',
        );
      },
    );

    test('pending GET cannot publish during or after upsert', () async {
      final now = DateTime.utc(2026, 6, 26, 10);
      SharedPreferences.setMockInitialValues({
        _cacheKey('user-a'): _cacheEnvelope(
          _profile(displayName: 'Cache antigo'),
          cachedAtUtc: now.subtract(const Duration(minutes: 20)),
        ),
      });
      final getCompleter = Completer<Profile?>();
      final repository = _FakeProfileRepository(
        getMeResponses: [getCompleter.future],
        upsertResult: _profile(displayName: 'Perfil salvo'),
      );
      final container = _container(repository: repository, now: now);
      addTearDown(container.dispose);

      await _readProfile(container);
      await _flushTimers();
      expect(repository.getMeCalls, 1);

      await container
          .read(profileControllerProvider.notifier)
          .upsertMe(
            displayName: 'Perfil salvo',
            birthDate: DateTime(2000, 1, 1),
            gender: 'CUSTOM',
            bio: 'bio',
            journeyLevel: 2,
          );
      expect(
        container.read(profileControllerProvider).asData?.value?.displayName,
        'Perfil salvo',
      );

      getCompleter.complete(_profile(displayName: 'GET antigo'));
      await _flushTimers();

      expect(
        container.read(profileControllerProvider).asData?.value?.displayName,
        'Perfil salvo',
      );
    });

    test('pending GET cannot remove avatar uploaded locally', () async {
      final now = DateTime.utc(2026, 6, 26, 10);
      final cached = _profile(displayName: 'Cache', avatarUrl: 'old.png');
      SharedPreferences.setMockInitialValues({
        _cacheKey('user-a'): _cacheEnvelope(
          cached,
          cachedAtUtc: now.subtract(const Duration(minutes: 20)),
        ),
      });
      final getCompleter = Completer<Profile?>();
      final repository = _FakeProfileRepository(
        getMeResponses: [getCompleter.future],
        uploadAvatarUrl: 'new.png',
      );
      final container = _container(repository: repository, now: now);
      addTearDown(container.dispose);

      await _readProfile(container);
      await _flushTimers();
      await container
          .read(profileControllerProvider.notifier)
          .uploadAvatar(
            bytes: Uint8List.fromList([1, 2, 3]),
            fileName: 'avatar.png',
          );

      final afterUpload = container
          .read(profileControllerProvider)
          .asData
          ?.value;
      expect(afterUpload?.avatarUrl, 'new.png');
      expect(afterUpload?.displayName, 'Cache');
      expect(afterUpload?.bio, cached.bio);

      getCompleter.complete(
        _profile(displayName: 'GET antigo', avatarUrl: 'old.png'),
      );
      await _flushTimers();

      expect(
        container.read(profileControllerProvider).asData?.value?.avatarUrl,
        'new.png',
      );
      expect(
        container.read(profileControllerProvider).asData?.value?.displayName,
        'Cache',
      );
    });

    test(
      'valid revalidation returning null removes cache and publishes null',
      () async {
        final now = DateTime.utc(2026, 6, 26, 10);
        SharedPreferences.setMockInitialValues({
          _cacheKey('user-a'): _cacheEnvelope(
            _profile(displayName: 'Cache antigo'),
            cachedAtUtc: now.subtract(const Duration(minutes: 20)),
          ),
        });
        final repository = _FakeProfileRepository(getMeResponses: [null]);
        final container = _container(repository: repository, now: now);
        addTearDown(container.dispose);

        await _readProfile(container);
        await _flushTimers();

        final preferences = await SharedPreferences.getInstance();
        expect(container.read(profileControllerProvider).asData?.value, isNull);
        expect(preferences.getString(_cacheKey('user-a')), isNull);
      },
    );

    test('mutation failures preserve previous state and cache', () async {
      final now = DateTime.utc(2026, 6, 26, 10);
      final cached = _profile(displayName: 'Cache', avatarUrl: 'old.png');
      SharedPreferences.setMockInitialValues({
        _cacheKey('user-a'): _cacheEnvelope(cached, cachedAtUtc: now),
      });
      final repository = _FakeProfileRepository(
        upsertError: StateError('upsert failed'),
        uploadError: StateError('upload failed'),
      );
      final container = _container(repository: repository, now: now);
      addTearDown(container.dispose);
      await _readProfile(container);

      await expectLater(
        container
            .read(profileControllerProvider.notifier)
            .upsertMe(
              displayName: 'Novo',
              birthDate: DateTime(2000, 1, 1),
              gender: 'CUSTOM',
              bio: 'bio',
              journeyLevel: 2,
            ),
        throwsStateError,
      );
      await expectLater(
        container
            .read(profileControllerProvider.notifier)
            .uploadAvatar(
              bytes: Uint8List.fromList([1]),
              fileName: 'avatar.png',
            ),
        throwsStateError,
      );

      expect(
        container.read(profileControllerProvider).asData?.value?.displayName,
        'Cache',
      );
      expect(
        container.read(profileControllerProvider).asData?.value?.avatarUrl,
        'old.png',
      );
      final preferences = await SharedPreferences.getInstance();
      final decoded =
          jsonDecode(preferences.getString(_cacheKey('user-a'))!)
              as Map<String, dynamic>;
      expect(
        (decoded['payload'] as Map<String, dynamic>)['displayName'],
        'Cache',
      );
      expect(
        (decoded['payload'] as Map<String, dynamic>)['avatarUrl'],
        'old.png',
      );
    });

    test(
      'late response from previous generation does not publish or write cache',
      () async {
        final now = DateTime.utc(2026, 6, 26, 10);
        final authController = _MutableFakeAuthController(userId: 'user-a');
        final oldGet = Completer<Profile?>();
        final repository = _FakeProfileRepository(
          getMeResponses: [oldGet.future],
        );
        final container = _container(
          repository: repository,
          now: now,
          authController: authController,
        );
        addTearDown(container.dispose);

        await container.read(authControllerProvider.future);
        final firstLoad = container.read(profileControllerProvider.future);
        await Future<void>.delayed(Duration.zero);
        expect(repository.getMeCalls, 1);

        authController.switchUser('user-b');
        container.read(authSessionGenerationProvider.notifier).bump();
        oldGet.complete(_profile(userId: 'user-a', displayName: 'Antigo'));
        await expectLater(firstLoad, completion(isNull));
        await _flushTimers();

        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString(_cacheKey('user-a')), isNull);
        expect(container.read(profileControllerProvider).asData?.value, isNull);
      },
    );
  });
}

ProviderContainer _container({
  required _FakeProfileRepository repository,
  required DateTime now,
  _MutableFakeAuthController? authController,
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(
        () => authController ?? _MutableFakeAuthController(userId: 'user-a'),
      ),
      profileRepositoryProvider.overrideWithValue(repository),
      profileCacheClockProvider.overrideWithValue(() => now),
    ],
  );
}

Future<Profile?> _readProfile(ProviderContainer container) async {
  await container.read(authControllerProvider.future);
  return container.read(profileControllerProvider.future);
}

class _MutableFakeAuthController extends AuthController {
  _MutableFakeAuthController({required String userId}) : _userId = userId;

  String? _userId;

  @override
  Future<AuthSession?> build() async => _session();

  void switchUser(String? userId) {
    _userId = userId;
    state = AsyncData(_session());
  }

  AuthSession? _session() {
    final userId = _userId;
    if (userId == null) {
      return null;
    }
    return AuthSession(
      userId: userId,
      email: '$userId@evolua.test',
      roles: const ['ROLE_USER'],
      accessToken: 'test-token',
      expiresAt: DateTime.utc(2026, 6, 26, 12),
    );
  }
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({
    List<FutureOr<Profile?>>? getMeResponses,
    this.upsertResult,
    this.upsertError,
    this.uploadAvatarUrl = 'avatar.png',
    this.uploadError,
  }) : _getMeResponses = getMeResponses ?? [];

  final List<FutureOr<Profile?>> _getMeResponses;
  final Profile? upsertResult;
  final Object? upsertError;
  final String uploadAvatarUrl;
  final Object? uploadError;
  var getMeCalls = 0;
  var upsertCalls = 0;
  var uploadAvatarCalls = 0;

  @override
  Future<Profile?> getMe() async {
    getMeCalls++;
    if (_getMeResponses.isEmpty) {
      return null;
    }
    final response = _getMeResponses.removeAt(0);
    if (response is Future<Profile?>) {
      return response;
    }
    return response;
  }

  @override
  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  }) async {
    upsertCalls++;
    final error = upsertError;
    if (error != null) {
      throw error;
    }
    return upsertResult ??
        _profile(
          displayName: displayName,
          bio: bio,
          journeyLevel: journeyLevel,
        );
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    uploadAvatarCalls++;
    final error = uploadError;
    if (error != null) {
      throw error;
    }
    return uploadAvatarUrl;
  }
}

Profile _profile({
  String userId = 'user-a',
  String displayName = 'Perfil',
  String bio = 'bio original',
  int journeyLevel = 1,
  String? avatarUrl,
}) {
  return Profile(
    id: userId == 'user-a' ? 1 : 2,
    userId: userId,
    displayName: displayName,
    bio: bio,
    journeyLevel: journeyLevel,
    premium: false,
    birthDate: DateTime(2000, 1, 1),
    gender: 'CUSTOM',
    customGender: null,
    avatarUrl: avatarUrl,
    createdAt: DateTime.utc(2026, 1, 1),
    personalGoals: 'objetivo',
  );
}

String _cacheKey(String userId) => '$_cachePrefix.$userId';

String _cacheEnvelope(Profile profile, {required DateTime cachedAtUtc}) {
  return jsonEncode({
    'schemaVersion': 2,
    'cachedAtUtc': cachedAtUtc.toUtc().toIso8601String(),
    'payload': _profileJson(profile),
  });
}

Map<String, dynamic> _profileJson(Profile profile) {
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

Future<void> _flushTimers() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
