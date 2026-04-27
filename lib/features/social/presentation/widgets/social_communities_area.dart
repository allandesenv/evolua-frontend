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
  final bool showScopeChips;
  final String? currentScope;
  final VoidCallback? onExploreSelected;
  final VoidCallback? onMineSelected;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      headline,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (canCreate)
                    OutlinedButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Criar espaco'),
                    ),
                ],
              ),
              if (showScopeChips || onRefresh != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (showScopeChips)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
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
                      ),
                    if (onRefresh != null)
                      OutlinedButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Atualizar'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                headline == 'Meus espacos'
                    ? '${result.totalItems} espacos em que voce ja entrou.'
                    : '${result.totalItems} espacos para explorar sem pressa.',
                style: Theme.of(context).textTheme.bodyMedium,
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
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: membershipFilter,
                      decoration: const InputDecoration(labelText: 'Recorte'),
                      items: const [
                        DropdownMenuItem(value: 'TODAS', child: Text('Todas')),
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
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: visibilityFilter,
                      decoration: const InputDecoration(
                        labelText: 'Visibilidade',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'TODAS', child: Text('Todas')),
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
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: categoryFilter,
                      decoration: const InputDecoration(labelText: 'Categoria'),
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
                          children: [
                            Expanded(
                              child: Text(
                                community.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: AppColors.textPrimary),
                              ),
                            ),
                            SocialMetaPill(label: community.visibility),
                          ],
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
                            SocialMetaPill(
                              label: community.joined
                                  ? 'Participando'
                                  : 'Explorar',
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
