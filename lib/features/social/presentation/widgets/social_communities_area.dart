import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_shared_widgets.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

class SocialCommunitiesArea extends StatelessWidget {
  const SocialCommunitiesArea({
    super.key,
    required this.result,
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
    required this.onView,
    required this.onJoin,
    required this.canCreate,
    required this.onCreate,
    required this.headline,
    required this.description,
    this.onRefresh,
  });

  final PaginatedResponse<Community> result;
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
  final ValueChanged<Community> onView;
  final Future<void> Function(Community community) onJoin;
  final bool canCreate;
  final VoidCallback onCreate;
  final String headline;
  final String description;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                            color: AppColors.accent.withValues(alpha: 0.22),
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
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              description,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (canCreate)
                        OutlinedButton.icon(
                          onPressed: onCreate,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Criar espaço'),
                        ),
                      if (onRefresh != null)
                        OutlinedButton.icon(
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Atualizar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SocialMetaPill(label: _resultCountLabel(result.totalItems)),
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
        if (result.items.isEmpty)
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
              ...result.items.map(
                (community) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CommunityCard(
                    community: community,
                    onView: () => onView(community),
                    onJoin: () => onJoin(community),
                  ),
                ),
              ),
              PaginationControls(
                page: result.page,
                totalPages: result.totalPages,
                onPageChanged: onPageChanged,
              ),
            ],
          ),
      ],
    );
  }

  String _resultCountLabel(int total) {
    if (total == 1) {
      return '1 espaço disponível';
    }
    return '$total espaços disponíveis';
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.community,
    required this.onView,
    required this.onJoin,
  });

  final Community community;
  final VoidCallback onView;
  final VoidCallback onJoin;

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
                    onPressed: onJoin,
                    icon: const Icon(Icons.group_add_rounded),
                    label: const Text('Entrar'),
                  ),
          ),
        ],
      ),
    );
  }
}
