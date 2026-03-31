import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_communities_area.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_feed_area.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_post_composer.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_shared_widgets.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SocialModuleTab { feed, communities }

class SocialModuleView extends ConsumerStatefulWidget {
  const SocialModuleView({
    super.key,
    this.initialTab = SocialModuleTab.feed,
    this.showTabs = true,
  });

  final SocialModuleTab initialTab;
  final bool showTabs;

  @override
  ConsumerState<SocialModuleView> createState() => _SocialModuleViewState();
}

class _SocialModuleViewState extends ConsumerState<SocialModuleView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _postFormKey = GlobalKey<FormState>();
  final _postContentController = TextEditingController();
  final _feedSearchController = TextEditingController();
  final _communitySearchController = TextEditingController();
  String _postVisibility = 'PUBLIC';
  String _feedVisibilityFilter = 'TODAS';
  String _feedCommunityFilter = 'TODAS';
  String _communityVisibilityFilter = 'TODAS';
  String _communityCategoryFilter = 'TODAS';
  String _communityMembershipFilter = 'TODAS';
  String? _postCommunitySlug;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.index = switch (widget.initialTab) {
      SocialModuleTab.feed => 0,
      SocialModuleTab.communities => 1,
    };

    ref.listenManual(socialPostControllerProvider, (previous, next) {
      if (next.hasError) {
        _showError(next.error, fallback: 'Nao foi possivel atualizar o feed.');
      }
    });

    ref.listenManual(communityControllerProvider, (previous, next) {
      if (next.hasError) {
        _showError(next.error, fallback: 'Nao foi possivel atualizar as comunidades.');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postContentController.dispose();
    _feedSearchController.dispose();
    _communitySearchController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (!_postFormKey.currentState!.validate()) {
      return;
    }

    final selectedCommunity = _postCommunitySlug;
    if (selectedCommunity == null || selectedCommunity.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Escolha uma comunidade para publicar.',
        icon: Icons.groups_rounded,
      );
      return;
    }

    await ref.read(socialPostControllerProvider.notifier).create(
          content: _postContentController.text.trim(),
          community: selectedCommunity,
          visibility: _postVisibility,
        );

    if (!mounted) {
      return;
    }

    _postContentController.clear();
    AppSnackBar.show(
      context,
      message: 'Post publicado com sucesso.',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  Future<void> _applyFeedFilters() {
    return ref.read(socialPostControllerProvider.notifier).applyFilters(
          search: _feedSearchController.text.trim().isEmpty ? null : _feedSearchController.text.trim(),
          community: _feedCommunityFilter == 'TODAS' ? null : _feedCommunityFilter,
          visibility: _feedVisibilityFilter == 'TODAS' ? null : _feedVisibilityFilter,
        );
  }

  Future<void> _applyCommunityFilters() {
    return ref.read(communityControllerProvider.notifier).applyFilters(
          search: _communitySearchController.text.trim().isEmpty
              ? null
              : _communitySearchController.text.trim(),
          visibility: _communityVisibilityFilter == 'TODAS' ? null : _communityVisibilityFilter,
          category: _communityCategoryFilter == 'TODAS' ? null : _communityCategoryFilter,
          joined: switch (_communityMembershipFilter) {
            'INGRESSADAS' => true,
            'DESCOBRIR' => false,
            _ => null,
          },
        );
  }

  Future<void> _openCreateCommunityModal() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String visibility = 'PUBLIC';
    String category = 'acolhimento';

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (context) {
          return _CreateCommunitySheet(
            formKey: formKey,
            nameController: nameController,
            descriptionController: descriptionController,
            initialVisibility: visibility,
            initialCategory: category,
            slugify: _slugify,
            onSubmit: (name, slug, description, nextVisibility, nextCategory) async {
              visibility = nextVisibility;
              category = nextCategory;
              await ref.read(communityControllerProvider.notifier).create(
                    name: name,
                    slug: slug,
                    description: description,
                    visibility: visibility,
                    category: category,
                  );

              if (!mounted) {
                return;
              }

              Navigator.of(this.context).pop();
              _tabController.animateTo(1);
              AppSnackBar.show(
                this.context,
                message: 'Comunidade criada com sucesso.',
                icon: Icons.groups_rounded,
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      descriptionController.dispose();
    }
  }

  void _showError(Object? error, {required String fallback}) {
    final message = error is DioException
        ? (error.response?.data is Map<String, dynamic>
            ? ((error.response?.data['details'] as List?)?.join(', ') ?? error.message ?? fallback)
            : error.message ?? fallback)
        : fallback;

    AppSnackBar.show(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
    );
  }

  String _slugify(String value) {
    final slug = value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? 'nova-comunidade' : slug;
  }

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(socialPostControllerProvider);
    final communitiesState = ref.watch(communityControllerProvider);
    final joinedCommunities =
        communitiesState.asData?.value.items.where((item) => item.joined).toList() ??
            const <Community>[];
    final allCommunities = communitiesState.asData?.value.items ?? const <Community>[];

    _postCommunitySlug ??= joinedCommunities.isNotEmpty ? joinedCommunities.first.slug : null;

    final communityFilterOptions = <String>{
      'TODAS',
      ...allCommunities.map((item) => item.slug),
    }.toList();
    final categories = <String>{
      'TODAS',
      ...allCommunities.map((item) => item.category),
    }.toList();

    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialTab == SocialModuleTab.feed
                              ? 'Feed do dia'
                              : 'Comunidades em movimento',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.initialTab == SocialModuleTab.feed
                              ? 'Passe pelo que importa agora, publique algo curto e siga em frente sem peso.'
                              : 'Explore grupos, encontre recortes que fazem sentido e crie um espaco quando for a hora.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(socialPostControllerProvider.notifier).refresh();
                          ref.read(communityControllerProvider.notifier).refresh();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Atualizar'),
                      ),
                      if (widget.initialTab == SocialModuleTab.communities)
                        FilledButton.icon(
                          onPressed: _openCreateCommunityModal,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Nova comunidade'),
                        ),
                    ],
                  ),
                ],
              ),
              if (widget.showTabs) ...[
                const SizedBox(height: 18),
                TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.accent,
                  tabs: const [
                    Tab(text: 'Feed'),
                    Tab(text: 'Comunidades'),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            if (_tabController.index == 0) {
              return Column(
                children: [
                  SocialPostComposer(
                    formKey: _postFormKey,
                    contentController: _postContentController,
                    visibility: _postVisibility,
                    selectedCommunitySlug: _postCommunitySlug,
                    joinedCommunities: joinedCommunities,
                    onVisibilityChanged: (value) => setState(() => _postVisibility = value),
                    onCommunityChanged: (value) => setState(() => _postCommunitySlug = value),
                    onSubmit: postsState.isLoading && !postsState.hasValue ? null : _submitPost,
                  ),
                  const SizedBox(height: 16),
                  postsState.when(
                    data: (result) => SocialFeedArea(
                      result: result,
                      searchController: _feedSearchController,
                      visibilityFilter: _feedVisibilityFilter,
                      communityFilter: _feedCommunityFilter,
                      communityOptions: communityFilterOptions,
                      onSearchChanged: (_) => _applyFeedFilters(),
                      onVisibilityFilterChanged: (value) {
                        setState(() => _feedVisibilityFilter = value);
                        _applyFeedFilters();
                      },
                      onCommunityFilterChanged: (value) {
                        setState(() => _feedCommunityFilter = value);
                        _applyFeedFilters();
                      },
                      onPageChanged: (page) =>
                          ref.read(socialPostControllerProvider.notifier).goToPage(page),
                    ),
                    error: (error, stackTrace) => SocialActionableErrorState(
                      title: 'Nao conseguimos abrir o feed agora.',
                      onRetry: () => ref.read(socialPostControllerProvider.notifier).refresh(),
                    ),
                    loading: () => const SocialLoadingState(label: 'Carregando feed...'),
                  ),
                ],
              );
            }

            return communitiesState.when(
              data: (result) => SocialCommunitiesArea(
                result: result,
                searchController: _communitySearchController,
                visibilityFilter: _communityVisibilityFilter,
                categoryFilter: _communityCategoryFilter,
                membershipFilter: _communityMembershipFilter,
                categories: categories,
                onSearchChanged: (_) => _applyCommunityFilters(),
                onVisibilityChanged: (value) {
                  setState(() => _communityVisibilityFilter = value);
                  _applyCommunityFilters();
                },
                onCategoryChanged: (value) {
                  setState(() => _communityCategoryFilter = value);
                  _applyCommunityFilters();
                },
                onMembershipChanged: (value) {
                  setState(() => _communityMembershipFilter = value);
                  _applyCommunityFilters();
                },
                onPageChanged: (page) =>
                    ref.read(communityControllerProvider.notifier).goToPage(page),
                onJoin: (community) async {
                  await ref.read(communityControllerProvider.notifier).join(community.id);
                  if (mounted) {
                    AppSnackBar.show(
                      this.context,
                      message: 'Voce entrou em ${community.name}.',
                      icon: Icons.check_circle_outline_rounded,
                    );
                  }
                },
                onLeave: (community) async {
                  await ref.read(communityControllerProvider.notifier).leave(community.id);
                  if (mounted) {
                    AppSnackBar.show(
                      this.context,
                      message: 'Voce saiu de ${community.name}.',
                      icon: Icons.logout_rounded,
                    );
                  }
                },
                onCreate: _openCreateCommunityModal,
              ),
              error: (error, stackTrace) => SocialActionableErrorState(
                title: 'Nao conseguimos abrir as comunidades agora.',
                onRetry: () => ref.read(communityControllerProvider.notifier).refresh(),
              ),
              loading: () => const SocialLoadingState(label: 'Carregando comunidades...'),
            );
          },
        ),
      ],
    );
  }
}

class _CreateCommunitySheet extends StatefulWidget {
  const _CreateCommunitySheet({
    required this.formKey,
    required this.nameController,
    required this.descriptionController,
    required this.initialVisibility,
    required this.initialCategory,
    required this.slugify,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String initialVisibility;
  final String initialCategory;
  final String Function(String value) slugify;
  final Future<void> Function(
    String name,
    String slug,
    String description,
    String visibility,
    String category,
  ) onSubmit;

  @override
  State<_CreateCommunitySheet> createState() => _CreateCommunitySheetState();
}

class _CreateCommunitySheetState extends State<_CreateCommunitySheet> {
  late String _visibility = widget.initialVisibility;
  late String _category = widget.initialCategory;

  @override
  Widget build(BuildContext context) {
    final slugPreview = widget.slugify(widget.nameController.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: widget.formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Criar nova comunidade',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Defina um nome claro, uma descricao curta e a visibilidade desse grupo.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: widget.nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da comunidade',
                  prefixIcon: Icon(Icons.groups_rounded),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) =>
                    value == null || value.trim().length < 3 ? 'Use pelo menos 3 caracteres.' : null,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: AppColors.surfaceStrong.withValues(alpha: 0.55),
                ),
                child: Text(
                  'Slug: $slugPreview',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: widget.descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descricao',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                validator: (value) => value == null || value.trim().length < 12
                    ? 'Descreva em pelo menos 12 caracteres.'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: const [
                  DropdownMenuItem(value: 'acolhimento', child: Text('Acolhimento')),
                  DropdownMenuItem(value: 'emocional', child: Text('Emocional')),
                  DropdownMenuItem(value: 'bem-estar', child: Text('Bem-estar')),
                  DropdownMenuItem(value: 'habitos', child: Text('Habitos')),
                  DropdownMenuItem(value: 'presenca', child: Text('Presenca')),
                  DropdownMenuItem(value: 'reflexao', child: Text('Reflexao')),
                  DropdownMenuItem(value: 'foco', child: Text('Foco')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: 'Visibilidade'),
                items: const [
                  DropdownMenuItem(value: 'PUBLIC', child: Text('Publica')),
                  DropdownMenuItem(value: 'PRIVATE', child: Text('Privada')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _visibility = value);
                  }
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (!widget.formKey.currentState!.validate()) {
                          return;
                        }

                        await widget.onSubmit(
                          widget.nameController.text.trim(),
                          slugPreview,
                          widget.descriptionController.text.trim(),
                          _visibility,
                          _category,
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Criar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
