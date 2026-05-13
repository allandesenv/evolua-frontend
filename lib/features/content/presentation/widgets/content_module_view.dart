import 'dart:async';

import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/subscription/application/mentor_premium_pass_reward_service.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/panel_skeleton.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

enum ContentModuleSection { journey, catalog }

class ContentModuleView extends ConsumerStatefulWidget {
  const ContentModuleView({
    super.key,
    this.section = ContentModuleSection.journey,
    this.showSectionChips = true,
    this.onOpenMentor,
    this.onOpenPremium,
  });

  final ContentModuleSection section;
  final bool showSectionChips;
  final VoidCallback? onOpenMentor;
  final VoidCallback? onOpenPremium;

  @override
  ConsumerState<ContentModuleView> createState() => _ContentModuleViewState();
}

class _ContentModuleViewState extends ConsumerState<ContentModuleView> {
  final _searchController = TextEditingController();
  bool? _premiumFilter;
  Trail? _selectedCatalogTrail;
  late ContentModuleSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.section;
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
    _searchController.dispose();
    super.dispose();
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
    final mentorPremiumPassActive =
        currentSubscription?.mentorPremiumPassActive ?? false;

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
                    hasPremiumAccess: hasPremiumAccess,
                    mentorPremiumPassActive: mentorPremiumPassActive,
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
                    onOpenPremium: widget.onOpenPremium,
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
              label: 'Explorar',
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
          'Trilha de ${_categoryLabel(trail.category)}',
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
            _StatusBadge(label: 'Jornada guiada', color: activeColor),
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
        ],
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

class _JourneyVideoPlayer extends ConsumerStatefulWidget {
  const _JourneyVideoPlayer({required this.trailId, required this.step});

  final int trailId;
  final TrailJourneyStep step;

  @override
  ConsumerState<_JourneyVideoPlayer> createState() =>
      _JourneyVideoPlayerState();
}

class _JourneyVideoPlayerState extends ConsumerState<_JourneyVideoPlayer> {
  YoutubePlayerController? _controller;
  Timer? _progressTimer;
  double _speed = 1;
  bool _started = false;
  int _lastSentPercent = -1;

  @override
  void initState() {
    super.initState();
    final videoId = _effectiveVideoId();
    if (videoId != null && videoId.isNotEmpty) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: false,
          showFullscreenButton: false,
          playsInline: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controller?.close();
    super.dispose();
  }

  String? _effectiveVideoId() {
    return widget.step.video?.videoId ?? _extractYoutubeId(widget.step.video?.url);
  }

  Future<void> _play() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    setState(() => _started = true);
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
    if (controller == null || declaredDuration == null || declaredDuration <= 0) {
      return;
    }
    final watched = (await controller.currentTime).round().clamp(0, declaredDuration);
    final percent = ((watched * 100) / declaredDuration).round().clamp(0, 100);
    if (!force && percent < 90 && percent < _lastSentPercent + 10) {
      return;
    }
    _lastSentPercent = percent;
    await ref.read(trailJourneyActionProvider).updateVideoProgress(
          trailId: widget.trailId,
          stepIndex: widget.step.index,
          watchedSeconds: watched,
          durationSeconds: declaredDuration,
        );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final video = widget.step.video;
    if (controller == null || video == null) {
      return _VideoUnavailableCard(url: video?.url);
    }

    final progress = widget.step.videoProgress;
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
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                YoutubePlayer(controller: controller, aspectRatio: 16 / 9),
                if (!_started && video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty)
                  Positioned.fill(
                    child: Image.network(video.thumbnailUrl!, fit: BoxFit.cover),
                  ),
                if (!_started)
                  FilledButton.icon(
                    onPressed: _play,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Assistir etapa'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _play,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play'),
              ),
              OutlinedButton.icon(
                onPressed: _pause,
                icon: const Icon(Icons.pause_rounded),
                label: const Text('Pause'),
              ),
              OutlinedButton.icon(
                onPressed: () => controller.toggleFullScreen(),
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
                selected: {_speed},
                onSelectionChanged: (value) => _setSpeed(value.first),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress.watchedPercent / 100),
            const SizedBox(height: 6),
            Text(
              progress.completed
                  ? 'Video assistido. Continue com a reflexao abaixo.'
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

class _VideoUnavailableCard extends StatelessWidget {
  const _VideoUnavailableCard({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: url == null || url!.isEmpty ? null : () => launchUrlString(url!),
      icon: const Icon(Icons.ondemand_video_rounded),
      label: const Text('Abrir video da etapa'),
    );
  }
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

String _stepTypeLabel(String type) {
  return switch (type.toUpperCase()) {
    'EXERCISE' => 'Exercicio',
    'READING' => 'Leitura',
    'VIDEO' => 'Video',
    'AUDIO' => 'Audio',
    'RITUAL' => 'Ritual',
    'AI' => 'IA guiada',
    'CHECKPOINT' => 'Checkpoint',
    _ => 'Reflexao',
  };
}

bool _isMentorPremiumTrail(Trail trail) {
  final category = trail.category.trim().toLowerCase();
  final sourceStyle = trail.sourceStyle?.trim().toLowerCase() ?? '';
  return trail.premium &&
      (category == 'mentoria' || sourceStyle == 'mentor_exclusive');
}

bool _isLockedMentorPremiumTrail(Trail trail) {
  return _isMentorPremiumTrail(trail) && !trail.accessible;
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
    required this.mentorPremiumPassActive,
    required this.searchController,
    required this.premiumFilter,
    required this.onSearchChanged,
    required this.onPremiumFilterChanged,
    required this.onOpenTrail,
    required this.onOpenPremium,
    required this.onPageChanged,
  });

  final PaginatedResponse<Trail> result;
  final bool hasPremiumAccess;
  final bool mentorPremiumPassActive;
  final TextEditingController searchController;
  final bool? premiumFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool?> onPremiumFilterChanged;
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
                final effectiveAccessible =
                    trail.accessible ||
                    (mentorPremiumPassActive && _isMentorPremiumTrail(trail));
                final lockedMentorTrail =
                    _isLockedMentorPremiumTrail(trail) &&
                    !mentorPremiumPassActive &&
                    !hasPremiumAccess;
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
                                    '${journeyState!.requireValue.progressPercent}% concluido',
                                color: context.evoluaColors.textSecondary,
                              ),
                            if (!effectiveAccessible && !hasPremiumAccess) ...[
                              _StatusBadge(
                                label: lockedMentorTrail
                                    ? 'Mentoria premium'
                                    : 'Faca upgrade para acessar',
                                color: AppColors.danger,
                              ),
                              if (lockedMentorTrail)
                                const _StatusBadge(
                                  label: 'Anuncio libera hoje',
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
    required bool lockedMentorTrail,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          var isRewardLoading = false;
          String? rewardStatusMessage;

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
                          child: trail.accessible
                              ? _UnlockedTrailDetails(trail: trail)
                              : lockedMentorTrail
                              ? _LockedMentorTrailState(
                                  isRewardLoading: isRewardLoading,
                                  onWatchAd: () async {
                                    if (isRewardLoading) {
                                      return;
                                    }
                                    setDialogState(() {
                                      isRewardLoading = true;
                                      rewardStatusMessage = null;
                                    });
                                    try {
                                      final result = await ref
                                          .read(
                                            mentorPremiumPassRewardServiceProvider,
                                          )
                                          .watchAdAndConfirm(
                                            trailId: trail.id,
                                            onAwaitingConfirmation: () {
                                              if (!context.mounted) {
                                                return;
                                              }
                                              setDialogState(() {
                                                rewardStatusMessage =
                                                    'Estamos confirmando seu passe de mentoria...';
                                              });
                                            },
                                          );
                                      if (!context.mounted) {
                                        return;
                                      }
                                      if (result.confirmed) {
                                        AppSnackBar.show(
                                          context,
                                          message:
                                              'Passe de mentoria liberado por hoje.',
                                          icon: Icons.workspace_premium_rounded,
                                        );
                                        Navigator.of(context).pop();
                                      } else {
                                        final message =
                                            result.status ==
                                                MentorPremiumPassRewardStatus
                                                    .unavailable
                                            ? 'Anuncio indisponivel neste dispositivo. Voce ainda pode assinar Premium.'
                                            : 'O anuncio foi concluido, mas ainda nao recebemos a confirmacao. Toque em Atualizar em instantes.';
                                        setDialogState(() {
                                          rewardStatusMessage = message;
                                        });
                                        AppSnackBar.show(
                                          context,
                                          message: message,
                                          icon: Icons.workspace_premium_rounded,
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setDialogState(
                                          () => isRewardLoading = false,
                                        );
                                      }
                                    }
                                  },
                                  statusMessage: rewardStatusMessage,
                                  onOpenPremium: onOpenPremium == null
                                      ? null
                                      : () {
                                          Navigator.of(context).pop();
                                          onOpenPremium?.call();
                                        },
                                )
                              : GuidedEmptyState(
                                  icon: Icons.workspace_premium_rounded,
                                  title:
                                      'Conteudo completo liberado no premium',
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
            'Conteudos de apoio',
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

class _LockedMentorTrailState extends StatelessWidget {
  const _LockedMentorTrailState({
    required this.isRewardLoading,
    required this.onWatchAd,
    required this.statusMessage,
    required this.onOpenPremium,
  });

  final bool isRewardLoading;
  final VoidCallback onWatchAd;
  final String? statusMessage;
  final VoidCallback? onOpenPremium;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.accent,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Libere esta mentoria por hoje',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Assista a um anuncio premiado para acessar trilhas de mentoria ate o fim do dia, ou assine Premium para acesso completo.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.evoluaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: isRewardLoading ? null : onWatchAd,
            icon: isRewardLoading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ondemand_video_rounded),
            label: Text(
              isRewardLoading
                  ? 'Carregando anuncio'
                  : 'Assistir anuncio para liberar mentoria por hoje',
            ),
          ),
          if (onOpenPremium != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onOpenPremium,
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('Assinar Premium'),
            ),
          ],
          if (statusMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              statusMessage!,
              textAlign: TextAlign.center,
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
