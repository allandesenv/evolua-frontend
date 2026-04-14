import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_shared_widgets.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

class SocialFeedArea extends StatelessWidget {
  const SocialFeedArea({
    super.key,
    required this.result,
    required this.searchController,
    required this.visibilityFilter,
    required this.communityFilter,
    required this.communityOptions,
    required this.contextualHint,
    required this.sectionLabel,
    required this.onSearchChanged,
    required this.onVisibilityFilterChanged,
    required this.onCommunityFilterChanged,
    required this.onPageChanged,
  });

  final PaginatedResponse<SocialPost> result;
  final TextEditingController searchController;
  final String visibilityFilter;
  final String communityFilter;
  final List<String> communityOptions;
  final String contextualHint;
  final String sectionLabel;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onVisibilityFilterChanged;
  final ValueChanged<String> onCommunityFilterChanged;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                contextualHint,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Text(
                sectionLabel == 'Minhas reflexoes'
                    ? '${result.totalItems} reflexoes suas neste recorte.'
                    : '${result.totalItems} reflexoes no ritmo de hoje.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Buscar por reflexao ou espaco',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 280,
                    child: DropdownButtonFormField<String>(
                      initialValue: communityFilter,
                      decoration: const InputDecoration(labelText: 'Espaco'),
                      items: communityOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(
                                item == 'TODAS' ? 'Todos os espacos' : item,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          onCommunityFilterChanged(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
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
                          onVisibilityFilterChanged(value);
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
            icon: Icons.dynamic_feed_rounded,
            title: 'Nenhuma reflexao apareceu com esse recorte.',
            subtitle:
                'Limpe a busca, troque o espaco ou compartilhe uma nova reflexao para movimentar esse momento.',
            actionLabel: 'Ver tudo',
            onAction: () {
              searchController.clear();
              onCommunityFilterChanged('TODAS');
              onVisibilityFilterChanged('TODAS');
            },
          )
        else
          Column(
            children: [
              ...result.items.map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PrimaryPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            Text(
                              post.community,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppColors.textPrimary),
                            ),
                            SocialMetaPill(label: post.visibility),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          post.content,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: const [
                            _LightInteractionChip(
                              icon: Icons.favorite_border_rounded,
                              label: 'Isso ressoou comigo',
                            ),
                            _LightInteractionChip(
                              icon: Icons.auto_awesome_outlined,
                              label: 'Quero aplicar isso',
                            ),
                            _LightInteractionChip(
                              icon: Icons.bookmark_border_rounded,
                              label: 'Salvei',
                            ),
                          ],
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

class _LightInteractionChip extends StatelessWidget {
  const _LightInteractionChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.surfaceStrong.withValues(alpha: 0.38),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
