import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';

class SocialFeedState {
  const SocialFeedState({
    required this.result,
    this.isFromCache = false,
    this.offlineMessage,
  });

  final PaginatedResponse<SocialPost> result;
  final bool isFromCache;
  final String? offlineMessage;

  int get totalItems => result.totalItems;

  factory SocialFeedState.fresh(PaginatedResponse<SocialPost> result) {
    return SocialFeedState(result: result);
  }

  factory SocialFeedState.cached(PaginatedResponse<SocialPost> result) {
    return SocialFeedState(
      result: result,
      isFromCache: true,
      offlineMessage:
          'Você está vendo reflexões salvas deste recorte enquanto a conexão volta.',
    );
  }

  factory SocialFeedState.offlineEmpty({
    required int page,
    required int size,
    required String sortBy,
    required String sortDir,
    required Map<String, dynamic> filters,
  }) {
    return SocialFeedState(
      result: PaginatedResponse.empty(
        page: page,
        size: size,
        sortBy: sortBy,
        sortDir: sortDir,
        filters: filters,
      ),
      isFromCache: true,
      offlineMessage:
          'Não encontramos reflexões salvas neste recorte. Quando a conexão voltar, atualize para carregar o feed.',
    );
  }
}
