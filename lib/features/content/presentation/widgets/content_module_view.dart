import 'dart:async';

import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/ads/presentation/widgets/monetization_prompt.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_video_progress.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/panel_skeleton.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as ytm;
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as ytw;

enum ContentModuleSection { journey, catalog }

class ContentModuleView extends ConsumerStatefulWidget {
  const ContentModuleView({
    super.key,
    this.section = ContentModuleSection.journey,
    this.showSectionChips = true,
    this.onOpenMentor,
    this.onOpenPremium,
    this.initialTrailId,
    this.onInitialTrailConsumed,
  });

  final ContentModuleSection section;
  final bool showSectionChips;
  final VoidCallback? onOpenMentor;
  final VoidCallback? onOpenPremium;
  final int? initialTrailId;
  final VoidCallback? onInitialTrailConsumed;

  @override
  ConsumerState<ContentModuleView> createState() => _ContentModuleViewState();
}

class _ContentModuleViewState extends ConsumerState<ContentModuleView> {
  final _searchController = TextEditingController();
  static const _minimumSearchLength = 4;
  static const _searchDebounceDuration = Duration(milliseconds: 450);
  Timer? _searchDebounce;
  String? _searchHelperText;
  bool? _premiumFilter;
  Trail? _selectedCatalogTrail;
  late ContentModuleSection _section;
  int? _openingInitialTrailId;

  @override
  void initState() {
    super.initState();
    _section = widget.section;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInitialTrailIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant ContentModuleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      setState(() {
        _section = widget.section;
        if (_section == ContentModuleSection.catalog &&
            widget.initialTrailId == null) {
          _selectedCatalogTrail = null;
        }
      });
    }

    if (oldWidget.initialTrailId != widget.initialTrailId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openInitialTrailIfNeeded();
      });
    }
  }

  Future<void> _openInitialTrailIfNeeded() async {
    final trailId = widget.initialTrailId;

    if (trailId == null || _openingInitialTrailId == trailId) {
      return;
    }

    _openingInitialTrailId = trailId;

    try {
      final journey = await ref.read(trailJourneyProvider(trailId).future);

      if (!mounted) {
        return;
      }

      setState(() {
        _section = ContentModuleSection.catalog;
        _selectedCatalogTrail = journey.trail;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir a trilha sugerida agora.'),
          ),
        );
      }
    } finally {
      _openingInitialTrailId = null;
      widget.onInitialTrailConsumed?.call();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _applyFilters({String? searchOverride}) {
    final rawSearch = searchOverride ?? _searchController.text;
    final normalizedSearch = rawSearch.trim();
    setState(() => _selectedCatalogTrail = null);
    return ref
        .read(trailControllerProvider.notifier)
        .applyFilters(
          search: normalizedSearch.isEmpty ? null : normalizedSearch,
          premium: _premiumFilter,
        );
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    final normalizedSearch = value.trim();

    if (normalizedSearch.isNotEmpty &&
        normalizedSearch.length < _minimumSearchLength) {
      setState(() {
        _searchHelperText = 'Digite pelo menos 4 caracteres para buscar.';
      });
      return;
    }

    setState(() => _searchHelperText = null);
    _searchDebounce = Timer(
      _searchDebounceDuration,
      () => _applyFilters(searchOverride: normalizedSearch),
    );
  }

  void _handlePremiumFilterChanged(bool? value) {
    _searchDebounce?.cancel();
    final normalizedSearch = _searchController.text.trim();
    setState(() {
      _premiumFilter = value;
      _selectedCatalogTrail = null;
      _searchHelperText =
          normalizedSearch.isNotEmpty &&
              normalizedSearch.length < _minimumSearchLength
          ? 'Digite pelo menos 4 caracteres para buscar.'
          : null;
    });
    _applyFilters(
      searchOverride: normalizedSearch.length >= _minimumSearchLength
          ? normalizedSearch
          : null,
    );
  }

  void _clearCatalogFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _premiumFilter = null;
      _selectedCatalogTrail = null;
      _searchHelperText = null;
    });
    _applyFilters(searchOverride: null);
  }

  void _selectSection(ContentModuleSection section) {
    setState(() {
      _section = section;
      if (section == ContentModuleSection.catalog) {
        _selectedCatalogTrail = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final trailsState = ref.watch(trailControllerProvider);
    final currentJourney = ref.watch(currentJourneyTrailProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final profile = ref.watch(currentProfileProvider);
    final currentSubscription = ref
        .watch(subscriptionControllerProvider)
        .asData
        ?.value
        .current;
    final hasPremiumAccess =
        (session?.isPremium ?? false) ||
        (profile?.premium ?? false) ||
        (currentSubscription?.premium ?? false);

    return LayoutBuilder(
      builder: (context, _) {
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
          (false, _)
              when _section == ContentModuleSection.journey &&
                  currentJourney.isLoading =>
            const PanelSkeleton(rows: 4, tileHeight: 92),
          (false, _)
              when _section == ContentModuleSection.journey &&
                  currentJourney.hasValue =>
            _EmptyJourneyPanel(
              onOpenCatalog: () => _selectSection(ContentModuleSection.catalog),
            ),
          _ => SingleChildScrollView(
            child: Column(
              children: [
                trailsState.when(
                  data: (result) => _TrailExplorer(
                    result: result,
                    hasPremiumAccess: hasPremiumAccess,
                    searchController: _searchController,
                    premiumFilter: _premiumFilter,
                    searchHelperText: _searchHelperText,
                    onSearchChanged: _handleSearchChanged,
                    onPremiumFilterChanged: _handlePremiumFilterChanged,
                    onClearFilters: _clearCatalogFilters,
                    onOpenTrail: (trail) => setState(() {
                      _section = ContentModuleSection.catalog;
                      _selectedCatalogTrail = trail;
                    }),
                    onOpenPremium: widget.onOpenPremium,
                    onPageChanged: (page) {
                      _searchDebounce?.cancel();
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
      semanticLabel: 'Alternar área de trilhas',
      child: Row(
        children: [
          Expanded(
            child: _ContentSectionButton(
              icon: Icons.route_rounded,
              label: hasActiveJourney ? 'Trilha atual' : 'Trilha',
              selected: selected == ContentModuleSection.journey,
              onTap: () => onSelected(ContentModuleSection.journey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ContentSectionButton(
              icon: Icons.grid_view_rounded,
              label: 'Explorar trilhas',
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

class _EmptyJourneyPanel extends StatelessWidget {
  const _EmptyJourneyPanel({required this.onOpenCatalog});

  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PrimaryPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sua trilha',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.evoluaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aqui ficam suas trilhas em andamento, o próximo passo e recomendações para continuar com constância.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            GuidedEmptyState(
              icon: Icons.route_rounded,
              title: 'Nenhuma trilha em andamento',
              subtitle:
                  'Explore o catálogo e escolha uma trilha para iniciar sua próxima etapa.',
              actionLabel: 'Explorar trilhas',
              onAction: onOpenCatalog,
            ),
          ],
        ),
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
            const SnackBar(content: Text('Você avançou mais um passo.')),
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
            const SnackBar(content: Text('Você avançou mais um passo.')),
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
                            trailId: journey.trail.id,
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
            'Precisa adaptar sua trilha hoje?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Converse com seu Mentor Evolua para ajustar sua próxima etapa.',
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
              ? 'Trilha de ${_categoryLabel(trail.category)}'
              : 'Sua trilha',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: activeColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(trail.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(trail.summary, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusBadge(label: 'Trilha guiada', color: activeColor),
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
                label: const Text('Voltar para explorar'),
              ),
            if (!isCatalogTrail && onOpenCatalog != null)
              OutlinedButton.icon(
                onPressed: onOpenCatalog,
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Explorar trilhas'),
              ),
            OutlinedButton.icon(
              onPressed: onOpenFullJourney,
              icon: const Icon(Icons.auto_stories_rounded),
              label: Text(
                isCatalogTrail ? 'Conteúdo completo' : 'Trilha completa',
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
                  '${journey.progressPercent}% da trilha',
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

class _JourneyStepDetailCard extends ConsumerWidget {
  const _JourneyStepDetailCard({
    required this.trailId,
    required this.step,
    required this.activeColor,
    required this.isCompleted,
  });

  final int trailId;
  final TrailJourneyStep step;
  final Color activeColor;
  final bool isCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            isCompleted ? 'Trilha concluída' : 'Próximo passo',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: activeColor),
          ),
          const SizedBox(height: 8),
          Text(step.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(step.summary, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusBadge(
                label: _stepTypeLabel(step.type),
                color: activeColor,
              ),
              _StatusBadge(
                label: '${step.estimatedMinutes} min',
                color: context.evoluaColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (step.type.toUpperCase() == 'VIDEO' && step.video != null) ...[
            _JourneyVideoPlayer(trailId: trailId, step: step),
            const SizedBox(height: 12),
          ] else ...[
            _StepTtsPlayer(step: step),
            const SizedBox(height: 12),
          ],
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
          if (_supportsStepResponse(step.type)) ...[
            const SizedBox(height: 18),
            _TrailStepResponseEditor(trailId: trailId, step: step),
          ],
        ],
      ),
    );
  }
}

class _TrailStepResponseEditor extends ConsumerStatefulWidget {
  const _TrailStepResponseEditor({required this.trailId, required this.step});

  final int trailId;
  final TrailJourneyStep step;

  @override
  ConsumerState<_TrailStepResponseEditor> createState() =>
      _TrailStepResponseEditorState();
}

class _TrailStepResponseEditorState
    extends ConsumerState<_TrailStepResponseEditor> {
  final _controller = TextEditingController();
  DateTime? _loadedUpdatedAt;
  bool _isSaving = false;

  TrailStepResponseKey get _key =>
      (trailId: widget.trailId, stepIndex: widget.step.index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final saved = await ref
          .read(trailJourneyActionProvider)
          .saveStepResponse(
            trailId: widget.trailId,
            stepIndex: widget.step.index,
            responseText: _controller.text,
          );
      _loadedUpdatedAt = saved.updatedAt;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resposta salva no seu diário.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar sua resposta agora. Tente novamente em instantes.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responseState = ref.watch(trailStepResponseProvider(_key));
    final response = responseState.asData?.value;
    if (response != null && response.updatedAt != _loadedUpdatedAt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isSaving || response.updatedAt == _loadedUpdatedAt) {
          return;
        }
        _loadedUpdatedAt = response.updatedAt;
        _controller.text = response.responseText;
      });
    }

    return Semantics(
      container: true,
      label: 'Sua resposta',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.evoluaColors.surface.withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: context.evoluaColors.outline.withValues(alpha: 0.46),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sua resposta',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.evoluaColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Escreva do seu jeito. Você poderá rever isso no seu diário.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.evoluaColors.textSecondary,
              ),
            ),
            if (responseState.isLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (responseState.hasError) ...[
              const SizedBox(height: 10),
              Text(
                'Não conseguimos carregar sua resposta agora, mas você ainda pode escrever e salvar normalmente.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.evoluaColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Toque para responder ao exercício...',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar resposta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTtsPlayer extends StatefulWidget {
  const _StepTtsPlayer({required this.step});

  final TrailJourneyStep step;

  @override
  State<_StepTtsPlayer> createState() => _StepTtsPlayerState();
}

class _StepTtsPlayerState extends State<_StepTtsPlayer> {
  late final FlutterTts _tts;
  double _speed = 1;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _speaking = false);
      }
    });
    _tts.setErrorHandler((_) {
      if (mounted) {
        setState(() => _speaking = false);
      }
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak() async {
    await _tts.setLanguage(_languageForStep());
    await _tts.setSpeechRate(_speechRateForSpeed(_speed));
    await _tts.speak(_ttsText());
    if (mounted) {
      setState(() => _speaking = true);
    }
  }

  Future<void> _pause() async {
    await _tts.pause();
    if (mounted) {
      setState(() => _speaking = false);
    }
  }

  Future<void> _stop() async {
    await _tts.stop();
    if (mounted) {
      setState(() => _speaking = false);
    }
  }

  String _languageForStep() {
    final text = _ttsText().toLowerCase();
    final englishHints = [' the ', ' and ', ' you ', ' your ', ' today '];
    return englishHints.any(text.contains) ? 'en-US' : 'pt-BR';
  }

  double _speechRateForSpeed(double speed) {
    return switch (speed) {
      0.75 => 0.38,
      1.25 => 0.58,
      1.5 => 0.68,
      _ => 0.48,
    };
  }

  String _ttsText() {
    return '${widget.step.title}. ${widget.step.summary}. ${widget.step.content}'
        .replaceAll(RegExp(r'[#*_`\[\]\(\)>-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.22),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: _speaking ? null : _speak,
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('Ouvir'),
          ),
          OutlinedButton.icon(
            onPressed: _speaking ? _pause : null,
            icon: const Icon(Icons.pause_rounded),
            label: const Text('Pausar'),
          ),
          OutlinedButton.icon(
            onPressed: _speaking ? _stop : null,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Parar'),
          ),
          SegmentedButton<double>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0.75, label: Text('0.75x')),
              ButtonSegment(value: 1, label: Text('1x')),
              ButtonSegment(value: 1.25, label: Text('1.25x')),
              ButtonSegment(value: 1.5, label: Text('1.5x')),
            ],
            selected: {_speed},
            onSelectionChanged: (value) async {
              final next = value.first;
              setState(() => _speed = next);
              if (_speaking) {
                await _stop();
                await _speak();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _JourneyVideoPlayer extends StatelessWidget {
  const _JourneyVideoPlayer({required this.trailId, required this.step});

  final int trailId;
  final TrailJourneyStep step;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _JourneyIframeVideoPlayer(trailId: trailId, step: step);
    }
    return _JourneyMobileVideoPlayer(trailId: trailId, step: step);
  }
}

class _JourneyIframeVideoPlayer extends ConsumerStatefulWidget {
  const _JourneyIframeVideoPlayer({required this.trailId, required this.step});

  final int trailId;
  final TrailJourneyStep step;

  @override
  ConsumerState<_JourneyIframeVideoPlayer> createState() =>
      _JourneyIframeVideoPlayerState();
}

class _JourneyIframeVideoPlayerState
    extends ConsumerState<_JourneyIframeVideoPlayer> {
  ytw.YoutubePlayerController? _controller;
  Timer? _progressTimer;
  double _speed = 1;
  int _lastSentPercent = -1;

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controller?.close();
    super.dispose();
  }

  String? _effectiveVideoId() {
    return widget.step.video?.videoId ??
        _extractYoutubeId(widget.step.video?.url);
  }

  ytw.YoutubePlayerController _createController(String videoId) {
    return ytw.YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const ytw.YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        playsInline: true,
      ),
    );
  }

  Future<void> _startInlinePlayback() async {
    final videoId = _effectiveVideoId();
    if (videoId == null || videoId.isEmpty) {
      return;
    }
    final controller = _controller ?? _createController(videoId);
    setState(() => _controller = controller);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) {
      return;
    }
    await controller.setPlaybackRate(_speed);
    await controller.playVideo();
    _startProgressTimer();
  }

  Future<void> _play() async {
    final controller = _controller;
    if (controller == null) {
      await _startInlinePlayback();
      return;
    }
    await controller.setPlaybackRate(_speed);
    await controller.playVideo();
    _startProgressTimer();
  }

  Future<void> _pause() async {
    await _controller?.pauseVideo();
    await _sendProgress(force: true);
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    await _controller?.setPlaybackRate(speed);
  }

  void _startProgressTimer() {
    _progressTimer ??= Timer.periodic(
      const Duration(seconds: 8),
      (_) => _sendProgress(),
    );
  }

  Future<void> _sendProgress({bool force = false}) async {
    final controller = _controller;
    final declaredDuration = widget.step.video?.durationSeconds;
    if (controller == null ||
        declaredDuration == null ||
        declaredDuration <= 0) {
      return;
    }
    final watched = (await controller.currentTime).round().clamp(
      0,
      declaredDuration,
    );
    await _sendVideoProgress(
      ref: ref,
      trailId: widget.trailId,
      stepIndex: widget.step.index,
      watchedSeconds: watched,
      durationSeconds: declaredDuration,
      lastSentPercent: _lastSentPercent,
      force: force,
      onPercentSent: (percent) => _lastSentPercent = percent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final video = widget.step.video;
    if (video == null || _effectiveVideoId() == null) {
      return _VideoUnavailableCard(thumbnailUrl: video?.thumbnailUrl);
    }
    if (controller == null) {
      return _VideoStartCard(
        thumbnailUrl: video.thumbnailUrl,
        onStart: _startInlinePlayback,
      );
    }

    return _VideoShell(
      progress: widget.step.videoProgress,
      controls: _VideoControls(
        speed: _speed,
        onPlay: _play,
        onPause: _pause,
        onFullscreen: () => controller.toggleFullScreen(),
        onSpeedChanged: _setSpeed,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ytw.YoutubePlayer(controller: controller, aspectRatio: 16 / 9),
      ),
    );
  }
}

class _JourneyMobileVideoPlayer extends ConsumerStatefulWidget {
  const _JourneyMobileVideoPlayer({required this.trailId, required this.step});

  final int trailId;
  final TrailJourneyStep step;

  @override
  ConsumerState<_JourneyMobileVideoPlayer> createState() =>
      _JourneyMobileVideoPlayerState();
}

class _JourneyMobileVideoPlayerState
    extends ConsumerState<_JourneyMobileVideoPlayer> {
  ytm.YoutubePlayerController? _controller;
  Timer? _progressTimer;
  double _speed = 1;
  int _lastSentPercent = -1;
  bool _hasPlayerError = false;

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  String? _effectiveVideoId() {
    return widget.step.video?.videoId ??
        _extractYoutubeId(widget.step.video?.url);
  }

  ytm.YoutubePlayerController _createController(String videoId) {
    return ytm.YoutubePlayerController(
      initialVideoId: videoId,
      flags: const ytm.YoutubePlayerFlags(
        autoPlay: false,
        hideControls: false,
        controlsVisibleAtStart: true,
        enableCaption: true,
        useHybridComposition: true,
      ),
    )..addListener(_handleControllerValue);
  }

  void _handleControllerValue() {
    final controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    final hasError = controller.value.hasError;
    if (hasError != _hasPlayerError) {
      setState(() => _hasPlayerError = hasError);
    }
  }

  Future<void> _startInlinePlayback() async {
    final videoId = _effectiveVideoId();
    if (videoId == null || videoId.isEmpty) {
      return;
    }
    final controller = _controller ?? _createController(videoId);
    setState(() => _controller = controller);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || !controller.value.isReady) {
      return;
    }
    controller.setPlaybackRate(_speed);
    controller.play();
    _startProgressTimer();
  }

  Future<void> _play() async {
    final controller = _controller;
    if (controller == null) {
      await _startInlinePlayback();
      return;
    }
    if (!controller.value.isReady) {
      return;
    }
    controller.setPlaybackRate(_speed);
    controller.play();
    _startProgressTimer();
  }

  Future<void> _pause() async {
    _controller?.pause();
    await _sendProgress(force: true);
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    final controller = _controller;
    if (controller != null && controller.value.isReady) {
      controller.setPlaybackRate(speed);
    }
  }

  void _startProgressTimer() {
    _progressTimer ??= Timer.periodic(
      const Duration(seconds: 8),
      (_) => _sendProgress(),
    );
  }

  Future<void> _sendProgress({bool force = false}) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final declaredDuration = widget.step.video?.durationSeconds;
    final duration = declaredDuration != null && declaredDuration > 0
        ? declaredDuration
        : controller.metadata.duration.inSeconds;
    if (duration <= 0) {
      return;
    }
    final watched = controller.value.position.inSeconds.clamp(0, duration);
    await _sendVideoProgress(
      ref: ref,
      trailId: widget.trailId,
      stepIndex: widget.step.index,
      watchedSeconds: watched,
      durationSeconds: duration,
      lastSentPercent: _lastSentPercent,
      force: force,
      onPercentSent: (percent) => _lastSentPercent = percent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final video = widget.step.video;
    if (video == null || _effectiveVideoId() == null) {
      return _VideoUnavailableCard(thumbnailUrl: video?.thumbnailUrl);
    }
    if (controller == null) {
      return _VideoStartCard(
        thumbnailUrl: video.thumbnailUrl,
        onStart: _startInlinePlayback,
      );
    }
    if (_hasPlayerError) {
      return _VideoErrorCard(thumbnailUrl: video.thumbnailUrl);
    }

    return _VideoShell(
      progress: widget.step.videoProgress,
      controls: _VideoControls(
        speed: _speed,
        onPlay: _play,
        onPause: _pause,
        onFullscreen: () => controller.toggleFullScreenMode(),
        onSpeedChanged: _setSpeed,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ytm.YoutubePlayer(
          controller: controller,
          aspectRatio: 16 / 9,
          showVideoProgressIndicator: true,
          bottomActions: const [
            ytm.CurrentPosition(),
            ytm.ProgressBar(isExpanded: true),
            ytm.RemainingDuration(),
          ],
        ),
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.speed,
    required this.onPlay,
    required this.onPause,
    required this.onFullscreen,
    required this.onSpeedChanged,
  });

  final double speed;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onFullscreen;
  final ValueChanged<double> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Play'),
        ),
        OutlinedButton.icon(
          onPressed: onPause,
          icon: const Icon(Icons.pause_rounded),
          label: const Text('Pause'),
        ),
        OutlinedButton.icon(
          onPressed: onFullscreen,
          icon: const Icon(Icons.fullscreen_rounded),
          label: const Text('Tela cheia'),
        ),
        SegmentedButton<double>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 1, label: Text('1x')),
            ButtonSegment(value: 1.25, label: Text('1.25x')),
            ButtonSegment(value: 1.5, label: Text('1.5x')),
          ],
          selected: {speed},
          onSelectionChanged: (value) => onSpeedChanged(value.first),
        ),
      ],
    );
  }
}

class _VideoStartCard extends StatelessWidget {
  const _VideoStartCard({this.thumbnailUrl, required this.onStart});

  final String? thumbnailUrl;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _VideoPlaceholderCard(
      thumbnailUrl: thumbnailUrl,
      overlay: FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Assistir etapa'),
      ),
      message: 'O vídeo será reproduzido dentro desta etapa.',
    );
  }
}

class _VideoUnavailableCard extends StatelessWidget {
  const _VideoUnavailableCard({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return _VideoPlaceholderCard(
      thumbnailUrl: thumbnailUrl,
      overlay: Icon(
        Icons.videocam_off_rounded,
        size: 42,
        color: context.evoluaColors.textPrimary,
      ),
      message: 'Vídeo indisponível nesta etapa.',
    );
  }
}

class _VideoErrorCard extends StatelessWidget {
  const _VideoErrorCard({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return _VideoPlaceholderCard(
      thumbnailUrl: thumbnailUrl,
      overlay: Icon(
        Icons.error_outline_rounded,
        size: 42,
        color: context.evoluaColors.textPrimary,
      ),
      message:
          'Não foi possível reproduzir este vídeo dentro do app. Verifique se o vídeo permite incorporação no YouTube.',
    );
  }
}

class _VideoPlaceholderCard extends StatelessWidget {
  const _VideoPlaceholderCard({
    required this.thumbnailUrl,
    required this.overlay,
    required this.message,
  });

  final String? thumbnailUrl;
  final Widget overlay;
  final String message;

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  if (hasThumbnail)
                    Image.network(thumbnailUrl!, fit: BoxFit.cover)
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.evoluaColors.surfaceStrong,
                      ),
                      child: Icon(
                        Icons.ondemand_video_rounded,
                        size: 52,
                        color: context.evoluaColors.textSecondary,
                      ),
                    ),
                  ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
                  overlay,
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.evoluaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoShell extends StatelessWidget {
  const _VideoShell({
    required this.child,
    required this.controls,
    required this.progress,
  });

  final Widget child;
  final Widget controls;
  final TrailStepVideoProgress? progress;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          const SizedBox(height: 12),
          controls,
          if (progress != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress.watchedPercent / 100),
            const SizedBox(height: 6),
            Text(
              progress.completed
                  ? 'Vídeo assistido. Continue com a reflexão abaixo.'
                  : '${progress.watchedPercent}% assistido',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.evoluaColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _sendVideoProgress({
  required WidgetRef ref,
  required int trailId,
  required int stepIndex,
  required int watchedSeconds,
  required int durationSeconds,
  required int lastSentPercent,
  required bool force,
  required ValueChanged<int> onPercentSent,
}) async {
  final percent = ((watchedSeconds * 100) / durationSeconds).round().clamp(
    0,
    100,
  );
  if (!force && percent < 90 && percent < lastSentPercent + 10) {
    return;
  }
  onPercentSent(percent);
  await ref
      .read(trailJourneyActionProvider)
      .updateVideoProgress(
        trailId: trailId,
        stepIndex: stepIndex,
        watchedSeconds: watchedSeconds,
        durationSeconds: durationSeconds,
      );
}

String? _extractYoutubeId(String? url) {
  if (url == null || url.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (host.contains('youtu.be')) {
    return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  }
  if (host.contains('youtube.com')) {
    final queryId = uri.queryParameters['v'];
    if (queryId != null && queryId.isNotEmpty) {
      return queryId;
    }
    final embedIndex = uri.pathSegments.indexOf('embed');
    if (embedIndex >= 0 && uri.pathSegments.length > embedIndex + 1) {
      return uri.pathSegments[embedIndex + 1];
    }
  }
  return null;
}

String _journeyCtaLabel(TrailJourney journey) {
  if (journey.isCompleted) {
    return 'Revisar trilha';
  }
  if (!journey.isStarted) {
    return 'Iniciar trilha';
  }
  return 'Fazer próxima etapa';
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

String _resultCountLabel(int totalItems) {
  if (totalItems == 1) {
    return '1 trilha encontrada';
  }
  return '$totalItems trilhas encontradas';
}

String _emptyStateTitle({
  required bool? premiumFilter,
  required String search,
}) {
  final hasSearch = search.trim().length >= 4;
  if (hasSearch) {
    return 'Nenhuma trilha encontrada para essa busca.';
  }
  if (premiumFilter == true) {
    return 'Novas trilhas premium em breve.';
  }
  if (premiumFilter == false) {
    return 'Novas trilhas essenciais em breve.';
  }
  return 'Novas trilhas serão adicionadas em breve.';
}

String _emptyStateSubtitle({
  required bool? premiumFilter,
  required String search,
}) {
  final hasSearch = search.trim().length >= 4;
  if (hasSearch) {
    return 'Tente outro termo ou limpe os filtros para ampliar sua descoberta.';
  }
  if (premiumFilter == true) {
    return 'Enquanto isso, continue nas trilhas essenciais ou volte mais tarde para novas experiências premium.';
  }
  if (premiumFilter == false) {
    return 'Em breve, novas trilhas gratuitas estarão disponíveis para continuar sua evolução.';
  }
  return 'O catálogo está sendo preparado. Volte em breve para descobrir novas trilhas.';
}

String _stepTypeLabel(String type) {
  return switch (type.toUpperCase()) {
    'EXERCISE' => 'Exercício',
    'READING' => 'Leitura',
    'VIDEO' => 'Vídeo',
    'AUDIO' => 'Áudio',
    'RITUAL' => 'Ritual',
    'AI' => 'IA guiada',
    'CHECKPOINT' => 'Checkpoint',
    _ => 'Reflexão',
  };
}

bool _supportsStepResponse(String type) {
  return switch (type.toUpperCase()) {
    'EXERCISE' || 'REFLECTION' => true,
    _ => false,
  };
}

bool _isMentorPremiumTrail(Trail trail) {
  final category = trail.category.trim().toLowerCase();
  final sourceStyle = trail.sourceStyle?.trim().toLowerCase() ?? '';
  return trail.premium &&
      (category == 'mentoria' || sourceStyle == 'mentor_exclusive');
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: _JourneyStepDetailCard(
              trailId: widget.journey.trail.id,
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

class _TrailExplorer extends ConsumerWidget {
  const _TrailExplorer({
    required this.result,
    required this.hasPremiumAccess,
    required this.searchController,
    required this.premiumFilter,
    required this.searchHelperText,
    required this.onSearchChanged,
    required this.onPremiumFilterChanged,
    required this.onClearFilters,
    required this.onOpenTrail,
    required this.onOpenPremium,
    required this.onPageChanged,
  });

  final PaginatedResponse<Trail> result;
  final bool hasPremiumAccess;
  final TextEditingController searchController;
  final bool? premiumFilter;
  final String? searchHelperText;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool?> onPremiumFilterChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<Trail> onOpenTrail;
  final VoidCallback? onOpenPremium;
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
                'Catálogo de trilhas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.evoluaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Descubra trilhas por tema, formato e profundidade. Use a busca quando quiser encontrar um caminho específico.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Text(
                _resultCountLabel(result.totalItems),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  labelText: 'Buscar por título, tema ou resumo',
                  helperText: searchHelperText,
                  prefixIcon: const Icon(Icons.search_rounded),
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
            title: _emptyStateTitle(
              premiumFilter: premiumFilter,
              search: searchController.text,
            ),
            subtitle: _emptyStateSubtitle(
              premiumFilter: premiumFilter,
              search: searchController.text,
            ),
            actionLabel: 'Ver todas as trilhas',
            onAction: onClearFilters,
          )
        else
          Column(
            children: [
              ...result.items.map((trail) {
                final effectiveAccessible = trail.premium
                    ? hasPremiumAccess
                    : trail.accessible;
                final lockedMentorTrail =
                    _isMentorPremiumTrail(trail) && !hasPremiumAccess;
                final journeyState = effectiveAccessible
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
                                    '${journeyState!.requireValue.progressPercent}% concluído',
                                color: context.evoluaColors.textSecondary,
                              ),
                            if (!effectiveAccessible && !hasPremiumAccess) ...[
                              _StatusBadge(
                                label: lockedMentorTrail
                                    ? 'Mentoria premium'
                                    : 'Faça upgrade para acessar',
                                color: AppColors.danger,
                              ),
                              if (lockedMentorTrail)
                                const _StatusBadge(
                                  label: 'Premium',
                                  color: AppColors.accentGold,
                                ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (effectiveAccessible)
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
                                onPressed: effectiveAccessible
                                    ? () => onOpenTrail(trail)
                                    : () => _showTrailDetails(
                                        context,
                                        trail,
                                        accessible: effectiveAccessible,
                                        lockedMentorTrail: lockedMentorTrail,
                                      ),
                                icon: const Icon(Icons.visibility_rounded),
                                label: Text(
                                  effectiveAccessible
                                      ? 'Ver caminho'
                                      : 'Ver detalhes',
                                ),
                              ),
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

  void _showTrailDetails(
    BuildContext context,
    Trail trail, {
    required bool accessible,
    required bool lockedMentorTrail,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          return StatefulBuilder(
            builder: (context, setDialogState) => Dialog(
              backgroundColor: context.evoluaColors.backgroundSecondary,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 760,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                ),
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
                                  ?.copyWith(
                                    color: context.evoluaColors.textPrimary,
                                  ),
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
                          child: accessible
                              ? _UnlockedTrailDetails(trail: trail)
                              : SoftPremiumPrompt(
                                  icon: Icons.auto_stories_rounded,
                                  title: lockedMentorTrail
                                      ? 'Mentoria disponível no Premium'
                                      : 'Esta trilha aprofunda sua evolução emocional',
                                  message: lockedMentorTrail
                                      ? 'O Mentor Evolua e as trilhas de mentoria ficam no Premium para manter uma experiência profunda, contínua e sem anúncios.'
                                      : 'Você pode visualizar o resumo da trilha agora. O conteúdo completo fica no Premium para apoiar sua trilha com mais contexto, sem anúncios e sem pressão.',
                                  benefit:
                                      'Premium libera trilhas premium, Espelho da Evolução completo, histórico completo e insights avançados.',
                                  primaryLabel: 'Aprofundar com Premium',
                                  secondaryLabel: 'Continuar vendo o resumo',
                                  onOpenPremium: onOpenPremium == null
                                      ? null
                                      : () {
                                          Navigator.of(context).pop();
                                          onOpenPremium?.call();
                                        },
                                  onSecondary: () =>
                                      Navigator.of(context).pop(),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UnlockedTrailDetails extends StatelessWidget {
  const _UnlockedTrailDetails({required this.trail});

  final Trail trail;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
            h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
            h2: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
            listBullet: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.accent),
          ),
        ),
        if (trail.mediaLinks.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Conteúdos de apoio',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    color: context.evoluaColors.surfaceStrong.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: context.evoluaColors.outline.withValues(
                        alpha: 0.4,
                      ),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.label,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: context.evoluaColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              link.url,
                              style: Theme.of(context).textTheme.bodySmall,
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
