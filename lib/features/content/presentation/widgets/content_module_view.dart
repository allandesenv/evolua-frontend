import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/panel_skeleton.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum ContentModuleSection { journey, catalog }

class ContentModuleView extends ConsumerStatefulWidget {
  const ContentModuleView({
    super.key,
    this.section = ContentModuleSection.journey,
    this.showSectionChips = true,
    this.onOpenMentor,
  });

  final ContentModuleSection section;
  final bool showSectionChips;
  final VoidCallback? onOpenMentor;

  @override
  ConsumerState<ContentModuleView> createState() => _ContentModuleViewState();
}

class _ContentModuleViewState extends ConsumerState<ContentModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController(text: 'ansiedade');
  final _searchController = TextEditingController();
  final List<_EditableMediaLink> _mediaLinks = [_EditableMediaLink.live()];
  bool _premium = false;
  bool? _premiumFilter;
  Trail? _selectedCatalogTrail;
  Trail? _editingTrail;
  late ContentModuleSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.section;
    ref.listenManual(trailControllerProvider, (previous, next) {
      if (!next.hasError) {
        return;
      }

      final error = next.error;
      final message = error is DioException
          ? (error.response?.data is Map<String, dynamic>
                ? ((error.response?.data['details'] as List?)?.join(', ') ??
                      error.response?.data['message']?.toString() ??
                      error.message ??
                      'Nao foi possivel salvar a trilha.')
                : error.message ?? 'Nao foi possivel salvar a trilha.')
          : 'Nao foi possivel salvar a trilha.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  void didUpdateWidget(covariant ContentModuleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _section = widget.section;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    _searchController.dispose();
    for (final link in _mediaLinks) {
      link.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(trailControllerProvider.notifier);
    final editingTrail = _editingTrail;
    if (editingTrail == null) {
      await controller.create(
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        content: _contentController.text.trim(),
        category: _categoryController.text.trim(),
        premium: _premium,
        mediaLinks: _buildMediaLinks(),
      );
    } else {
      await controller.updateTrail(
        id: editingTrail.id,
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        content: _contentController.text.trim(),
        category: _categoryController.text.trim(),
        premium: _premium,
        mediaLinks: _buildMediaLinks(),
      );
    }

    if (!mounted) {
      return;
    }

    _resetAdminEditor();
  }

  void _resetAdminEditor() {
    _titleController.clear();
    _summaryController.clear();
    _contentController.clear();
    _categoryController.text = 'ansiedade';
    setState(() {
      _premium = false;
      _editingTrail = null;
      for (final link in _mediaLinks) {
        link.dispose();
      }
      _mediaLinks
        ..clear()
        ..add(_EditableMediaLink.live());
    });
  }

  void _startEditingTrail(Trail trail) {
    _titleController.text = trail.title;
    _summaryController.text = trail.summary;
    _contentController.text = trail.content ?? '';
    _categoryController.text = trail.category;
    setState(() {
      _premium = trail.premium;
      _editingTrail = trail;
      for (final link in _mediaLinks) {
        link.dispose();
      }
      _mediaLinks
        ..clear()
        ..addAll(
          trail.mediaLinks.isEmpty
              ? [_EditableMediaLink.live()]
              : trail.mediaLinks.map(_EditableMediaLink.fromLink),
        );
    });
  }

  Future<void> _confirmDeleteTrail(Trail trail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir trilha?'),
        content: Text(
          'A trilha "${trail.title}" sera removida, junto com o progresso associado a ela.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(trailControllerProvider.notifier).delete(trail.id);
    if (!mounted) {
      return;
    }

    if (_editingTrail?.id == trail.id) {
      _resetAdminEditor();
    }
    if (_selectedCatalogTrail?.id == trail.id) {
      setState(() => _selectedCatalogTrail = null);
    }
  }

  Future<void> _applyFilters() {
    setState(() => _selectedCatalogTrail = null);
    return ref
        .read(trailControllerProvider.notifier)
        .applyFilters(
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          premium: _premiumFilter,
        );
  }

  void _selectSection(ContentModuleSection section) {
    setState(() {
      _section = section;
      if (section == ContentModuleSection.catalog) {
        _selectedCatalogTrail = null;
      }
    });
  }

  List<TrailMediaLink> _buildMediaLinks() {
    return _mediaLinks
        .where((item) => item.urlController.text.trim().isNotEmpty)
        .map(
          (item) => TrailMediaLink(
            label: item.labelController.text.trim().isEmpty
                ? 'Conteudo complementar'
                : item.labelController.text.trim(),
            url: item.urlController.text.trim(),
            type: item.type == 'auto'
                ? _detectType(item.urlController.text.trim())
                : item.type,
          ),
        )
        .toList();
  }

  String _detectType(String url) {
    final normalized = url.toLowerCase();
    if (normalized.contains('youtube.com') || normalized.contains('youtu.be')) {
      return 'youtube';
    }
    if (normalized.endsWith('.mp4') || normalized.contains('vimeo.com')) {
      return 'video';
    }
    if (normalized.endsWith('.mp3') || normalized.contains('spotify.com')) {
      return 'audio';
    }
    return 'external';
  }

  @override
  Widget build(BuildContext context) {
    final trailsState = ref.watch(trailControllerProvider);
    final currentJourney = ref.watch(currentJourneyTrailProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final profile = ref.watch(currentProfileProvider);
    final isAdmin = session?.isAdmin ?? false;
    final hasPremiumAccess =
        (session?.isPremium ?? false) || (profile?.premium ?? false);
    final isSaving = trailsState.isLoading && !trailsState.hasValue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final currentTrail = currentJourney.asData?.value;
        final showingActiveJourney =
            currentTrail != null && _section == ContentModuleSection.journey;
        final showingCatalogJourney =
            _section == ContentModuleSection.catalog &&
            _selectedCatalogTrail != null;

        final Widget body = switch ((
          showingActiveJourney,
          showingCatalogJourney,
        )) {
          (true, _) => currentJourney.when(
            data: (trail) => trail == null
                ? const SizedBox.shrink()
                : _CurrentJourneyPanel(
                    trail: trail,
                    onOpenCatalog: () =>
                        _selectSection(ContentModuleSection.catalog),
                    onOpenMentor: widget.onOpenMentor,
                  ),
            error: (_, _) => const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
          ),
          (_, true) => _CatalogJourneyPanel(
            trail: _selectedCatalogTrail!,
            onBack: () => setState(() => _selectedCatalogTrail = null),
            onOpenMentor: widget.onOpenMentor,
          ),
          _ => SingleChildScrollView(
            child: Column(
              children: [
                currentJourney.when(
                  data: (trail) => trail == null
                      ? const SizedBox.shrink()
                      : _CurrentJourneyBanner(
                          trail: trail,
                          onOpenJourney: () => setState(
                            () => _section = ContentModuleSection.journey,
                          ),
                        ),
                  error: (_, _) => const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                trailsState.when(
                  data: (result) => _TrailExplorer(
                    result: result,
                    isAdmin: isAdmin,
                    hasPremiumAccess: hasPremiumAccess,
                    searchController: _searchController,
                    premiumFilter: _premiumFilter,
                    onSearchChanged: (_) => _applyFilters(),
                    onPremiumFilterChanged: (value) {
                      setState(() {
                        _premiumFilter = value;
                        _selectedCatalogTrail = null;
                      });
                      _applyFilters();
                    },
                    onOpenTrail: (trail) => setState(() {
                      _section = ContentModuleSection.catalog;
                      _selectedCatalogTrail = trail;
                    }),
                    onEditTrail: isAdmin ? _startEditingTrail : null,
                    onDeleteTrail: isAdmin ? _confirmDeleteTrail : null,
                    onPageChanged: (page) {
                      setState(() => _selectedCatalogTrail = null);
                      ref.read(trailControllerProvider.notifier).goToPage(page);
                    },
                  ),
                  error: (error, stackTrace) => _ContentErrorState(
                    onRetry: () =>
                        ref.read(trailControllerProvider.notifier).refresh(),
                  ),
                  loading: () => const _ContentLoadingState(),
                ),
              ],
            ),
          ),
        };

        return Column(
          children: [
            if (widget.showSectionChips) ...[
              _ContentSectionSwitcher(
                selected: _section,
                hasActiveJourney: currentTrail != null,
                onSelected: _selectSection,
              ),
              const SizedBox(height: 16),
            ],
            if (isAdmin) ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.44,
                ),
                child: SingleChildScrollView(
                  child: PrimaryPanel(
                    child: _AdminTrailEditor(
                      formKey: _formKey,
                      titleController: _titleController,
                      summaryController: _summaryController,
                      contentController: _contentController,
                      categoryController: _categoryController,
                      premium: _premium,
                      onPremiumChanged: (value) =>
                          setState(() => _premium = value),
                      mediaLinks: _mediaLinks,
                      editingTrail: _editingTrail,
                      onAddLink: () => setState(
                        () => _mediaLinks.add(_EditableMediaLink.live()),
                      ),
                      onRemoveLink: (index) => setState(() {
                        _mediaLinks[index].dispose();
                        _mediaLinks.removeAt(index);
                        if (_mediaLinks.isEmpty) {
                          _mediaLinks.add(_EditableMediaLink.live());
                        }
                      }),
                      onCancelEditing: _editingTrail == null
                          ? null
                          : _resetAdminEditor,
                      onSubmit: isSaving ? null : _submit,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

class _ContentSectionSwitcher extends StatelessWidget {
  const _ContentSectionSwitcher({
    required this.selected,
    required this.hasActiveJourney,
    required this.onSelected,
  });

  final ContentModuleSection selected;
  final bool hasActiveJourney;
  final ValueChanged<ContentModuleSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(8),
      semanticLabel: 'Alternar area de trilhas',
      child: Row(
        children: [
          Expanded(
            child: _ContentSectionButton(
              icon: Icons.route_rounded,
              label: hasActiveJourney ? 'Minha jornada' : 'Jornada',
              selected: selected == ContentModuleSection.journey,
              onTap: () => onSelected(ContentModuleSection.journey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ContentSectionButton(
              icon: Icons.grid_view_rounded,
              label: 'Catalogo',
              selected: selected == ContentModuleSection.catalog,
              onTap: () => onSelected(ContentModuleSection.catalog),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentSectionButton extends StatelessWidget {
  const _ContentSectionButton({
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
    final color = selected
        ? context.evoluaColors.background
        : context.evoluaColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : context.evoluaColors.outline.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
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

class _CurrentJourneyBanner extends StatelessWidget {
  const _CurrentJourneyBanner({
    required this.trail,
    required this.onOpenJourney,
  });

  final Trail trail;
  final VoidCallback onOpenJourney;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minha jornada ativa',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.evoluaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(trail.title, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onOpenJourney,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Abrir jornada'),
          ),
        ],
      ),
    );
  }
}

class _CurrentJourneyPanel extends ConsumerStatefulWidget {
  const _CurrentJourneyPanel({
    required this.trail,
    required this.onOpenCatalog,
    this.onOpenMentor,
  });

  final Trail trail;
  final VoidCallback onOpenCatalog;
  final VoidCallback? onOpenMentor;

  @override
  ConsumerState<_CurrentJourneyPanel> createState() =>
      _CurrentJourneyPanelState();
}

class _CurrentJourneyPanelState extends ConsumerState<_CurrentJourneyPanel> {
  bool _isActing = false;

  Future<void> _runJourneyAction(TrailJourney journey) async {
    if (_isActing) {
      return;
    }

    if (journey.isCompleted) {
      _showJourneyDetails(context, journey.trail);
      return;
    }

    setState(() => _isActing = true);
    try {
      final actions = ref.read(trailJourneyActionProvider);
      if (!journey.isStarted) {
        await actions.start(journey.trail.id);
      } else if (journey.nextStep != null && !journey.isCompleted) {
        await actions.completeStep(journey.trail.id, journey.nextStep!.index);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voce avancou mais um passo.')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final journeyState = ref.watch(trailJourneyProvider(widget.trail.id));

    return journeyState.when(
      data: (journey) => _VisualJourneyPanel(
        journey: journey,
        isActing: _isActing,
        onOpenCatalog: widget.onOpenCatalog,
        onOpenMentor: widget.onOpenMentor,
        onPrimaryAction: () => _runJourneyAction(journey),
      ),
      error: (_, _) => PrimaryPanel(
        child: _ContentErrorState(
          onRetry: () => ref.invalidate(trailJourneyProvider(widget.trail.id)),
        ),
      ),
      loading: () => const PanelSkeleton(rows: 4, tileHeight: 92),
    );
  }
}

class _CatalogJourneyPanel extends ConsumerStatefulWidget {
  const _CatalogJourneyPanel({
    required this.trail,
    required this.onBack,
    this.onOpenMentor,
  });

  final Trail trail;
  final VoidCallback onBack;
  final VoidCallback? onOpenMentor;

  @override
  ConsumerState<_CatalogJourneyPanel> createState() =>
      _CatalogJourneyPanelState();
}

class _CatalogJourneyPanelState extends ConsumerState<_CatalogJourneyPanel> {
  bool _isActing = false;

  Future<void> _runJourneyAction(TrailJourney journey) async {
    if (_isActing) {
      return;
    }

    if (journey.isCompleted) {
      _showJourneyDetails(context, journey.trail);
      return;
    }

    setState(() => _isActing = true);
    try {
      final actions = ref.read(trailJourneyActionProvider);
      if (!journey.isStarted) {
        await actions.start(journey.trail.id);
      } else if (journey.nextStep != null) {
        await actions.completeStep(journey.trail.id, journey.nextStep!.index);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voce avancou mais um passo.')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final journeyState = ref.watch(trailJourneyProvider(widget.trail.id));

    return journeyState.when(
      data: (journey) => _VisualJourneyPanel(
        journey: journey,
        isActing: _isActing,
        isCatalogTrail: true,
        onBackToCatalog: widget.onBack,
        onOpenMentor: widget.onOpenMentor,
        onPrimaryAction: () => _runJourneyAction(journey),
      ),
      error: (_, _) => PrimaryPanel(
        child: _ContentErrorState(
          onRetry: () => ref.invalidate(trailJourneyProvider(widget.trail.id)),
        ),
      ),
      loading: () => const PanelSkeleton(rows: 4, tileHeight: 92),
    );
  }
}

class _VisualJourneyPanel extends StatelessWidget {
  const _VisualJourneyPanel({
    required this.journey,
    required this.isActing,
    required this.onPrimaryAction,
    this.isCatalogTrail = false,
    this.onBackToCatalog,
    this.onOpenCatalog,
    this.onOpenMentor,
  });

  final TrailJourney journey;
  final bool isActing;
  final VoidCallback onPrimaryAction;
  final bool isCatalogTrail;
  final VoidCallback? onBackToCatalog;
  final VoidCallback? onOpenCatalog;
  final VoidCallback? onOpenMentor;

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveBreakpoints.isCompact(context);
    final activeColor = _journeyAccentColor(journey.trail);
    final nextStep = journey.nextStep;

    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _JourneyHeader(
                    journey: journey,
                    activeColor: activeColor,
                    isCatalogTrail: isCatalogTrail,
                    onBackToCatalog: onBackToCatalog,
                    onOpenCatalog: onOpenCatalog,
                    onOpenFullJourney: () =>
                        _showJourneyDetails(context, journey.trail),
                  ),
                  const SizedBox(height: 18),
                  _JourneyProgressSummary(
                    journey: journey,
                    activeColor: activeColor,
                  ),
                  const SizedBox(height: 18),
                  if (compact)
                    _JourneyTimeline(
                      journey: journey,
                      activeColor: activeColor,
                      onStepTap: (step) =>
                          _showStepSheet(context, journey, step),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _JourneyTimeline(
                            journey: journey,
                            activeColor: activeColor,
                            onStepTap: (step) =>
                                _showStepSheet(context, journey, step),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 6,
                          child: _JourneyStepDetailCard(
                            step: nextStep ?? journey.steps.last,
                            activeColor: activeColor,
                            isCompleted: journey.isCompleted,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  _JourneyMentorEntryCard(onOpenMentor: onOpenMentor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _JourneyStickyCta(
            journey: journey,
            isActing: isActing,
            onPressed: isActing || journey.steps.isEmpty
                ? null
                : onPrimaryAction,
          ),
        ],
      ),
    );
  }
}

class _JourneyStickyCta extends StatelessWidget {
  const _JourneyStickyCta({
    required this.journey,
    required this.isActing,
    required this.onPressed,
  });

  final TrailJourney journey;
  final bool isActing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
      decoration: BoxDecoration(
        color: context.evoluaColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: isActing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  journey.isCompleted
                      ? Icons.replay_rounded
                      : journey.isStarted
                      ? Icons.task_alt_rounded
                      : Icons.play_arrow_rounded,
                ),
          label: Text(_journeyCtaLabel(journey)),
        ),
      ),
    );
  }
}

class _JourneyMentorEntryCard extends StatelessWidget {
  const _JourneyMentorEntryCard({this.onOpenMentor});

  final VoidCallback? onOpenMentor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Precisa adaptar sua jornada hoje?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Converse com seu Mentor Evolua para ajustar sua proxima etapa.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpenMentor,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Abrir Mentor Evolua'),
          ),
        ],
      ),
    );
  }
}

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({
    required this.journey,
    required this.activeColor,
    required this.onOpenFullJourney,
    this.isCatalogTrail = false,
    this.onBackToCatalog,
    this.onOpenCatalog,
  });

  final TrailJourney journey;
  final Color activeColor;
  final VoidCallback onOpenFullJourney;
  final bool isCatalogTrail;
  final VoidCallback? onBackToCatalog;
  final VoidCallback? onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    final trail = journey.trail;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCatalogTrail
              ? 'Trilha avulsa'
              : trail.generatedByAi
              ? 'Sua trilha de ${_categoryLabel(trail.category)}'
              : 'Trilha guiada',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: activeColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(trail.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          isCatalogTrail
              ? 'Conteudo cadastrado para voce fazer no seu ritmo, sem substituir sua jornada principal.'
              : trail.generatedByAi
              ? 'Criada com base no seu estado atual. Vamos seguir com passos pequenos e claros.'
              : trail.summary,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusBadge(
              label: isCatalogTrail
                  ? 'Conteudo guiado'
                  : trail.generatedByAi
                  ? 'Personalizada'
                  : 'Catalogo',
              color: activeColor,
            ),
            if (trail.generatedByAi)
              const _StatusBadge(
                label: 'IA ativa',
                color: AppColors.accentGold,
              ),
            _StatusBadge(
              label: '${journey.steps.length} etapas',
              color: context.evoluaColors.textSecondary,
            ),
          ],
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            if (isCatalogTrail && onBackToCatalog != null)
              OutlinedButton.icon(
                onPressed: onBackToCatalog,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar ao catalogo'),
              ),
            if (!isCatalogTrail && onOpenCatalog != null)
              OutlinedButton.icon(
                onPressed: onOpenCatalog,
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Ver catalogo'),
              ),
            OutlinedButton.icon(
              onPressed: onOpenFullJourney,
              icon: const Icon(Icons.auto_stories_rounded),
              label: Text(
                isCatalogTrail ? 'Conteudo completo' : 'Jornada completa',
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [info, const SizedBox(height: 14), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: info),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    );
  }
}

class _JourneyProgressSummary extends StatelessWidget {
  const _JourneyProgressSummary({
    required this.journey,
    required this.activeColor,
  });

  final TrailJourney journey;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: activeColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${journey.progressPercent}% da jornada',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.evoluaColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${journey.completedSteps}/${journey.steps.length} etapas',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.evoluaColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: journey.progressPercent / 100,
              backgroundColor: context.evoluaColors.surfaceStrong.withValues(
                alpha: 0.5,
              ),
              color: activeColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyTimeline extends StatelessWidget {
  const _JourneyTimeline({
    required this.journey,
    required this.activeColor,
    required this.onStepTap,
  });

  final TrailJourney journey;
  final Color activeColor;
  final ValueChanged<TrailJourneyStep> onStepTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: journey.steps
          .map(
            (step) => _JourneyTimelineNode(
              step: step,
              isLast: step.index == journey.steps.length - 1,
              activeColor: activeColor,
              onTap: () => onStepTap(step),
            ),
          )
          .toList(),
    );
  }
}

class _JourneyTimelineNode extends StatelessWidget {
  const _JourneyTimelineNode({
    required this.step,
    required this.isLast,
    required this.activeColor,
    required this.onTap,
  });

  final TrailJourneyStep step;
  final bool isLast;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nodeColor = step.isCompleted || step.isCurrent
        ? activeColor
        : context.evoluaColors.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: step.isCurrent ? 34 : 28,
                height: step.isCurrent ? 34 : 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.isCompleted
                      ? activeColor
                      : context.evoluaColors.surfaceStrong.withValues(
                          alpha: 0.9,
                        ),
                  border: Border.all(
                    color: nodeColor,
                    width: step.isCurrent ? 2 : 1,
                  ),
                  boxShadow: step.isCurrent
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.42),
                            blurRadius: 22,
                            spreadRadius: 2,
                          ),
                        ]
                      : const [],
                ),
                child: Icon(
                  step.isCompleted
                      ? Icons.check_rounded
                      : step.isCurrent
                      ? Icons.local_fire_department_rounded
                      : Icons.circle_outlined,
                  size: 17,
                  color: step.isCompleted
                      ? context.evoluaColors.background
                      : nodeColor,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        nodeColor.withValues(alpha: 0.8),
                        context.evoluaColors.outline.withValues(alpha: 0.14),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: step.isCurrent
                          ? context.evoluaColors.textPrimary
                          : context.evoluaColors.textSecondary,
                      fontWeight: step.isCurrent
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${step.estimatedMinutes} min • ${step.summary}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyStepDetailCard extends StatelessWidget {
  const _JourneyStepDetailCard({
    required this.step,
    required this.activeColor,
    required this.isCompleted,
  });

  final TrailJourneyStep step;
  final Color activeColor;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: activeColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCompleted ? 'Jornada concluida' : 'Proximo passo',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: activeColor),
          ),
          const SizedBox(height: 8),
          Text(step.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(step.summary, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          MarkdownBody(
            data: step.content,
            selectable: true,
            onTapLink: (text, href, title) {
              if (href != null) {
                launchUrlString(href);
              }
            },
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.evoluaColors.textPrimary,
                  ),
                  listBullet: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: activeColor),
                ),
          ),
        ],
      ),
    );
  }
}

String _journeyCtaLabel(TrailJourney journey) {
  if (journey.isCompleted) {
    return 'Revisar jornada';
  }
  if (!journey.isStarted) {
    return 'Iniciar trilha';
  }
  return 'Fazer proxima etapa';
}

String _catalogTrailCtaLabel(TrailJourney journey) {
  if (journey.isCompleted) {
    return 'Revisar trilha';
  }
  if (journey.isStarted) {
    return 'Continuar trilha';
  }
  return 'Iniciar trilha';
}

Color _journeyAccentColor(Trail trail) {
  final category = trail.category.toLowerCase();
  if (category.contains('ansiedade') || category.contains('sono')) {
    return const Color(0xFF7DD3FC);
  }
  if (category.contains('foco') || category.contains('produt')) {
    return AppColors.accent;
  }
  if (category.contains('motiv') || category.contains('energia')) {
    return AppColors.accentWarm;
  }
  return trail.generatedByAi ? AppColors.accent : AppColors.accentGold;
}

String _categoryLabel(String category) {
  if (category.trim().isEmpty) {
    return 'clareza';
  }
  return category.trim().toLowerCase();
}

void _showStepSheet(
  BuildContext context,
  TrailJourney journey,
  TrailJourneyStep initialStep,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.evoluaColors.backgroundSecondary,
    builder: (context) => _JourneyStepSheet(
      journey: journey,
      initialStep: initialStep,
      activeColor: _journeyAccentColor(journey.trail),
    ),
  );
}

class _JourneyStepSheet extends StatefulWidget {
  const _JourneyStepSheet({
    required this.journey,
    required this.initialStep,
    required this.activeColor,
  });

  final TrailJourney journey;
  final TrailJourneyStep initialStep;
  final Color activeColor;

  @override
  State<_JourneyStepSheet> createState() => _JourneyStepSheetState();
}

class _JourneyStepSheetState extends State<_JourneyStepSheet> {
  late int _index = widget.initialStep.index;

  @override
  Widget build(BuildContext context) {
    final step = widget.journey.steps[_index];
    return SafeArea(
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -120 && _index < widget.journey.steps.length - 1) {
            setState(() => _index++);
          }
          if (velocity > 120 && _index > 0) {
            setState(() => _index--);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: _JourneyStepDetailCard(
              step: step,
              activeColor: widget.activeColor,
              isCompleted: widget.journey.isCompleted,
            ),
          ),
        ),
      ),
    );
  }
}

void _showJourneyDetails(BuildContext context, Trail trail) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: context.evoluaColors.backgroundSecondary,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trail.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: context.evoluaColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(trail.summary, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownBody(
                        data: trail.content ?? '',
                        selectable: true,
                        onTapLink: (text, href, title) {
                          if (href != null) {
                            launchUrlString(href);
                          }
                        },
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ).copyWith(
                              p: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: context.evoluaColors.textPrimary,
                                  ),
                              h1: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: context.evoluaColors.textPrimary,
                                  ),
                              h2: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: context.evoluaColors.textPrimary,
                                  ),
                              listBullet: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.accent),
                            ),
                      ),
                      if (trail.mediaLinks.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Links curados',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: context.evoluaColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        ...trail.mediaLinks.map(
                          (link) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: OutlinedButton.icon(
                              onPressed: () => launchUrlString(link.url),
                              icon: Icon(
                                link.isYoutube
                                    ? Icons.ondemand_video_rounded
                                    : Icons.link_rounded,
                              ),
                              label: Text(link.label),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AdminTrailEditor extends StatelessWidget {
  const _AdminTrailEditor({
    required this.formKey,
    required this.titleController,
    required this.summaryController,
    required this.contentController,
    required this.categoryController,
    required this.premium,
    required this.onPremiumChanged,
    required this.mediaLinks,
    required this.editingTrail,
    required this.onAddLink,
    required this.onRemoveLink,
    required this.onCancelEditing,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController contentController;
  final TextEditingController categoryController;
  final bool premium;
  final ValueChanged<bool> onPremiumChanged;
  final List<_EditableMediaLink> mediaLinks;
  final Trail? editingTrail;
  final VoidCallback onAddLink;
  final ValueChanged<int> onRemoveLink;
  final VoidCallback? onCancelEditing;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final isEditing = editingTrail != null;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing ? 'Editar trilha' : 'Criar nova trilha',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          if (isEditing) ...[
            const SizedBox(height: 6),
            Text(
              'Editando: ${editingTrail!.title}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          TextFormField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Titulo da trilha',
              prefixIcon: Icon(Icons.auto_stories_rounded),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Informe o titulo.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: summaryController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Resumo curto',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.short_text_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Informe um resumo.';
              if (text.length < 12) return 'Use pelo menos 12 caracteres.';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: contentController,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Conteudo principal em Markdown',
              alignLabelWithHint: true,
              helperText:
                  'Exemplos: # Titulo, ## Secao, - lista, [link](https://...)',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escreva o conteudo principal.'
                : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe a categoria.'
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Trilha premium'),
                  value: premium,
                  onChanged: onPremiumChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Links de apoio',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.evoluaColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...mediaLinks.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MediaLinkEditor(
                item: entry.value,
                onRemove: mediaLinks.length == 1
                    ? null
                    : () => onRemoveLink(entry.key),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddLink,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Adicionar link'),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: onSubmit,
                icon: Icon(
                  isEditing
                      ? Icons.save_outlined
                      : Icons.add_circle_outline_rounded,
                ),
                label: Text(isEditing ? 'Salvar alteracoes' : 'Criar trilha'),
              ),
              if (onCancelEditing != null)
                OutlinedButton.icon(
                  onPressed: onCancelEditing,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancelar edicao'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaLinkEditor extends StatelessWidget {
  const _MediaLinkEditor({required this.item, required this.onRemove});

  final _EditableMediaLink item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.labelController,
                  decoration: const InputDecoration(
                    labelText: 'Rotulo do link',
                    prefixIcon: Icon(Icons.label_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: item.type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    prefixIcon: Icon(Icons.video_library_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'auto',
                      child: Text('Auto detectar'),
                    ),
                    DropdownMenuItem(value: 'youtube', child: Text('YouTube')),
                    DropdownMenuItem(value: 'video', child: Text('Video')),
                    DropdownMenuItem(value: 'article', child: Text('Artigo')),
                    DropdownMenuItem(value: 'audio', child: Text('Audio')),
                    DropdownMenuItem(value: 'external', child: Text('Externo')),
                  ],
                  onChanged: (value) => item.type = value ?? 'auto',
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: item.urlController,
            decoration: const InputDecoration(
              labelText: 'URL do conteudo',
              hintText: 'https://youtube.com/... ou outro link seguro',
              prefixIcon: Icon(Icons.link_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              if (!text.startsWith('http://') && !text.startsWith('https://')) {
                return 'Use uma URL com http ou https.';
              }
              return null;
            },
          ),
          if (item.urlController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.urlController.text.toLowerCase().contains('youtu')
                    ? 'Preview detectado: YouTube'
                    : 'Preview detectado: link externo',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.accentWarm),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrailExplorer extends ConsumerWidget {
  const _TrailExplorer({
    required this.result,
    required this.isAdmin,
    required this.hasPremiumAccess,
    required this.searchController,
    required this.premiumFilter,
    required this.onSearchChanged,
    required this.onPremiumFilterChanged,
    required this.onOpenTrail,
    required this.onEditTrail,
    required this.onDeleteTrail,
    required this.onPageChanged,
  });

  final PaginatedResponse<Trail> result;
  final bool isAdmin;
  final bool hasPremiumAccess;
  final TextEditingController searchController;
  final bool? premiumFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool?> onPremiumFilterChanged;
  final ValueChanged<Trail> onOpenTrail;
  final ValueChanged<Trail>? onEditTrail;
  final ValueChanged<Trail>? onDeleteTrail;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Encontrar uma trilha certa',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.evoluaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.totalItems} trilhas encontradas nesta busca.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Buscar por titulo, tema ou resumo',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: premiumFilter == null,
                    onSelected: (_) => onPremiumFilterChanged(null),
                  ),
                  ChoiceChip(
                    label: const Text('Essenciais'),
                    selected: premiumFilter == false,
                    onSelected: (_) => onPremiumFilterChanged(false),
                  ),
                  ChoiceChip(
                    label: const Text('Premium'),
                    selected: premiumFilter == true,
                    onSelected: (_) => onPremiumFilterChanged(true),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (result.items.isEmpty)
          GuidedEmptyState(
            icon: Icons.spa_rounded,
            title: 'Nenhuma trilha aparece com esse filtro.',
            subtitle:
                'Experimente outro termo ou limpe os filtros para ampliar sua busca.',
            actionLabel: 'Ver todas as trilhas',
            onAction: () {
              searchController.clear();
              onPremiumFilterChanged(null);
            },
          )
        else
          Column(
            children: [
              ...result.items.map((trail) {
                final journeyState = trail.accessible
                    ? ref.watch(trailJourneyProvider(trail.id))
                    : null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PrimaryPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                trail.title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: context.evoluaColors.textPrimary,
                                    ),
                              ),
                            ),
                            Text(
                              trail.category,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.accent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          trail.summary,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusBadge(
                              label: trail.premium ? 'Premium' : 'Essencial',
                              color: trail.premium
                                  ? AppColors.accentGold
                                  : AppColors.accent,
                            ),
                            if (trail.mediaLinks.isNotEmpty)
                              _StatusBadge(
                                label: '${trail.mediaLinks.length} links',
                                color: AppColors.accentWarm,
                              ),
                            if (journeyState?.hasValue ?? false)
                              _StatusBadge(
                                label:
                                    '${journeyState!.requireValue.progressPercent}% concluido',
                                color: context.evoluaColors.textSecondary,
                              ),
                            if (!trail.accessible &&
                                !isAdmin &&
                                !hasPremiumAccess)
                              const _StatusBadge(
                                label: 'Faca upgrade para acessar',
                                color: AppColors.danger,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (trail.accessible)
                                journeyState!.when(
                                  data: (journey) => ElevatedButton.icon(
                                    onPressed: () async {
                                      if (!journey.isStarted) {
                                        await ref
                                            .read(trailJourneyActionProvider)
                                            .start(trail.id);
                                      }
                                      if (context.mounted) {
                                        onOpenTrail(trail);
                                      }
                                    },
                                    icon: Icon(
                                      journey.isCompleted
                                          ? Icons.replay_rounded
                                          : journey.isStarted
                                          ? Icons.task_alt_rounded
                                          : Icons.play_arrow_rounded,
                                    ),
                                    label: Text(_catalogTrailCtaLabel(journey)),
                                  ),
                                  loading: () => ElevatedButton.icon(
                                    onPressed: null,
                                    icon: const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    label: const Text('Carregando progresso'),
                                  ),
                                  error: (_, _) => ElevatedButton.icon(
                                    onPressed: () => onOpenTrail(trail),
                                    icon: const Icon(Icons.route_rounded),
                                    label: const Text('Abrir trilha'),
                                  ),
                                ),
                              OutlinedButton.icon(
                                onPressed: trail.accessible
                                    ? () => onOpenTrail(trail)
                                    : () => _showTrailDetails(context, trail),
                                icon: const Icon(Icons.visibility_rounded),
                                label: Text(
                                  trail.accessible
                                      ? 'Ver caminho'
                                      : 'Ver detalhes',
                                ),
                              ),
                              if (isAdmin) ...[
                                OutlinedButton.icon(
                                  onPressed: () => onEditTrail?.call(trail),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Editar'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => onDeleteTrail?.call(trail),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  label: const Text('Excluir'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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

  void _showTrailDetails(BuildContext context, Trail trail) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: context.evoluaColors.backgroundSecondary,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trail.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: context.evoluaColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  trail.summary,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    child: trail.accessible
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MarkdownBody(
                                data: trail.content ?? '',
                                selectable: true,
                                onTapLink: (text, href, title) {
                                  if (href != null) {
                                    launchUrlString(href);
                                  }
                                },
                                styleSheet:
                                    MarkdownStyleSheet.fromTheme(
                                      Theme.of(context),
                                    ).copyWith(
                                      p: Theme.of(context).textTheme.bodyLarge
                                          ?.copyWith(
                                            color: context
                                                .evoluaColors
                                                .textPrimary,
                                          ),
                                      h1: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: context
                                                .evoluaColors
                                                .textPrimary,
                                          ),
                                      h2: Theme.of(context).textTheme.titleLarge
                                          ?.copyWith(
                                            color: context
                                                .evoluaColors
                                                .textPrimary,
                                          ),
                                      listBullet: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(color: AppColors.accent),
                                    ),
                              ),
                              if (trail.mediaLinks.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(
                                  'Conteudos de apoio',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: context.evoluaColors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                ...trail.mediaLinks.map(
                                  (link) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: InkWell(
                                      onTap: () => launchUrlString(link.url),
                                      borderRadius: BorderRadius.circular(18),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: context
                                              .evoluaColors
                                              .surfaceStrong
                                              .withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: context.evoluaColors.outline
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              link.isYoutube
                                                  ? Icons.ondemand_video_rounded
                                                  : Icons.link_rounded,
                                              color: link.isYoutube
                                                  ? AppColors.danger
                                                  : AppColors.accentWarm,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    link.label,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    link.url,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : GuidedEmptyState(
                            icon: Icons.workspace_premium_rounded,
                            title: 'Conteudo completo liberado no premium',
                            subtitle:
                                'Voce pode visualizar o resumo da trilha agora e desbloquear o conteudo completo com upgrade.',
                            actionLabel: 'Entendi',
                            onAction: () => Navigator.of(context).pop(),
                          ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

class _ContentLoadingState extends StatelessWidget {
  const _ContentLoadingState();

  @override
  Widget build(BuildContext context) {
    return const FeedSkeleton(cards: 3);
  }
}

class _ContentErrorState extends StatelessWidget {
  const _ContentErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GuidedEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Nao conseguimos abrir as trilhas agora.',
      subtitle: 'Atualize a pagina ou tente novamente em instantes.',
      actionLabel: 'Tentar novamente',
      onAction: onRetry,
    );
  }
}

class _EditableMediaLink {
  _EditableMediaLink.live()
    : labelController = TextEditingController(),
      urlController = TextEditingController(),
      type = 'auto';

  _EditableMediaLink.fromLink(TrailMediaLink link)
    : labelController = TextEditingController(text: link.label),
      urlController = TextEditingController(text: link.url),
      type = link.type;

  final TextEditingController labelController;
  final TextEditingController urlController;
  String type;

  void dispose() {
    labelController.dispose();
    urlController.dispose();
  }
}
