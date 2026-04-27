import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/content/application/journey_chat_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_message.dart';
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
  });

  final ContentModuleSection section;
  final bool showSectionChips;

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

    await ref
        .read(trailControllerProvider.notifier)
        .create(
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim(),
          content: _contentController.text.trim(),
          category: _categoryController.text.trim(),
          premium: _premium,
          mediaLinks: _buildMediaLinks(),
        );

    if (!mounted) {
      return;
    }

    _titleController.clear();
    _summaryController.clear();
    _contentController.clear();
    _categoryController.text = 'ansiedade';
    setState(() {
      _premium = false;
      for (final link in _mediaLinks) {
        link.dispose();
      }
      _mediaLinks
        ..clear()
        ..add(_EditableMediaLink.live());
    });
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

    return Column(
      children: [
        if (isAdmin) ...[
          PrimaryPanel(
            child: _AdminTrailEditor(
              formKey: _formKey,
              titleController: _titleController,
              summaryController: _summaryController,
              contentController: _contentController,
              categoryController: _categoryController,
              premium: _premium,
              onPremiumChanged: (value) => setState(() => _premium = value),
              mediaLinks: _mediaLinks,
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
              onSubmit: isSaving ? null : _submit,
            ),
          ),
          const SizedBox(height: 16),
        ],
        currentJourney.when(
          data: (trail) => trail == null ||
                  (_section == ContentModuleSection.catalog &&
                      _selectedCatalogTrail != null)
              ? const SizedBox.shrink()
              : _section == ContentModuleSection.catalog
              ? _CurrentJourneyBanner(
                  trail: trail,
                  onOpenJourney: () =>
                      setState(() => _section = ContentModuleSection.journey),
                )
              : _CurrentJourneyPanel(trail: trail),
          error: (_, _) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        ),
        if (_section == ContentModuleSection.catalog ||
            currentJourney.asData?.value == null) ...[
          const SizedBox(height: 16),
          if (_section == ContentModuleSection.catalog &&
              _selectedCatalogTrail != null)
            _CatalogJourneyPanel(
              trail: _selectedCatalogTrail!,
              onBack: () => setState(() => _selectedCatalogTrail = null),
            )
          else
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
      ],
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
                    color: AppColors.textPrimary,
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
  const _CurrentJourneyPanel({required this.trail});

  final Trail trail;

  @override
  ConsumerState<_CurrentJourneyPanel> createState() => _CurrentJourneyPanelState();
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
  });

  final Trail trail;
  final VoidCallback onBack;

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
  });

  final TrailJourney journey;
  final bool isActing;
  final VoidCallback onPrimaryAction;
  final bool isCatalogTrail;
  final VoidCallback? onBackToCatalog;

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveBreakpoints.isCompact(context);
    final activeColor = _journeyAccentColor(journey.trail);
    final nextStep = journey.nextStep;

    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JourneyHeader(
            journey: journey,
            activeColor: activeColor,
            isCatalogTrail: isCatalogTrail,
            onBackToCatalog: onBackToCatalog,
            onOpenFullJourney: () => _showJourneyDetails(context, journey.trail),
          ),
          const SizedBox(height: 18),
          _JourneyProgressSummary(journey: journey, activeColor: activeColor),
          const SizedBox(height: 18),
          if (compact)
            _JourneyTimeline(
              journey: journey,
              activeColor: activeColor,
              onStepTap: (step) => _showStepSheet(context, journey, step),
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
                    onStepTap: (step) => _showStepSheet(context, journey, step),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isActing || journey.steps.isEmpty ? null : onPrimaryAction,
              icon: isActing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(journey.isCompleted
                      ? Icons.replay_rounded
                      : journey.isStarted
                          ? Icons.task_alt_rounded
                          : Icons.play_arrow_rounded),
              label: Text(_journeyCtaLabel(journey)),
            ),
          ),
          const SizedBox(height: 18),
          _JourneyChatCard(trail: journey.trail),
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
  });

  final TrailJourney journey;
  final Color activeColor;
  final VoidCallback onOpenFullJourney;
  final bool isCatalogTrail;
  final VoidCallback? onBackToCatalog;

  @override
  Widget build(BuildContext context) {
    final trail = journey.trail;
    final compact = ResponsiveBreakpoints.isCompact(context);
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
              const _StatusBadge(label: 'IA ativa', color: AppColors.accentGold),
            _StatusBadge(
              label: '${journey.steps.length} etapas',
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ],
    );
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
        OutlinedButton.icon(
          onPressed: onOpenFullJourney,
          icon: const Icon(Icons.auto_stories_rounded),
          label: Text(isCatalogTrail ? 'Conteudo completo' : 'Jornada completa'),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          info,
          const SizedBox(height: 14),
          actions,
        ],
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
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              Text(
                '${journey.completedSteps}/${journey.steps.length} etapas',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
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
              backgroundColor: AppColors.surfaceStrong.withValues(alpha: 0.5),
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
    final nodeColor = step.isCompleted || step.isCurrent ? activeColor : AppColors.outline;
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
                      : AppColors.surfaceStrong.withValues(alpha: 0.9),
                  border: Border.all(color: nodeColor, width: step.isCurrent ? 2 : 1),
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
                  color: step.isCompleted ? AppColors.background : nodeColor,
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
                        AppColors.outline.withValues(alpha: 0.14),
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
                          color: step.isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: step.isCurrent ? FontWeight.w700 : FontWeight.w500,
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
        color: AppColors.surfaceStrong.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: activeColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCompleted ? 'Jornada concluida' : 'Proximo passo',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: activeColor),
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
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
              listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: activeColor,
                  ),
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
    backgroundColor: AppColors.backgroundSecondary,
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

class _JourneyChatCard extends ConsumerStatefulWidget {
  const _JourneyChatCard({required this.trail});

  final Trail trail;

  @override
  ConsumerState<_JourneyChatCard> createState() => _JourneyChatCardState();
}

class _JourneyChatCardState extends ConsumerState<_JourneyChatCard> {
  final _messageController = TextEditingController();
  final List<JourneyChatMessage> _messages = const [
    JourneyChatMessage(
      role: 'assistant',
      content:
          'Estou aqui para conversar sobre sua jornada. Me conte onde voce travou ou qual exercicio quer adaptar para hoje.',
    ),
  ].toList();
  bool _isSending = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
      _messages.add(JourneyChatMessage(role: 'user', content: text));
      _messageController.clear();
    });

    try {
      final reply = await ref
          .read(journeyChatControllerProvider)
          .send(
            message: text,
            conversationHistory: _messages.length > 6
                ? _messages.sublist(_messages.length - 6)
                : List.of(_messages),
            trailId: widget.trail.id,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          JourneyChatMessage(
            role: 'assistant',
            content:
                '${reply.reply}\n\nProximo passo: ${reply.suggestedNextStep}',
          ),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is DioException
          ? (error.response?.data is Map<String, dynamic>
                ? (error.response?.data['message']?.toString() ??
                      error.message ??
                      'Nao conseguimos responder agora.')
                : error.message ?? 'Nao conseguimos responder agora.')
          : 'Nao conseguimos responder agora.';
      setState(() => _error = message);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversar sobre minha jornada',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'A IA usa a trilha ativa como contexto e responde com passos pequenos, sem substituir apoio profissional.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: Column(
                children: _messages
                    .map(
                      (message) => Align(
                        alignment: message.role == 'user'
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: message.role == 'user'
                                ? AppColors.accent.withValues(alpha: 0.16)
                                : AppColors.surface.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.outline.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            message.content,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 3,
                  enabled: !_isSending,
                  decoration: const InputDecoration(
                    labelText: 'Pergunte ou peça uma adaptacao',
                    hintText:
                        'Ex: como eu faco esse exercicio com pouco tempo?',
                    prefixIcon: Icon(Icons.forum_rounded),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _isSending ? null : _send,
                icon: _isSending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showJourneyDetails(BuildContext context, Trail trail) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.backgroundSecondary,
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
                          ?.copyWith(color: AppColors.textPrimary),
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
                                  ?.copyWith(color: AppColors.textPrimary),
                              h1: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(color: AppColors.textPrimary),
                              h2: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: AppColors.textPrimary),
                              listBullet: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.accent),
                            ),
                      ),
                      if (trail.mediaLinks.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Links curados',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.textPrimary),
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
    required this.onAddLink,
    required this.onRemoveLink,
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
  final VoidCallback onAddLink;
  final ValueChanged<int> onRemoveLink;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
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
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Criar trilha'),
            ),
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
        color: AppColors.surfaceStrong.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
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
              ...result.items.map(
                (trail) {
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
                                      ?.copyWith(color: AppColors.textPrimary),
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
                                  color: AppColors.textSecondary,
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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

  void _showTrailDetails(BuildContext context, Trail trail) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.backgroundSecondary,
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
                            ?.copyWith(color: AppColors.textPrimary),
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
                                            color: AppColors.textPrimary,
                                          ),
                                      h1: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                      h2: Theme.of(context).textTheme.titleLarge
                                          ?.copyWith(
                                            color: AppColors.textPrimary,
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
                                      ?.copyWith(color: AppColors.textPrimary),
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
                                          color: AppColors.surfaceStrong
                                              .withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: AppColors.outline.withValues(
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

  final TextEditingController labelController;
  final TextEditingController urlController;
  String type;

  void dispose() {
    labelController.dispose();
    urlController.dispose();
  }
}
