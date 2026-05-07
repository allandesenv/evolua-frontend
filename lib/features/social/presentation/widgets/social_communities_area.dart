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
    required this.onJoin,
    required this.onLeave,
    required this.canCreate,
    required this.onCreate,
    required this.headline,
    required this.description,
    this.showMembershipFilter = true,
    this.showScopeChips = false,
    this.currentScope,
    this.onExploreSelected,
    this.onMineSelected,
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
  final Future<void> Function(Community community) onJoin;
  final Future<void> Function(Community community) onLeave;
  final bool canCreate;
  final VoidCallback onCreate;
  final String headline;
  final String description;
  final bool showMembershipFilter;
  final bool showScopeChips;
  final String? currentScope;
  final VoidCallback? onExploreSelected;
  final VoidCallback? onMineSelected;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final isMine = headline == 'Meus espacos';
    return Column(
      children: [
        PrimaryPanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final fieldWidth = compact ? constraints.maxWidth : 220.0;
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
                        child: Icon(
                          isMine
                              ? Icons.verified_user_rounded
                              : Icons.explore_rounded,
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
                          label: const Text('Criar espaco'),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SocialMetaPill(
                        label: isMine
                            ? '${result.totalItems} participando'
                            : '${result.totalItems} para explorar',
                      ),
                      if (showScopeChips) ...[
                        ChoiceChip(
                          label: const Text('Explorar'),
                          selected: currentScope == 'explore',
                          onSelected: (_) => onExploreSelected?.call(),
                        ),
                        ChoiceChip(
                          label: const Text('Meus espacos'),
                          selected: currentScope == 'mine',
                          onSelected: (_) => onMineSelected?.call(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por espaco, descricao ou tema',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (showMembershipFilter)
                        SizedBox(
                          width: fieldWidth,
                          child: DropdownButtonFormField<String>(
                            initialValue: membershipFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Recorte',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'TODAS',
                                child: Text('Todas'),
                              ),
                              DropdownMenuItem(
                                value: 'INGRESSADAS',
                                child: Text('Participando'),
                              ),
                              DropdownMenuItem(
                                value: 'DESCOBRIR',
                                child: Text('Descobrir'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                onMembershipChanged(value);
                              }
                            },
                          ),
                        ),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          initialValue: visibilityFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Visibilidade',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'TODAS',
                              child: Text('Todas'),
                            ),
                            DropdownMenuItem(
                              value: 'PUBLIC',
                              child: Text('Publicas'),
                            ),
                            DropdownMenuItem(
                              value: 'PRIVATE',
                              child: Text('Privadas'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              onVisibilityChanged(value);
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          initialValue: categoryFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                          ),
                          items: categories
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item == 'TODAS' ? 'Todas' : item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              onCategoryChanged(value);
                            }
                          },
                        ),
                      ),
                    ],
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
            title: 'Nenhum espaco apareceu com esse recorte.',
            subtitle: canCreate
                ? 'Amplie a busca, troque os filtros ou crie o primeiro espaco para esse contexto.'
                : 'Amplie a busca ou troque os filtros para encontrar um espaco com mais aderencia ao seu momento.',
            actionLabel: canCreate ? 'Criar espaco' : 'Ver todos',
            onAction: canCreate
                ? onCreate
                : () {
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
                  child: PrimaryPanel(
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
                                    : AppColors.surfaceStrong.withValues(
                                        alpha: 0.58,
                                      ),
                                border: Border.all(
                                  color: community.joined
                                      ? AppColors.accent.withValues(alpha: 0.24)
                                      : AppColors.outline.withValues(
                                          alpha: 0.24,
                                        ),
                                ),
                              ),
                              child: Icon(
                                community.joined
                                    ? Icons.check_rounded
                                    : Icons.groups_rounded,
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
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
                                        label:
                                            '${community.memberCount} pessoas',
                                      ),
                                      SocialMetaPill(
                                        label: community.joined
                                            ? 'Participando'
                                            : 'Explorar',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SocialMetaPill(label: community.visibility),
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
                              ? OutlinedButton.icon(
                                  onPressed: () => onLeave(community),
                                  icon: const Icon(Icons.logout_rounded),
                                  label: const Text('Sair do espaco'),
                                )
                              : FilledButton.icon(
                                  onPressed: () => onJoin(community),
                                  icon: const Icon(Icons.group_add_rounded),
                                  label: const Text('Entrar no espaco'),
                                ),
                        ),
                      ],
                    ),
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
}
