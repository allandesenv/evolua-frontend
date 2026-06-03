import 'dart:async';

import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/features/social/domain/repositories/community_repository.dart';
import 'package:evolua_frontend/features/social/domain/repositories/social_post_repository.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_module_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SocialModuleView spaces UX', () {
    testWidgets('renders spaces without internal tabs or future messages', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Espaços'), findsOneWidget);
      expect(find.text('Em destaque'), findsNothing);
      expect(find.text('Reflexões'), findsNothing);
      expect(find.text('Meus'), findsNothing);
      expect(find.text('Mensagens para o futuro'), findsNothing);
      expect(find.text('Participando'), findsOneWidget);
      expect(find.text('Ver espaço'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Sair do espaço'), findsNothing);
      expect(find.text('PUBLIC'), findsNothing);
      expect(find.text('joined'), findsNothing);
    });

    testWidgets('renders spaces structure before communities finish loading', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final gate = Completer<PaginatedResponse<Community>>();
      final communities = _FakeCommunityRepository(firstListGate: gate);

      await tester.pumpWidget(_testApp(communities: communities));
      await tester.pump();

      expect(find.text('Espaços'), findsOneWidget);
      expect(find.text('Buscar espaço'), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);

      gate.complete(_response(_communities(), page: 0, size: 8));
      await tester.pumpAndSettle();

      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('joining a space uses the card primary action', (tester) async {
      await _setCompactSurface(tester);
      final communities = _FakeCommunityRepository();

      await tester.pumpWidget(_testApp(communities: communities));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(communities.joinedIds, contains('community-open'));
    });

    testWidgets(
      'joining a space disables the action and prevents duplicate taps',
      (tester) async {
        await _setCompactSurface(tester);
        final joinGate = Completer<void>();
        final communities = _FakeCommunityRepository(joinGate: joinGate);

        await tester.pumpWidget(_testApp(communities: communities));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Entrar'));
        await tester.tap(find.text('Entrar'));
        await tester.pump();

        expect(find.text('Entrando...'), findsOneWidget);
        expect(communities.joinedIds, ['community-open']);

        await tester.tap(find.text('Entrando...'));
        await tester.pump();
        expect(communities.joinedIds, ['community-open']);

        joinGate.complete();
        await tester.pumpAndSettle();

        expect(find.text('Sair do espaço'), findsOneWidget);
      },
    );

    testWidgets('failed join restores the action and shows friendly feedback', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final communities = _FakeCommunityRepository(
        joinError: Exception('join failed'),
      );

      await tester.pumpWidget(_testApp(communities: communities));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Entrando...'), findsNothing);
      expect(
        find.text(
          'Não foi possível entrar neste espaço agora. Tente novamente.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('space detail writes reflection without space dropdown', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final posts = _FakeSocialPostRepository();

      await tester.pumpWidget(_testApp(posts: posts));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver espaço'));
      await tester.tap(find.text('Ver espaço'));
      await tester.pumpAndSettle();

      expect(find.text('Sair do espaço'), findsOneWidget);
      expect(find.text('Escrever reflexão'), findsOneWidget);
      expect(posts.lastListedCommunity, 'respirar');

      await tester.tap(find.text('Escrever reflexão'));
      await tester.pumpAndSettle();

      expect(find.text('Compartilhar em'), findsNothing);
      expect(find.text('Hoje percebi que...'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).last,
        'Hoje percebi que respirar mudou meu ritmo.',
      );
      await tester.tap(find.text('Compartilhar reflexão'));
      await tester.pumpAndSettle();

      expect(posts.lastCreatedCommunity, 'respirar');
      expect(
        posts.lastCreatedContent,
        'Hoje percebi que respirar mudou meu ritmo.',
      );
    });

    testWidgets(
      'compact spaces auto-loads paginated items from parent scroll',
      (tester) async {
        await _setCompactSurface(tester);
        final communities = _FakeCommunityRepository(
          pages: {
            0: _response(
              _manyCommunities(start: 1, count: 8),
              page: 0,
              size: 8,
              totalItems: 24,
              totalPages: 3,
              hasNext: true,
            ),
            1: _response(
              _manyCommunities(start: 9, count: 8),
              page: 1,
              size: 8,
              totalItems: 24,
              totalPages: 3,
              hasNext: true,
            ),
            2: _response(
              _manyCommunities(start: 17, count: 8),
              page: 2,
              size: 8,
              totalItems: 24,
              totalPages: 3,
            ),
          },
        );

        await tester.pumpWidget(_testApp(communities: communities));
        await tester.pumpAndSettle();

        expect(find.textContaining('24'), findsOneWidget);
        expect(find.text('Space 01'), findsOneWidget);
        expect(find.text('Space 09'), findsNothing);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -2200),
        );
        await tester.pumpAndSettle();

        expect(communities.requestedPages, containsAllInOrder([0, 1]));
        expect(find.text('Space 09'), findsOneWidget);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -3200),
        );
        await tester.pumpAndSettle();

        expect(communities.requestedPages, containsAllInOrder([0, 1, 2]));
        expect(find.text('Space 24'), findsOneWidget);
        expect(find.textContaining('todos os'), findsOneWidget);
      },
    );

    testWidgets('compact spaces ignores repeated scrolls while loading more', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final nextPageGate = Completer<PaginatedResponse<Community>>();
      final communities = _FakeCommunityRepository(
        nextPageGate: nextPageGate,
        pages: {
          0: _response(
            _manyCommunities(start: 1, count: 8),
            page: 0,
            size: 8,
            totalItems: 16,
            totalPages: 2,
            hasNext: true,
          ),
          1: _response(
            _manyCommunities(start: 9, count: 8),
            page: 1,
            size: 8,
            totalItems: 16,
            totalPages: 2,
          ),
        },
      );

      await tester.pumpWidget(_testApp(communities: communities));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2400),
      );
      await tester.pump();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump();

      expect(communities.requestedPages, [0, 1]);

      nextPageGate.complete(
        _response(
          _manyCommunities(start: 9, count: 8),
          page: 1,
          size: 8,
          totalItems: 16,
          totalPages: 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Space 16'), findsOneWidget);
      expect(communities.requestedPages, [0, 1]);
    });
  });
}

Future<void> _setCompactSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 820));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _testApp({
  CommunityRepository? communities,
  SocialPostRepository? posts,
}) {
  SharedPreferences.setMockInitialValues({});

  return ProviderScope(
    overrides: [
      communityRepositoryProvider.overrideWithValue(
        communities ?? _FakeCommunityRepository(),
      ),
      socialPostRepositoryProvider.overrideWithValue(
        posts ?? _FakeSocialPostRepository(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: SocialModuleView(),
          ),
        ),
      ),
    ),
  );
}

class _FakeCommunityRepository implements CommunityRepository {
  _FakeCommunityRepository({
    this.firstListGate,
    this.nextPageGate,
    this.joinGate,
    this.joinError,
    Map<int, PaginatedResponse<Community>>? pages,
  }) : pages = pages ?? const {};

  final joinedIds = <String>[];
  final Completer<PaginatedResponse<Community>>? firstListGate;
  final Completer<PaginatedResponse<Community>>? nextPageGate;
  final Completer<void>? joinGate;
  final Object? joinError;
  final Map<int, PaginatedResponse<Community>> pages;
  final requestedPages = <int>[];
  var _listCalls = 0;

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
    _listCalls += 1;
    requestedPages.add(page);
    if (_listCalls == 1 && firstListGate != null) {
      return firstListGate!.future;
    }
    if (page > 0 && nextPageGate != null) {
      return nextPageGate!.future;
    }
    final paged = pages[page];
    if (paged != null) {
      return paged;
    }
    final items = _communities()
        .where((community) => joined == null || community.joined == joined)
        .toList();
    return _response(items, page: page, size: size);
  }

  @override
  Future<Community> create({
    required String name,
    required String slug,
    required String description,
    required String visibility,
    required String category,
  }) async {
    return _communities().first;
  }

  @override
  Future<Community> join(String id) async {
    joinedIds.add(id);
    await joinGate?.future;
    if (joinError != null) {
      throw joinError!;
    }
    return _communities().firstWhere((item) => item.id == id);
  }

  @override
  Future<Community> leave(String id) async {
    return _communities().firstWhere((item) => item.id == id);
  }
}

class _FakeSocialPostRepository implements SocialPostRepository {
  String? lastListedCommunity;
  String? lastCreatedCommunity;
  String? lastCreatedContent;

  @override
  Future<PaginatedResponse<SocialPost>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? community,
    String? visibility,
    bool? mine,
  }) async {
    lastListedCommunity = community;
    final items = community == null
        ? const <SocialPost>[]
        : [
            SocialPost(
              id: 'post-1',
              userId: 'user-1',
              content: 'Uma reflexão já compartilhada.',
              community: community,
              visibility: 'PUBLIC',
              createdAt: DateTime(2026, 5, 22, 8),
            ),
          ];
    return PaginatedResponse(
      items: items,
      page: page,
      size: size,
      totalItems: items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: {'community': community},
    );
  }

  @override
  Future<SocialPost> create({
    required String content,
    required String community,
    required String visibility,
  }) async {
    lastCreatedCommunity = community;
    lastCreatedContent = content;
    return SocialPost(
      id: 'post-created',
      userId: 'user-1',
      content: content,
      community: community,
      visibility: visibility,
      createdAt: DateTime(2026, 5, 22, 9),
    );
  }
}

PaginatedResponse<Community> _response(
  List<Community> items, {
  required int page,
  required int size,
  int? totalItems,
  int totalPages = 1,
  bool hasNext = false,
}) {
  return PaginatedResponse(
    items: items,
    page: page,
    size: size,
    totalItems: totalItems ?? items.length,
    totalPages: totalPages,
    hasNext: hasNext,
    hasPrevious: page > 0,
    sortBy: 'createdAt',
    sortDir: 'desc',
    filters: const {},
  );
}

List<Community> _manyCommunities({required int start, required int count}) {
  return List.generate(count, (index) {
    final number = start + index;
    final id = 'space-${number.toString().padLeft(2, '0')}';
    return Community(
      id: id,
      slug: id,
      name: 'Space ${number.toString().padLeft(2, '0')}',
      description: 'Community $number for pagination coverage.',
      visibility: 'PUBLIC',
      category: 'acolhimento',
      memberCount: number,
      joined: false,
      createdAt: DateTime(2026, 5, number),
    );
  });
}

List<Community> _communities() {
  return [
    Community(
      id: 'community-joined',
      slug: 'respirar',
      name: 'Respirar junto',
      description: 'Um espaço para desacelerar e compartilhar percepções.',
      visibility: 'PUBLIC',
      category: 'acolhimento',
      memberCount: 12,
      joined: true,
      createdAt: DateTime(2026, 5, 22),
    ),
    Community(
      id: 'community-open',
      slug: 'clareza',
      name: 'Clareza possível',
      description: 'Conversas leves para organizar o momento.',
      visibility: 'PUBLIC',
      category: 'foco',
      memberCount: 8,
      joined: false,
      createdAt: DateTime(2026, 5, 21),
    ),
  ];
}
