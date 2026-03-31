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
                'Feed principal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.totalItems} publicacoes no ritmo de hoje.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Buscar por conteudo ou comunidade',
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
                      decoration: const InputDecoration(labelText: 'Comunidade'),
                      items: communityOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item == 'TODAS' ? 'Todas as comunidades' : item),
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
                      decoration: const InputDecoration(labelText: 'Visibilidade'),
                      items: const [
                        DropdownMenuItem(value: 'TODAS', child: Text('Todas')),
                        DropdownMenuItem(value: 'PUBLIC', child: Text('Publicas')),
                        DropdownMenuItem(value: 'PRIVATE', child: Text('Privadas')),
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
            title: 'Seu feed nao encontrou publicacoes com esses filtros.',
            subtitle:
                'Limpe a busca, troque a comunidade ou publique algo novo para movimentar esse espaco.',
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
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            SocialMetaPill(label: post.visibility),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(post.content, style: Theme.of(context).textTheme.bodyLarge),
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
