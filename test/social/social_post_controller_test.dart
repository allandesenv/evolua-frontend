import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/features/social/domain/repositories/social_post_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SocialPostController offline cache', () {
    test(
      'stores successful feed and returns cached posts on network error',
      () async {
        SharedPreferences.setMockInitialValues({});
        final onlineContainer = ProviderContainer(
          overrides: [
            socialPostRepositoryProvider.overrideWithValue(
              _FakeSocialPostRepository(result: _response(_posts())),
            ),
          ],
        );
        addTearDown(onlineContainer.dispose);

        final onlineState = await onlineContainer.read(
          socialPostControllerProvider.future,
        );

        expect(onlineState.isFromCache, isFalse);
        expect(onlineState.result.items, hasLength(2));

        final offlineContainer = ProviderContainer(
          overrides: [
            socialPostRepositoryProvider.overrideWithValue(
              _FakeSocialPostRepository(error: _networkError()),
            ),
          ],
        );
        addTearDown(offlineContainer.dispose);

        final offlineState = await offlineContainer.read(
          socialPostControllerProvider.future,
        );

        expect(offlineState.isFromCache, isTrue);
        expect(offlineState.result.items, hasLength(2));
        expect(offlineState.offlineMessage, contains('reflexoes salvas'));
      },
    );

    test('returns friendly offline empty state when no cache exists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          socialPostRepositoryProvider.overrideWithValue(
            _FakeSocialPostRepository(error: _networkError()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(socialPostControllerProvider.future);

      expect(state.isFromCache, isTrue);
      expect(state.result.items, isEmpty);
      expect(
        state.offlineMessage,
        contains('Nao encontramos reflexoes salvas'),
      );
    });
  });
}

class _FakeSocialPostRepository implements SocialPostRepository {
  const _FakeSocialPostRepository({this.result, this.error});

  final PaginatedResponse<SocialPost>? result;
  final Object? error;

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
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return result ?? PaginatedResponse.empty(page: page, size: size);
  }

  @override
  Future<SocialPost> create({
    required String content,
    required String community,
    required String visibility,
  }) async {
    return _posts().first;
  }
}

PaginatedResponse<SocialPost> _response(List<SocialPost> items) {
  return PaginatedResponse(
    items: items,
    page: 0,
    size: 4,
    totalItems: items.length,
    totalPages: 1,
    hasNext: false,
    hasPrevious: false,
    sortBy: 'createdAt',
    sortDir: 'desc',
    filters: const {},
  );
}

List<SocialPost> _posts() {
  return [
    SocialPost(
      id: 'post-1',
      userId: 'user-1',
      content: 'Uma reflexao salva para momentos sem conexao.',
      community: 'respirar',
      visibility: 'PUBLIC',
      createdAt: DateTime(2026, 5, 6, 10),
    ),
    SocialPost(
      id: 'post-2',
      userId: 'user-2',
      content: 'Outro conteudo que continua acessivel offline.',
      community: 'clareza',
      visibility: 'PUBLIC',
      createdAt: DateTime(2026, 5, 6, 9),
    ),
  ];
}

DioException _networkError() {
  return DioException(
    requestOptions: RequestOptions(path: '/v1/posts'),
    type: DioExceptionType.connectionError,
  );
}
