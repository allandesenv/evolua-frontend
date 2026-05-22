import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/application/social_feed_state.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_communities_area.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_feed_area.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_post_composer.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_shared_widgets.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SocialModuleTab { featured, reflections, mySpaces }

enum SocialFeedScope { moment, mine }

enum SocialCommunityScope { explore, mine }

class SocialModuleView extends ConsumerStatefulWidget {
  const SocialModuleView({
    super.key,
    this.initialTab = SocialModuleTab.featured,
    this.showTabs = true,
    this.feedScope = SocialFeedScope.moment,
    this.communityScope = SocialCommunityScope.explore,
    this.showScopeChips = true,
    this.onTabChanged,
    this.onOpenFutureMessages,
  });

  final SocialModuleTab initialTab;
  final bool showTabs;
  final SocialFeedScope feedScope;
  final SocialCommunityScope communityScope;
  final bool showScopeChips;
  final ValueChanged<SocialModuleTab>? onTabChanged;
  final VoidCallback? onOpenFutureMessages;

  @override
  ConsumerState<SocialModuleView> createState() => _SocialModuleViewState();
}

class _SocialModuleViewState extends ConsumerState<SocialModuleView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _postFormKey = GlobalKey<FormState>();
  final _communityPostFormKey = GlobalKey<FormState>();
  final _postContentController = TextEditingController();
  final _communityPostContentController = TextEditingController();
  final _feedSearchController = TextEditingController();
  final _communitySearchController = TextEditingController();
  String _postVisibility = 'PUBLIC';
  String _communityPostVisibility = 'PUBLIC';
  String _feedVisibilityFilter = 'TODAS';
  String _feedCommunityFilter = 'TODAS';
  String _communityVisibilityFilter = 'TODAS';
  String _communityCategoryFilter = 'TODAS';
  String _communityMembershipFilter = 'TODAS';
  String? _postCommunitySlug;
  Community? _selectedCommunity;
  late SocialFeedScope _feedScope;
  late SocialCommunityScope _communityScope;

  @override
  void initState() {
    super.initState();
    _feedScope = widget.feedScope;
    _communityScope = widget.communityScope;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = _indexForTab(widget.initialTab);
    _tabController.addListener(_handleTabChanged);

    ref.listenManual(socialPostControllerProvider, (previous, next) {
      if (next.hasError) {
        _showError(
          next.error,
          fallback: 'Nao foi possivel atualizar as reflexoes.',
        );
      }
    });

    ref.listenManual(communityControllerProvider, (previous, next) {
      if (next.hasError) {
        _showError(
          next.error,
          fallback: 'Nao foi possivel atualizar os espacos.',
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScopes(force: true);
    });
  }

  @override
  void didUpdateWidget(covariant SocialModuleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedScope != widget.feedScope ||
        oldWidget.communityScope != widget.communityScope ||
        oldWidget.initialTab != widget.initialTab) {
      _feedScope = widget.feedScope;
      _communityScope = widget.communityScope;
      _tabController.index = _indexForTab(widget.initialTab);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncScopes(force: true);
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _postContentController.dispose();
    _communityPostContentController.dispose();
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
        message: 'Escolha um espaco para compartilhar sua reflexao.',
        icon: Icons.groups_rounded,
      );
      return;
    }

    await ref
        .read(socialPostControllerProvider.notifier)
        .create(
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
      message: 'Reflexao publicada com sucesso.',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  Future<void> _submitCommunityPost() async {
    final community = _selectedCommunity;
    if (community == null || !_communityPostFormKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(socialPostControllerProvider.notifier)
        .create(
          content: _communityPostContentController.text.trim(),
          community: community.slug,
          visibility: _communityPostVisibility,
        );

    if (!mounted) {
      return;
    }

    _communityPostContentController.clear();
    AppSnackBar.show(
      context,
      message: 'Reflexão publicada em ${community.name}.',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  Future<void> _openCommunityDetail(Community community) async {
    setState(() {
      _selectedCommunity = community;
      _communityPostVisibility = 'PUBLIC';
      _communityPostContentController.clear();
    });
    await ref
        .read(socialPostControllerProvider.notifier)
        .applyFilters(community: community.slug, visibility: null, mine: null);
  }

  Future<void> _closeCommunityDetail() async {
    setState(() => _selectedCommunity = null);
    await _syncScopes(force: true);
  }

  Future<void> _applyFeedFilters() {
    return ref
        .read(socialPostControllerProvider.notifier)
        .applyFilters(
          search: _feedSearchController.text.trim().isEmpty
              ? null
              : _feedSearchController.text.trim(),
          community: _feedCommunityFilter == 'TODAS'
              ? null
              : _feedCommunityFilter,
          visibility: _feedVisibilityFilter == 'TODAS'
              ? null
              : _feedVisibilityFilter,
          mine: _feedScope == SocialFeedScope.mine,
        );
  }

  Future<void> _applyCommunityFilters() {
    return ref
        .read(communityControllerProvider.notifier)
        .applyFilters(
          search: _communitySearchController.text.trim().isEmpty
              ? null
              : _communitySearchController.text.trim(),
          visibility: _communityVisibilityFilter == 'TODAS'
              ? null
              : _communityVisibilityFilter,
          category: _communityCategoryFilter == 'TODAS'
              ? null
              : _communityCategoryFilter,
          joined: switch (_communityMembershipFilter) {
            'INGRESSADAS' => true,
            'DESCOBRIR' => false,
            _ => null,
          },
        );
  }

  Future<void> _syncScopes({bool force = false}) async {
    final currentTab = _tabForIndex(_tabController.index);
    if (currentTab == SocialModuleTab.reflections) {
      if (force) {
        await _applyFeedFilters();
      }
      return;
    }

    if (currentTab == SocialModuleTab.mySpaces ||
        _communityScope == SocialCommunityScope.mine) {
      _communityMembershipFilter = 'INGRESSADAS';
    } else if (force || _communityMembershipFilter == 'INGRESSADAS') {
      _communityMembershipFilter = 'TODAS';
    }
    await _applyCommunityFilters();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }

    final tab = _tabForIndex(_tabController.index);
    widget.onTabChanged?.call(tab);
    _syncScopes(force: true);
  }

  int _indexForTab(SocialModuleTab tab) {
    return switch (tab) {
      SocialModuleTab.featured => 0,
      SocialModuleTab.reflections => 1,
      SocialModuleTab.mySpaces => 2,
    };
  }

  SocialModuleTab _tabForIndex(int index) {
    return switch (index) {
      1 => SocialModuleTab.reflections,
      2 => SocialModuleTab.mySpaces,
      _ => SocialModuleTab.featured,
    };
  }

  void _selectTab(SocialModuleTab tab) {
    final index = _indexForTab(tab);
    if (_tabController.index == index) {
      return;
    }
    _tabController.animateTo(index);
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
            onSubmit:
                (name, slug, description, nextVisibility, nextCategory) async {
                  visibility = nextVisibility;
                  category = nextCategory;
                  await ref
                      .read(communityControllerProvider.notifier)
                      .create(
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
                  _tabController.animateTo(0);
                  AppSnackBar.show(
                    this.context,
                    message: 'Espaco criado com sucesso.',
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
              ? ((error.response?.data['details'] as List?)?.join(', ') ??
                    error.message ??
                    fallback)
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
    return slug.isEmpty ? 'novo-espaco' : slug;
  }

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(socialPostControllerProvider);
    final communitiesState = ref.watch(communityControllerProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final canCreateCommunity = session?.isAdmin ?? false;
    final latestCheckIn = ref
        .watch(checkInControllerProvider)
        .asData
        ?.value
        .latestCreatedCheckIn;
    final contextualHint = _contextualHint(latestCheckIn?.mood);
    final joinedCommunities =
        communitiesState.asData?.value.items
            .where((item) => item.joined)
            .toList() ??
        const <Community>[];
    final allCommunities =
        communitiesState.asData?.value.items ?? const <Community>[];

    _postCommunitySlug ??= joinedCommunities.isNotEmpty
        ? joinedCommunities.first.slug
        : null;

    final communityFilterOptions = <String>{
      'TODAS',
      ...allCommunities.map((item) => item.slug),
    }.toList();
    final categories = <String>{
      'TODAS',
      ...allCommunities.map((item) => item.category),
    }.toList();
    final postsCount = postsState.asData?.value.result.totalItems ?? 0;

    final selectedCommunity = _selectedCommunity;
    if (selectedCommunity != null) {
      return _CommunityDetailView(
        community: selectedCommunity,
        postsState: postsState,
        formKey: _communityPostFormKey,
        contentController: _communityPostContentController,
        visibility: _communityPostVisibility,
        onVisibilityChanged: (value) =>
            setState(() => _communityPostVisibility = value),
        onSubmit: postsState.isLoading && !postsState.hasValue
            ? null
            : _submitCommunityPost,
        onBack: _closeCommunityDetail,
        onRefresh: () => ref
            .read(socialPostControllerProvider.notifier)
            .applyFilters(community: selectedCommunity.slug),
        onPageChanged: (page) =>
            ref.read(socialPostControllerProvider.notifier).goToPage(page),
      );
    }

    return Column(
      children: [
        if (widget.showTabs)
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              return _SocialModuleHeader(
                selected: _tabForIndex(_tabController.index),
                spacesCount: communitiesState.asData?.value.totalItems ?? 0,
                joinedCount: joinedCommunities.length,
                reflectionsCount: postsCount,
                onSelected: _selectTab,
              );
            },
          ),
        if (widget.showTabs) const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final currentTab = _tabForIndex(_tabController.index);
            if (currentTab == SocialModuleTab.reflections) {
              return Column(
                children: [
                  _FutureMessageReflectionCard(
                    onOpen: widget.onOpenFutureMessages,
                  ),
                  const SizedBox(height: 16),
                  SocialPostComposer(
                    formKey: _postFormKey,
                    contentController: _postContentController,
                    visibility: _postVisibility,
                    selectedCommunitySlug: _postCommunitySlug,
                    joinedCommunities: joinedCommunities,
                    onVisibilityChanged: (value) =>
                        setState(() => _postVisibility = value),
                    onCommunityChanged: (value) =>
                        setState(() => _postCommunitySlug = value),
                    onSubmit: postsState.isLoading && !postsState.hasValue
                        ? null
                        : _submitPost,
                  ),
                  const SizedBox(height: 16),
                  postsState.when(
                    data: (feedState) => SocialFeedArea(
                      result: feedState.result,
                      isFromCache: feedState.isFromCache,
                      offlineMessage: feedState.offlineMessage,
                      searchController: _feedSearchController,
                      visibilityFilter: _feedVisibilityFilter,
                      communityFilter: _feedCommunityFilter,
                      communityOptions: communityFilterOptions,
                      contextualHint: _feedScope == SocialFeedScope.mine
                          ? 'Revise o que voce mesmo compartilhou, encontre padroes no seu jeito de refletir e recupere aprendizados que ainda fazem sentido.'
                          : contextualHint,
                      sectionLabel: _feedScope == SocialFeedScope.mine
                          ? 'Minhas reflexoes'
                          : 'Reflexoes do momento',
                      showScopeChips: true,
                      currentScope: _feedScope.name,
                      onMomentSelected: () async {
                        setState(() => _feedScope = SocialFeedScope.moment);
                        await _applyFeedFilters();
                      },
                      onMineSelected: () async {
                        setState(() => _feedScope = SocialFeedScope.mine);
                        await _applyFeedFilters();
                      },
                      onRefresh: () => ref
                          .read(socialPostControllerProvider.notifier)
                          .refresh(),
                      onSearchChanged: (_) => _applyFeedFilters(),
                      onVisibilityFilterChanged: (value) {
                        setState(() => _feedVisibilityFilter = value);
                        _applyFeedFilters();
                      },
                      onCommunityFilterChanged: (value) {
                        setState(() => _feedCommunityFilter = value);
                        _applyFeedFilters();
                      },
                      onPageChanged: (page) => ref
                          .read(socialPostControllerProvider.notifier)
                          .goToPage(page),
                    ),
                    error: (error, stackTrace) => SocialActionableErrorState(
                      title: 'Nao conseguimos abrir as reflexoes agora.',
                      onRetry: () => ref
                          .read(socialPostControllerProvider.notifier)
                          .refresh(),
                    ),
                    loading: () => const SocialLoadingState(
                      label: 'Carregando reflexoes...',
                    ),
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
                onPageChanged: (page) => ref
                    .read(communityControllerProvider.notifier)
                    .goToPage(page),
                onView: _openCommunityDetail,
                onJoin: (community) async {
                  await ref
                      .read(communityControllerProvider.notifier)
                      .join(community.id);
                  if (mounted) {
                    AppSnackBar.show(
                      this.context,
                      message: 'Voce entrou em ${community.name}.',
                      icon: Icons.check_circle_outline_rounded,
                    );
                  }
                },
                onLeave: (community) async {
                  await ref
                      .read(communityControllerProvider.notifier)
                      .leave(community.id);
                  if (mounted) {
                    AppSnackBar.show(
                      this.context,
                      message: 'Voce saiu de ${community.name}.',
                      icon: Icons.logout_rounded,
                    );
                  }
                },
                canCreate: canCreateCommunity,
                onCreate: _openCreateCommunityModal,
                headline:
                    currentTab == SocialModuleTab.mySpaces ||
                        _communityScope == SocialCommunityScope.mine
                    ? 'Meus espacos'
                    : 'Espacos em destaque',
                description:
                    currentTab == SocialModuleTab.mySpaces ||
                        _communityScope == SocialCommunityScope.mine
                    ? 'Acompanhe os ambientes em que voce ja entrou e retome as reflexoes desse contexto.'
                    : 'Explore ambientes de troca antes de compartilhar uma reflexao. Cada espaco organiza pessoas, temas e conversas com mais contexto.',
                showMembershipFilter: currentTab != SocialModuleTab.mySpaces,
                showScopeChips: widget.showScopeChips,
                currentScope: currentTab == SocialModuleTab.mySpaces
                    ? SocialCommunityScope.mine.name
                    : _communityScope.name,
                onExploreSelected: () async {
                  setState(
                    () => _communityScope = SocialCommunityScope.explore,
                  );
                  await _syncScopes(force: true);
                },
                onMineSelected: () async {
                  setState(() => _communityScope = SocialCommunityScope.mine);
                  await _syncScopes(force: true);
                },
                onRefresh: () =>
                    ref.read(communityControllerProvider.notifier).refresh(),
              ),
              error: (error, stackTrace) => SocialActionableErrorState(
                title: 'Nao conseguimos abrir os espacos agora.',
                onRetry: () =>
                    ref.read(communityControllerProvider.notifier).refresh(),
              ),
              loading: () =>
                  const SocialLoadingState(label: 'Carregando espacos...'),
            );
          },
        ),
      ],
    );
  }

  String _contextualHint(String? mood) {
    final normalized = mood?.toLowerCase() ?? '';
    if (normalized.contains('ans')) {
      return 'Seu momento recente pede mais regulacao. Estas reflexoes priorizam ansiedade, acolhimento e pequenas praticas aplicaveis agora.';
    }
    if (normalized.contains('cans')) {
      return 'Seu momento recente pede mais leveza. Estas reflexoes puxam recuperacao, ritmo sustentavel e menos cobranca.';
    }
    if (normalized.contains('calm') || normalized.contains('presen')) {
      return 'Seu momento recente abre espaco para clareza. Estas reflexoes priorizam presenca, constancia e aplicacao pratica.';
    }
    return 'Leia reflexoes curtas, aprendizados e relatos leves sem entrar no ritmo de uma rede social.';
  }
}

class _CommunityDetailView extends StatelessWidget {
  const _CommunityDetailView({
    required this.community,
    required this.postsState,
    required this.formKey,
    required this.contentController,
    required this.visibility,
    required this.onVisibilityChanged,
    required this.onSubmit,
    required this.onBack,
    required this.onRefresh,
    required this.onPageChanged,
  });

  final Community community;
  final AsyncValue<SocialFeedState> postsState;
  final GlobalKey<FormState> formKey;
  final TextEditingController contentController;
  final String visibility;
  final ValueChanged<String> onVisibilityChanged;
  final VoidCallback? onSubmit;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Voltar',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.accent,
                style: IconButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.36),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.accent.withValues(alpha: 0.14),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          community.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          community.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SocialMetaPill(label: community.category),
                            SocialMetaPill(
                              label: '${community.memberCount} pessoas',
                            ),
                            const SocialMetaPill(label: 'Participando'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryPanel(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Criar reflexão neste espaço',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Compartilhe um registro curto conectado ao tema deste espaço.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Sua reflexão',
                    hintText: 'Escreva com calma, no seu ritmo.',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escreva sua reflexão.'
                      : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: visibility,
                  decoration: const InputDecoration(
                    labelText: 'Visibilidade',
                    prefixIcon: Icon(Icons.visibility_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PUBLIC', child: Text('Pública')),
                    DropdownMenuItem(value: 'PRIVATE', child: Text('Privada')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onVisibilityChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Publicar reflexão'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        postsState.when(
          data: (feedState) {
            final result = feedState.result;
            if (result.items.isEmpty) {
              return GuidedEmptyState(
                icon: Icons.forum_rounded,
                title: 'Nenhuma reflexão ainda',
                subtitle:
                    'Quando alguém compartilhar uma reflexão neste espaço, ela aparecerá aqui.',
                actionLabel: 'Atualizar',
                onAction: onRefresh,
              );
            }
            return Column(
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
                              const Icon(
                                Icons.format_quote_rounded,
                                color: AppColors.accentWarm,
                              ),
                              const SizedBox(width: 8),
                              SocialMetaPill(label: post.visibility),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            post.content,
                            style: Theme.of(context).textTheme.bodyLarge,
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
            );
          },
          error: (_, _) => SocialActionableErrorState(
            title: 'Não conseguimos abrir as reflexões deste espaço agora.',
            onRetry: onRefresh,
          ),
          loading: () =>
              const SocialLoadingState(label: 'Carregando reflexões...'),
        ),
      ],
    );
  }
}

class _SocialModuleHeader extends StatelessWidget {
  const _SocialModuleHeader({
    required this.selected,
    required this.spacesCount,
    required this.joinedCount,
    required this.reflectionsCount,
    required this.onSelected,
  });

  final SocialModuleTab selected;
  final int spacesCount;
  final int joinedCount;
  final int reflectionsCount;
  final ValueChanged<SocialModuleTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: 'Alternar area de espacos',
      child: Column(
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
                  color: AppColors.accent.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: AppColors.accent,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Espacos',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ambientes de troca, reflexao e pertencimento para entrar com contexto e sair com clareza.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SocialMetricPill(
                icon: Icons.explore_rounded,
                label: '$spacesCount espacos',
              ),
              _SocialMetricPill(
                icon: Icons.check_circle_rounded,
                label: '$joinedCount participando',
              ),
              _SocialMetricPill(
                icon: Icons.edit_note_rounded,
                label: '$reflectionsCount reflexoes',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SocialSectionSwitcher(selected: selected, onSelected: onSelected),
        ],
      ),
    );
  }
}

class _SocialSectionSwitcher extends StatelessWidget {
  const _SocialSectionSwitcher({
    required this.selected,
    required this.onSelected,
  });

  final SocialModuleTab selected;
  final ValueChanged<SocialModuleTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.surfaceStrong.withValues(alpha: 0.34),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(minHeight: 58),
      child: Row(
        children: [
          Expanded(
            child: _SocialSectionButton(
              icon: Icons.auto_awesome_rounded,
              label: 'Em destaque',
              selected: selected == SocialModuleTab.featured,
              onTap: () => onSelected(SocialModuleTab.featured),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SocialSectionButton(
              icon: Icons.edit_note_rounded,
              label: 'Reflexoes',
              selected: selected == SocialModuleTab.reflections,
              onTap: () => onSelected(SocialModuleTab.reflections),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SocialSectionButton(
              icon: Icons.groups_2_rounded,
              label: 'Meus',
              selected: selected == SocialModuleTab.mySpaces,
              onTap: () => onSelected(SocialModuleTab.mySpaces),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialSectionButton extends StatelessWidget {
  const _SocialSectionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.background : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : AppColors.outline.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialMetricPill extends StatelessWidget {
  const _SocialMetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.surfaceStrong.withValues(alpha: 0.48),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FutureMessageReflectionCard extends StatelessWidget {
  const _FutureMessageReflectionCard({required this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.accent.withValues(alpha: 0.14),
            ),
            child: const Icon(
              Icons.forward_to_inbox_rounded,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mensagens para o futuro',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Abra sua tela privada de cartas: escreva para o futuro e leia quando uma versao sua voltar no momento certo.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Abrir mensagens'),
                ),
              ],
            ),
          ),
        ],
      ),
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
  )
  onSubmit;

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
                'Criar novo espaco',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Defina um nome claro, uma descricao curta e a abertura desse espaco.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: widget.nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do espaco',
                  prefixIcon: Icon(Icons.groups_rounded),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) => value == null || value.trim().length < 3
                    ? 'Use pelo menos 3 caracteres.'
                    : null,
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
                  labelText: 'Descricao do espaco',
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
                  DropdownMenuItem(
                    value: 'acolhimento',
                    child: Text('Acolhimento'),
                  ),
                  DropdownMenuItem(
                    value: 'emocional',
                    child: Text('Emocional'),
                  ),
                  DropdownMenuItem(
                    value: 'bem-estar',
                    child: Text('Bem-estar'),
                  ),
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
