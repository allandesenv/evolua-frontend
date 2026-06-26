import 'dart:async';

import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/features/social/domain/repositories/community_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CommunityController performance state', () {
    test('loads first page and ignores unchanged default filters', () async {
      final repository = _FakeCommunityRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      final state = await container.read(communityControllerProvider.future);
      expect(state.result.items.map((item) => item.id), ['a', 'b']);
      expect(repository.listCalls, 1);

      await container.read(communityControllerProvider.notifier).applyFilters();
      expect(repository.listCalls, 1);
    });

    test('loadNextPage concatenates unique communities', () async {
      final repository = _FakeCommunityRepository(
        pages: {
          0: _page(
            [_community('a'), _community('b')],
            page: 0,
            totalItems: 4,
            totalPages: 2,
            hasNext: true,
          ),
          1: _page(
            [_community('b'), _community('c')],
            page: 1,
            totalItems: 4,
            totalPages: 2,
          ),
        },
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      await container.read(communityControllerProvider.future);
      await container.read(communityControllerProvider.notifier).loadNextPage();

      final state = container.read(communityControllerProvider).value!;
      expect(state.result.items.map((item) => item.id), ['a', 'b', 'c']);
      expect(repository.requestedPages, [0, 1]);
    });

    test('loadNextPage ignores duplicate calls while loading', () async {
      final gate = Completer<PaginatedResponse<Community>>();
      final repository = _FakeCommunityRepository(
        pages: {
          0: _page(
            [_community('a')],
            page: 0,
            totalItems: 2,
            totalPages: 2,
            hasNext: true,
          ),
        },
        nextPageGate: gate,
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      await container.read(communityControllerProvider.future);
      final first = container
          .read(communityControllerProvider.notifier)
          .loadNextPage();
      final second = container
          .read(communityControllerProvider.notifier)
          .loadNextPage();

      await _waitUntil(() => repository.requestedPages.length == 2);
      expect(repository.requestedPages, [0, 1]);
      gate.complete(_page([_community('b')], page: 1, totalPages: 2));
      await Future.wait([first, second]);

      final state = container.read(communityControllerProvider).value!;
      expect(state.result.items.map((item) => item.id), ['a', 'b']);
    });

    test('loadNextPage error preserves existing list', () async {
      final repository = _FakeCommunityRepository(
        pages: {
          0: _page(
            [_community('a')],
            page: 0,
            totalItems: 2,
            totalPages: 2,
            hasNext: true,
          ),
        },
        failNextPage: true,
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      await container.read(communityControllerProvider.future);
      await container.read(communityControllerProvider.notifier).loadNextPage();

      final state = container.read(communityControllerProvider).value!;
      expect(state.result.items.map((item) => item.id), ['a']);
      expect(state.loadMoreError, isNotNull);
    });
  });
}

ProviderContainer _container(_FakeCommunityRepository repository) {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(
        () => _FakeAuthController(
          _session(userId: 'user-a', email: 'a@evolua.test'),
        ),
      ),
      communityRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._session);

  final AuthSession? _session;

  @override
  Future<AuthSession?> build() async => _session;
}

AuthSession _session({required String userId, required String email}) {
  return AuthSession(
    userId: userId,
    email: email,
    roles: const ['ROLE_USER'],
    accessToken: _jwt(userId: userId, email: email),
    refreshToken: 'refresh-$userId',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
}

String _jwt({required String userId, required String email}) {
  return 'fake.$userId.$email';
}

class _FakeCommunityRepository implements CommunityRepository {
  _FakeCommunityRepository({
    Map<int, PaginatedResponse<Community>>? pages,
    this.nextPageGate,
    this.failNextPage = false,
  }) : pages =
           pages ??
           {
             0: _page(
               [_community('a'), _community('b')],
               page: 0,
               totalItems: 2,
             ),
           };

  final Map<int, PaginatedResponse<Community>> pages;
  final Completer<PaginatedResponse<Community>>? nextPageGate;
  final bool failNextPage;
  final requestedPages = <int>[];

  int get listCalls => requestedPages.length;

  @override
  Future<PaginatedResponse<Community>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? visibility,
    String? category,
    bool? joined,
  }) async {
    requestedPages.add(page);
    if (page > 0 && failNextPage) {
      throw Exception('network');
    }
    if (page > 0 && nextPageGate != null) {
      return nextPageGate!.future;
    }
    return pages[page] ?? _page(const [], page: page);
  }

  @override
  Future<Community> create({
    required String name,
    required String slug,
    required String description,
    required String visibility,
    required String category,
  }) async {
    return _community('created');
  }

  @override
  Future<Community> join(String id) async {
    return _community(id, joined: true);
  }

  @override
  Future<Community> leave(String id) async {
    return _community(id);
  }
}

PaginatedResponse<Community> _page(
  List<Community> items, {
  required int page,
  int totalItems = 0,
  int totalPages = 1,
  bool hasNext = false,
}) {
  return PaginatedResponse(
    items: items,
    page: page,
    size: CommunityController.pageSize,
    totalItems: totalItems == 0 ? items.length : totalItems,
    totalPages: totalPages,
    hasNext: hasNext,
    hasPrevious: page > 0,
    sortBy: 'createdAt',
    sortDir: 'desc',
    filters: const {},
  );
}

Community _community(String id, {bool joined = false}) {
  return Community(
    id: id,
    slug: id,
    name: 'Espaço $id',
    description: 'Descrição $id',
    visibility: 'PUBLIC',
    category: 'acolhimento',
    memberCount: 1,
    joined: joined,
    createdAt: DateTime(2026, 6, 1),
  );
}
