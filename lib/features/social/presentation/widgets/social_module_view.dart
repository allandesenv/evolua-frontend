import 'dart:async';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/application/social_feed_state.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_communities_area.dart';
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
    this.onInternalBackChanged,
  });

  final SocialModuleTab initialTab;
  final bool showTabs;
  final SocialFeedScope feedScope;
  final SocialCommunityScope communityScope;
  final bool showScopeChips;
  final ValueChanged<SocialModuleTab>? onTabChanged;
  final VoidCallback? onOpenFutureMessages;
  final ValueChanged<VoidCallback?>? onInternalBackChanged;

  @override
  ConsumerState<SocialModuleView> createState() => _SocialModuleViewState();
}

class _SocialModuleViewState extends ConsumerState<SocialModuleView> {
  final _communitySearchController = TextEditingController();
  final _communityPostFormKey = GlobalKey<FormState>();
  final _communityPostContentController = TextEditingController();

  String _communityVisibilityFilter = 'TODAS';
  String _communityCategoryFilter = 'TODAS';
  String _communityMembershipFilter = 'TODAS';
  String _communityPostVisibility = 'PUBLIC';
  Community? _selectedCommunity;
  String? _joiningCommunityId;

  @override
  void initState() {
    super.initState();
    widget.onInternalBackChanged?.call(null);

    ref.listenManual(socialPostControllerProvider, (previous, next) {
      if (next.hasError) {
        _showError(
          next.error,
          fallback: 'Não foi possível atualizar as reflexões.',
        );
      }
    });

    ref.listenManual(communityControllerProvider, (previous, next) {
      if (next.hasError) {
        _showError(
          next.error,
          fallback: 'Não foi possível atualizar os espaços.',
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyCommunityFilters();
    });
  }

  @override
  void dispose() {
    _communitySearchController.dispose();
    _communityPostContentController.dispose();
    super.dispose();
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

  Future<void> _openCommunityDetail(Community community) async {
    setState(() {
      _selectedCommunity = community;
      _communityPostContentController.clear();
      _communityPostVisibility = 'PUBLIC';
    });
    widget.onInternalBackChanged?.call(
      () => unawaited(_closeCommunityDetail()),
    );
    await ref
        .read(socialPostControllerProvider.notifier)
        .applyFilters(community: community.slug, visibility: null, mine: null);
  }

  Future<void> _closeCommunityDetail() async {
    widget.onInternalBackChanged?.call(null);
    setState(() => _selectedCommunity = null);
    await _applyCommunityFilters();
  }

  Future<void> _openCommunityPostSheet() async {
    _communityPostVisibility = 'PUBLIC';
    _communityPostContentController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return _CommunityReflectionSheet(
          formKey: _communityPostFormKey,
          contentController: _communityPostContentController,
          initialVisibility: _communityPostVisibility,
          title: 'Escrever reflexão',
          subtitle: 'Compartilhe um registro curto no espaço atual.',
          submitLabel: 'Compartilhar reflexão',
          showVisibility: true,
          disposeContentController: false,
          onSubmit: (visibility) async {
            _communityPostVisibility = visibility;
            final success = await _submitCommunityPost();
            if (success && sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
        );
      },
    );
  }

  Future<bool> _submitCommunityPost() async {
    final community = _selectedCommunity;
    if (community == null || !_communityPostFormKey.currentState!.validate()) {
      return false;
    }

    final createdPost = await ref
        .read(socialPostControllerProvider.notifier)
        .create(
          content: _communityPostContentController.text.trim(),
          community: community.slug,
          visibility: _communityPostVisibility,
        );

    if (!mounted || ref.read(socialPostControllerProvider).hasError) {
      return false;
    }

    _communityPostContentController.clear();
    AppSnackBar.show(
      context,
      message: 'Reflexão publicada em ${community.name}.',
      icon: Icons.check_circle_outline_rounded,
      actionLabel: createdPost == null ? null : 'Desfazer',
      onAction: createdPost == null
          ? null
          : () => unawaited(_undoCreatedPost(createdPost)),
    );
    return true;
  }

  Future<void> _openEditCommunityPostSheet(SocialPost post) async {
    final formKey = GlobalKey<FormState>();
    final contentController = TextEditingController(text: post.content);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) {
          return _CommunityReflectionSheet(
            formKey: formKey,
            contentController: contentController,
            initialVisibility: post.visibility,
            title: 'Editar reflexão',
            subtitle: 'Ajuste o texto que você compartilhou neste espaço.',
            submitLabel: 'Salvar atualização',
            showVisibility: false,
            disposeContentController: true,
            onSubmit: (_) async {
              await ref
                  .read(socialPostControllerProvider.notifier)
                  .updatePost(
                    id: post.id,
                    content: contentController.text.trim(),
                  );
              if (!mounted || !sheetContext.mounted) {
                return;
              }
              Navigator.of(sheetContext).pop();
              AppSnackBar.show(
                context,
                message: 'Reflexão atualizada.',
                icon: Icons.check_circle_outline_rounded,
              );
            },
          );
        },
      );
    } catch (error) {
      if (mounted) {
        _showError(
          error,
          fallback: 'Não foi possível atualizar esta reflexão agora.',
        );
      }
    }
  }

  Future<void> _confirmDeleteCommunityPost(SocialPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir reflexão?'),
          content: const Text(
            'Tem certeza que deseja excluir esta reflexão? Essa ação não poderá ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteCommunityPost(post, successMessage: 'Reflexão excluída.');
    }
  }

  Future<void> _undoCreatedPost(SocialPost post) {
    return _deleteCommunityPost(
      post,
      successMessage: 'Compartilhamento desfeito.',
      fallback: 'Não foi possível desfazer o compartilhamento agora.',
    );
  }

  Future<void> _deleteCommunityPost(
    SocialPost post, {
    required String successMessage,
    String fallback = 'Não foi possível excluir esta reflexão agora.',
  }) async {
    try {
      await ref.read(socialPostControllerProvider.notifier).deletePost(post.id);
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: successMessage,
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (error) {
      if (mounted) {
        _showError(error, fallback: fallback);
      }
    }
  }

  Future<void> _leaveSelectedCommunity() async {
    final community = _selectedCommunity;
    if (community == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sair do espaço?'),
          content: Text(
            'Você deixará de participar de ${community.name}, mas poderá entrar novamente depois.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(communityControllerProvider.notifier).leave(community.id);
    if (!mounted) {
      return;
    }
    AppSnackBar.show(
      context,
      message: 'Você saiu de ${community.name}.',
      icon: Icons.logout_rounded,
    );
    await _closeCommunityDetail();
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
                  AppSnackBar.show(
                    this.context,
                    message: 'Espaço criado com sucesso.',
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

  Future<void> _joinCommunity(Community community) async {
    if (_joiningCommunityId != null) {
      return;
    }

    setState(() => _joiningCommunityId = community.id);
    try {
      final joinedCommunity = await ref
          .read(communityControllerProvider.notifier)
          .join(community.id);
      if (!mounted) {
        return;
      }

      final state = ref.read(communityControllerProvider);
      if (state.hasError) {
        return;
      }

      AppSnackBar.show(
        context,
        message: 'Você entrou em ${community.name}.',
        icon: Icons.check_circle_outline_rounded,
      );
      await _openCommunityDetail(joinedCommunity);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message:
              'Não foi possível entrar neste espaço agora. Tente novamente.',
          icon: Icons.info_outline_rounded,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _joiningCommunityId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(socialPostControllerProvider);
    final communitiesState = ref.watch(communityControllerProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final canCreateCommunity = session?.isAdmin ?? false;
    final communityCatalog = communitiesState.asData?.value;
    final communityResult = communityCatalog?.result;
    final categories = <String>{
      'TODAS',
      ...?communityResult?.items.map((item) => item.category),
    }.toList();

    final selectedCommunity = _selectedCommunity;
    if (selectedCommunity != null) {
      return _CommunityDetailView(
        community: selectedCommunity,
        postsState: postsState,
        currentUserId: session?.userId,
        onBack: _closeCommunityDetail,
        onWriteReflection: postsState.isLoading && !postsState.hasValue
            ? null
            : _openCommunityPostSheet,
        onEditPost: _openEditCommunityPostSheet,
        onDeletePost: _confirmDeleteCommunityPost,
        onLeave: _leaveSelectedCommunity,
        onRefresh: () => ref
            .read(socialPostControllerProvider.notifier)
            .applyFilters(community: selectedCommunity.slug),
        onPageChanged: (page) =>
            ref.read(socialPostControllerProvider.notifier).goToPage(page),
      );
    }

    final loadingWithoutData =
        communitiesState.isLoading && communityCatalog == null;
    if (communityCatalog != null || loadingWithoutData) {
      return SocialCommunitiesArea(
        result:
            communityResult ??
            PaginatedResponse.empty(
              page: 0,
              size: CommunityController.pageSize,
            ),
        isInitialLoading: loadingWithoutData,
        isRefreshing: communityCatalog?.isRefreshing ?? false,
        isLoadingMore: communityCatalog?.isLoadingMore ?? false,
        isFromCache: communityCatalog?.isFromCache ?? false,
        loadMoreError: communityCatalog?.loadMoreError,
        refreshError: communityCatalog?.refreshError,
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
        onLoadMore: () =>
            ref.read(communityControllerProvider.notifier).loadNextPage(),
        onRetryLoadMore: () =>
            ref.read(communityControllerProvider.notifier).retryLoadMore(),
        onView: _openCommunityDetail,
        joiningCommunityId: _joiningCommunityId,
        onJoin: _joinCommunity,
        canCreate: canCreateCommunity,
        onCreate: _openCreateCommunityModal,
        headline: 'Espaços',
        description:
            'Encontre ambientes de troca para entrar, ler e compartilhar reflexões com mais contexto.',
        onRefresh: () =>
            ref.read(communityControllerProvider.notifier).refresh(),
      );
    }
    return SocialActionableErrorState(
      title: 'Não conseguimos abrir os espaços agora.',
      onRetry: () => ref.read(communityControllerProvider.notifier).refresh(),
    );
  }
}

class _CommunityDetailView extends StatelessWidget {
  const _CommunityDetailView({
    required this.community,
    required this.postsState,
    required this.currentUserId,
    required this.onBack,
    required this.onWriteReflection,
    required this.onEditPost,
    required this.onDeletePost,
    required this.onLeave,
    required this.onRefresh,
    required this.onPageChanged,
  });

  final Community community;
  final AsyncValue<SocialFeedState> postsState;
  final String? currentUserId;
  final VoidCallback onBack;
  final VoidCallback? onWriteReflection;
  final ValueChanged<SocialPost> onEditPost;
  final ValueChanged<SocialPost> onDeletePost;
  final VoidCallback onLeave;
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
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onWriteReflection,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Escrever reflexão'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onLeave,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sair do espaço'),
                  ),
                ],
              ),
            ],
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
                              SocialMetaPill(
                                label: post.visibility == 'PUBLIC'
                                    ? 'Aberta'
                                    : 'Privada',
                              ),
                              if (post.userId == currentUserId) ...[
                                const Spacer(),
                                PopupMenuButton<String>(
                                  tooltip: 'Opções da reflexão',
                                  icon: const Icon(Icons.more_horiz_rounded),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      onEditPost(post);
                                    } else if (value == 'delete') {
                                      onDeletePost(post);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Excluir'),
                                    ),
                                  ],
                                ),
                              ],
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

class _CommunityReflectionSheet extends StatefulWidget {
  const _CommunityReflectionSheet({
    required this.formKey,
    required this.contentController,
    required this.initialVisibility,
    required this.title,
    required this.subtitle,
    required this.submitLabel,
    required this.showVisibility,
    required this.disposeContentController,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController contentController;
  final String initialVisibility;
  final String title;
  final String subtitle;
  final String submitLabel;
  final bool showVisibility;
  final bool disposeContentController;
  final Future<void> Function(String visibility) onSubmit;

  @override
  State<_CommunityReflectionSheet> createState() =>
      _CommunityReflectionSheetState();
}

class _CommunityReflectionSheetState extends State<_CommunityReflectionSheet> {
  late String _visibility = widget.initialVisibility;
  bool _submitting = false;

  @override
  void dispose() {
    if (widget.disposeContentController) {
      widget.contentController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
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
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: widget.contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Sua reflexão',
                    hintText: 'Hoje percebi que...',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escreva sua reflexão.'
                      : null,
                ),
                if (widget.showVisibility) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _visibility,
                    decoration: const InputDecoration(
                      labelText: 'Visibilidade',
                      prefixIcon: Icon(Icons.visibility_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'PUBLIC', child: Text('Aberta')),
                      DropdownMenuItem(
                        value: 'PRIVATE',
                        child: Text('Privada'),
                      ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _visibility = value);
                            }
                          },
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting
                        ? null
                        : () async {
                            if (!widget.formKey.currentState!.validate()) {
                              return;
                            }
                            setState(() => _submitting = true);
                            try {
                              await widget.onSubmit(_visibility);
                            } finally {
                              if (mounted) {
                                setState(() => _submitting = false);
                              }
                            }
                          },
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(widget.submitLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                'Criar novo espaço',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Defina um nome claro, uma descrição curta e a abertura desse espaço.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: widget.nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do espaço',
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
                  labelText: 'Descrição do espaço',
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
                  DropdownMenuItem(value: 'habitos', child: Text('Hábitos')),
                  DropdownMenuItem(value: 'presenca', child: Text('Presença')),
                  DropdownMenuItem(value: 'reflexao', child: Text('Reflexão')),
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
                  DropdownMenuItem(value: 'PUBLIC', child: Text('Aberto')),
                  DropdownMenuItem(value: 'PRIVATE', child: Text('Privado')),
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
