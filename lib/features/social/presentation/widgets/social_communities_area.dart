import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_shared_widgets.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

class SocialCommunitiesArea extends StatefulWidget {
  const SocialCommunitiesArea({
    super.key,
    required this.result,
    required this.isInitialLoading,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.isFromCache,
    this.loadMoreError,
    this.refreshError,
    required this.searchController,
    required this.visibilityFilter,
    required this.categoryFilter,
    required this.membershipFilter,
    required this.categories,
    required this.onSearchChanged,
    required this.onVisibilityChanged,
    required this.onCategoryChanged,
    required this.onMembershipChanged,
    required this.onPageChanged,
    required this.onLoadMore,
    required this.onRetryLoadMore,
    required this.onView,
    required this.onJoin,
    this.joiningCommunityId,
    required this.canCreate,
    required this.onCreate,
    required this.headline,
    required this.description,
    this.onRefresh,
  });

  final PaginatedResponse<Community> result;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isFromCache;
  final Object? loadMoreError;
  final Object? refreshError;
  final TextEditingController searchController;
  final String visibilityFilter;
  final String categoryFilter;
  final String membershipFilter;
  final List<String> categories;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onMembershipChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onLoadMore;
  final VoidCallback onRetryLoadMore;
  final ValueChanged<Community> onView;
  final Future<void> Function(Community community) onJoin;
  final String? joiningCommunityId;
  final bool canCreate;
  final VoidCallback onCreate;
  final String headline;
  final String description;
  final VoidCallback? onRefresh;

  @override
  State<SocialCommunitiesArea> createState() => _SocialCommunitiesAreaState();
}

class _SocialCommunitiesAreaState extends State<SocialCommunitiesArea> {
  ScrollPosition? _scrollPosition;
  bool _compactCatalog = false;
  bool _postFrameCheckScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePostFrameCheck();
  }

  @override
  void didUpdateWidget(SocialCommunitiesArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedulePostFrameCheck();
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_maybeLoadMore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isInitialLoading = widget.isInitialLoading;
    final isRefreshing = widget.isRefreshing;
    final isLoadingMore = widget.isLoadingMore;
    final isFromCache = widget.isFromCache;
    final loadMoreError = widget.loadMoreError;
    final refreshError = widget.refreshError;
    final searchController = widget.searchController;
    final onSearchChanged = widget.onSearchChanged;
    final onVisibilityChanged = widget.onVisibilityChanged;
    final onCategoryChanged = widget.onCategoryChanged;
    final onMembershipChanged = widget.onMembershipChanged;
    final onPageChanged = widget.onPageChanged;
    final onRetryLoadMore = widget.onRetryLoadMore;
    final onView = widget.onView;
    final onJoin = widget.onJoin;
    final canCreate = widget.canCreate;
    final onCreate = widget.onCreate;
    final headline = widget.headline;
    final description = widget.description;
    final onRefresh = widget.onRefresh;

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final compactCatalog = outerConstraints.maxWidth < 680;
        _compactCatalog = compactCatalog;
        _schedulePostFrameCheck();
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) =>
              _handleScrollNotification(notification.metrics, compactCatalog),
          child: Column(
            children: [
              PrimaryPanel(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: AppColors.accent.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.22,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: AppColors.accent,
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: compact
                                    ? constraints.maxWidth
                                    : constraints.maxWidth - 180,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    headline,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    description,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            if (canCreate)
                              OutlinedButton.icon(
                                onPressed: onCreate,
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                ),
                                label: const Text('Criar espaço'),
                              ),
                            if (onRefresh != null)
                              OutlinedButton.icon(
                                onPressed: isRefreshing ? null : onRefresh,
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(
                                  isRefreshing ? 'Atualizando...' : 'Atualizar',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SocialMetaPill(
                          label: _resultCountLabel(result.totalItems),
                        ),
                        if (isRefreshing ||
                            isFromCache ||
                            refreshError != null) ...[
                          const SizedBox(height: 12),
                          _CommunityCatalogNotice(
                            isRefreshing: isRefreshing,
                            isFromCache: isFromCache,
                            hasRefreshError: refreshError != null,
                            onRefresh: onRefresh,
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          decoration: const InputDecoration(
                            labelText: 'Buscar espaço',
                            hintText: 'Nome, descrição ou tema',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (isInitialLoading)
                const FeedSkeleton(cards: 3)
              else if (result.items.isEmpty)
                GuidedEmptyState(
                  icon: Icons.groups_rounded,
                  title: 'Nenhum espaço encontrado.',
                  subtitle:
                      'Tente buscar por outro tema ou volte mais tarde para descobrir novos espaços.',
                  actionLabel: 'Ver todos',
                  onAction: () {
                    searchController.clear();
                    onSearchChanged('');
                    onMembershipChanged('TODAS');
                    onVisibilityChanged('TODAS');
                    onCategoryChanged('TODAS');
                  },
                )
              else
                Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: result.items.length,
                      itemBuilder: (context, index) {
                        final community = result.items[index];
                        final isJoining =
                            widget.joiningCommunityId == community.id;
                        return Padding(
                          key: ValueKey(community.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CommunityCard(
                            community: community,
                            onView: () => onView(community),
                            onJoin: () => onJoin(community),
                            isJoining: isJoining,
                          ),
                        );
                      },
                    ),
                    if (compactCatalog)
                      _CommunityLoadMoreFooter(
                        result: result,
                        isLoadingMore: isLoadingMore,
                        loadMoreError: loadMoreError,
                        onRetry: onRetryLoadMore,
                      )
                    else
                      PaginationControls(
                        page: result.page,
                        totalPages: result.totalPages,
                        onPageChanged: onPageChanged,
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  bool _handleScrollNotification(ScrollMetrics metrics, bool compactCatalog) {
    _tryLoadMore(metrics.extentAfter, compactCatalog);
    return false;
  }

  void _schedulePostFrameCheck() {
    if (_postFrameCheckScheduled) {
      return;
    }
    _postFrameCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameCheckScheduled = false;
      if (!mounted) {
        return;
      }
      _syncAncestorScrollPosition();
      _maybeLoadMore();
    });
  }

  void _syncAncestorScrollPosition() {
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition == nextPosition) {
      return;
    }
    _scrollPosition?.removeListener(_maybeLoadMore);
    _scrollPosition = nextPosition;
    _scrollPosition?.addListener(_maybeLoadMore);
  }

  void _maybeLoadMore() {
    final position = _scrollPosition;
    if (position == null || !position.hasPixels) {
      return;
    }
    _tryLoadMore(position.extentAfter, _compactCatalog);
  }

  void _tryLoadMore(double extentAfter, bool compactCatalog) {
    if (!compactCatalog ||
        widget.isInitialLoading ||
        widget.isLoadingMore ||
        widget.loadMoreError != null ||
        !widget.result.hasNext) {
      return;
    }
    if (extentAfter < 480) {
      widget.onLoadMore();
    }
  }

  String _resultCountLabel(int total) {
    if (total == 1) {
      return '1 espaço disponível';
    }
    return '$total espaços disponíveis';
  }
}

class _CommunityCatalogNotice extends StatelessWidget {
  const _CommunityCatalogNotice({
    required this.isRefreshing,
    required this.isFromCache,
    required this.hasRefreshError,
    required this.onRefresh,
  });

  final bool isRefreshing;
  final bool isFromCache;
  final bool hasRefreshError;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final message = hasRefreshError
        ? 'Não foi possível atualizar agora. Mostrando os espaços já carregados.'
        : isRefreshing
        ? 'Atualizando espaços em segundo plano...'
        : isFromCache
        ? 'Mostrando espaços já carregados.'
        : '';
    if (message.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (isRefreshing && !hasRefreshError)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.info_outline_rounded, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (hasRefreshError && onRefresh != null)
              TextButton(
                onPressed: onRefresh,
                child: const Text('Tentar novamente'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommunityLoadMoreFooter extends StatelessWidget {
  const _CommunityLoadMoreFooter({
    required this.result,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.onRetry,
  });

  final PaginatedResponse<Community> result;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Column(
          children: [
            Text(
              'Não foi possível carregar mais espaços.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (!result.hasNext) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        child: Text(
          'Você viu todos os espaços disponíveis.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.community,
    required this.onView,
    required this.onJoin,
    required this.isJoining,
  });

  final Community community;
  final VoidCallback onView;
  final VoidCallback onJoin;
  final bool isJoining;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: community.joined
                      ? AppColors.accent.withValues(alpha: 0.14)
                      : AppColors.surfaceStrong.withValues(alpha: 0.58),
                  border: Border.all(
                    color: community.joined
                        ? AppColors.accent.withValues(alpha: 0.24)
                        : AppColors.outline.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(
                  community.joined ? Icons.check_rounded : Icons.groups_rounded,
                  color: community.joined
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SocialMetaPill(label: community.category),
                        SocialMetaPill(
                          label: '${community.memberCount} pessoas',
                        ),
                        const SocialMetaPill(label: 'Aberto'),
                        if (community.joined)
                          const SocialMetaPill(label: 'Participando'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            community.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: community.joined
                ? FilledButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('Ver espaço'),
                  )
                : FilledButton.icon(
                    onPressed: isJoining ? null : onJoin,
                    icon: isJoining
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.group_add_rounded),
                    label: Text(isJoining ? 'Entrando...' : 'Entrar'),
                  ),
          ),
        ],
      ),
    );
  }
}
