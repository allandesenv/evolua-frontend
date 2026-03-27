import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocialModuleView extends ConsumerStatefulWidget {
  const SocialModuleView({super.key});

  @override
  ConsumerState<SocialModuleView> createState() => _SocialModuleViewState();
}

class _SocialModuleViewState extends ConsumerState<SocialModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _communityController = TextEditingController(text: 'geral');
  final _searchController = TextEditingController();
  String _visibility = 'PUBLIC';
  String _visibilityFilter = 'TODOS';

  @override
  void initState() {
    super.initState();
    ref.listenManual(socialPostControllerProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DioException
            ? (error.response?.data is Map<String, dynamic>
                ? ((error.response?.data['details'] as List?)?.join(', ') ??
                    error.message ??
                    'Nao foi possivel publicar.')
                : error.message ?? 'Nao foi possivel publicar.')
            : 'Nao foi possivel publicar.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _communityController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(socialPostControllerProvider.notifier).create(
          content: _contentController.text.trim(),
          community: _communityController.text.trim(),
          visibility: _visibility,
        );

    if (!mounted) {
      return;
    }

    _contentController.clear();
    _communityController.text = 'geral';
    setState(() => _visibility = 'PUBLIC');
  }

  Future<void> _applyFilters() {
    return ref.read(socialPostControllerProvider.notifier).applyFilters(
          search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
          visibility: _visibilityFilter == 'TODOS' ? null : _visibilityFilter,
        );
  }

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(socialPostControllerProvider);

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
                      'Comunidade segura',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(socialPostControllerProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Compartilhe uma reflexao com clareza e deixe a visibilidade sob seu controle.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _contentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'O que voce quer compartilhar?',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.forum_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Escreva o conteudo.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _communityController,
                            decoration: const InputDecoration(
                              labelText: 'Comunidade',
                              prefixIcon: Icon(Icons.groups_rounded),
                            ),
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'Informe a comunidade.'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _visibility,
                            decoration: const InputDecoration(
                              labelText: 'Visibilidade',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'PUBLIC', child: Text('PUBLICA')),
                              DropdownMenuItem(value: 'PRIVATE', child: Text('PRIVADA')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _visibility = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: postsState.isLoading && !postsState.hasValue ? null : _submit,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Publicar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        postsState.when(
          data: (result) => _SocialFeed(
            result: result,
            searchController: _searchController,
            visibilityFilter: _visibilityFilter,
            onSearchChanged: (_) => _applyFilters(),
            onVisibilityFilterChanged: (value) {
              setState(() => _visibilityFilter = value);
              _applyFilters();
            },
            onPageChanged: (page) => ref.read(socialPostControllerProvider.notifier).goToPage(page),
          ),
          error: (error, stackTrace) => const _SocialErrorState(),
          loading: () => const _SocialLoadingState(),
        ),
      ],
    );
  }
}

class _SocialFeed extends StatelessWidget {
  const _SocialFeed({
    required this.result,
    required this.searchController,
    required this.visibilityFilter,
    required this.onSearchChanged,
    required this.onVisibilityFilterChanged,
    required this.onPageChanged,
  });

  final PaginatedResponse<SocialPost> result;
  final TextEditingController searchController;
  final String visibilityFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onVisibilityFilterChanged;
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
                'Filtrar conversas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.totalItems} posts encontrados.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Buscar por comunidade ou conteudo',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['TODOS', 'PUBLIC', 'PRIVATE']
                    .map(
                      (value) => ChoiceChip(
                        label: Text(value == 'TODOS' ? 'Todas' : value),
                        selected: visibilityFilter == value,
                        onSelected: (_) => onVisibilityFilterChanged(value),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (result.items.isEmpty)
          GuidedEmptyState(
            icon: Icons.groups_rounded,
            title: 'Nenhuma conversa aparece com esse filtro.',
            subtitle: 'Tente ampliar a busca ou publique um post para iniciar a troca com seguranca.',
            actionLabel: 'Limpar filtros',
            onAction: () {
              searchController.clear();
              onVisibilityFilterChanged('TODOS');
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                post.community,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                            ),
                            Text(
                              post.visibility,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.accent,
                                  ),
                            ),
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

class _SocialLoadingState extends StatelessWidget {
  const _SocialLoadingState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Carregando posts...'),
        ],
      ),
    );
  }
}

class _SocialErrorState extends StatelessWidget {
  const _SocialErrorState();

  @override
  Widget build(BuildContext context) {
    return GuidedEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Nao conseguimos abrir a comunidade agora.',
      subtitle: 'Atualize a pagina ou tente novamente daqui a pouco.',
      actionLabel: 'Tentar novamente',
      onAction: () {},
    );
  }
}
