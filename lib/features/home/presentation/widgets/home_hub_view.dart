import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/presentation/widgets/check_in_ai_insight_card.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeHubView extends ConsumerStatefulWidget {
  const HomeHubView({
    super.key,
    required this.profilesCount,
    required this.trailsCount,
    required this.checkInsCount,
    required this.postsCount,
    required this.communitiesCount,
    required this.onOpenTrails,
    required this.onOpenFeed,
    required this.onOpenCommunity,
    required this.onOpenProfile,
    this.onOpenPremium,
  });

  final int profilesCount;
  final int trailsCount;
  final int checkInsCount;
  final int postsCount;
  final int communitiesCount;
  final VoidCallback onOpenTrails;
  final VoidCallback onOpenFeed;
  final VoidCallback onOpenCommunity;
  final VoidCallback onOpenProfile;
  final VoidCallback? onOpenPremium;

  @override
  ConsumerState<HomeHubView> createState() => _HomeHubViewState();
}

class _HomeHubViewState extends ConsumerState<HomeHubView> {
  static const _quickMoodOptions = ['Calmo', 'Ansioso', 'Cansado', 'Distraido'];

  final _reflectionController = TextEditingController();
  String _selectedMood = 'Calmo';
  double _energyLevel = 7;
  bool _isSubmittingCheckIn = false;
  bool _isRewardLoading = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(checkInControllerProvider, (previous, next) {
      if (!next.hasError || !mounted) {
        return;
      }

      final error = next.error;
      final message = error is DioException
          ? (error.response?.data is Map<String, dynamic>
                ? ((error.response?.data['details'] as List?)?.join(', ') ??
                      error.message ??
                      'Nao foi possivel salvar o check-in.')
                : error.message ?? 'Nao foi possivel salvar o check-in.')
          : 'Nao foi possivel salvar o check-in.';

      AppSnackBar.show(
        context,
        message: message,
        icon: Icons.favorite_border_rounded,
      );
    });
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _submitQuickCheckIn() async {
    if (_isSubmittingCheckIn) {
      return;
    }

    setState(() => _isSubmittingCheckIn = true);
    try {
      await ref
          .read(checkInControllerProvider.notifier)
          .create(
            mood: _selectedMood.toLowerCase(),
            reflection: _reflectionController.text.trim().isEmpty
                ? null
                : _reflectionController.text.trim(),
            energyLevel: _energyLevel.round(),
          );

      if (!mounted) {
        return;
      }

      _reflectionController.clear();

      AppSnackBar.show(
        context,
        message: 'Check-in registrado. Continue no seu ritmo.',
        icon: Icons.check_circle_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCheckIn = false);
      }
    }
  }

  void _openMoodPicker(List<CheckIn> recentItems, CheckInAiInsight? insight) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _MoodPickerSheet(
        recentItems: recentItems,
        suggestedInsight: insight,
        selectedMood: _selectedMood,
        onSelected: (mood) {
          setState(() => _selectedMood = mood);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openInsightSheet(CheckInAiInsight insight) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _BriefingBottomSheet(
        title: 'Analise completa',
        child: CheckInAiInsightCard(
          insight: insight,
          onOpenTrails: widget.onOpenTrails,
          isRewardLoading: _isRewardLoading,
          onWatchRewardedAd: _watchRewardedAd,
          onOpenPremium: widget.onOpenPremium,
        ),
      ),
    );
  }

  Future<void> _watchRewardedAd() async {
    if (_isRewardLoading) {
      return;
    }

    setState(() => _isRewardLoading = true);
    try {
      final rewarded = await ref
          .read(rewardedAdServiceProvider)
          .showRewardedAd(rewardType: 'AI_ACTION');
      if (!mounted) {
        return;
      }
      await ref.read(subscriptionControllerProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: rewarded
            ? 'Credito extra de IA liberado. Faca um novo check-in quando quiser.'
            : 'Anuncio indisponivel neste dispositivo. Voce ainda pode assinar Premium.',
        icon: rewarded
            ? Icons.ondemand_video_rounded
            : Icons.workspace_premium_rounded,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: 'Nao foi possivel carregar o anuncio agora. Tente novamente em instantes.',
        icon: Icons.wifi_off_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isRewardLoading = false);
      }
    }
  }

  void _openRhythmDetails(_RhythmSummary summary, List<CheckIn> recentItems) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _BriefingBottomSheet(
        title: 'Seu ritmo hoje',
        child: _RhythmDetailsSheet(summary: summary, recentItems: recentItems),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveBreakpoints.isCompact(context);
    final checkInState = ref.watch(checkInControllerProvider);
    final currentJourney = ref.watch(currentJourneyTrailProvider).asData?.value;
    final result = checkInState.asData?.value.result;
    final recentItems = result?.items ?? const <CheckIn>[];
    final latestInsight =
        checkInState.asData?.value.latestCreatedCheckIn?.aiInsight ??
        recentItems
            .where((item) => item.aiInsight != null)
            .map((item) => item.aiInsight!)
            .firstOrNull;
    final rhythmSummary = _RhythmSummary.fromItems(
      recentItems,
      fallbackEnergy: _energyLevel.round(),
      activeJourneyTitle: currentJourney?.title,
    );

    final paceLabel = switch (widget.trailsCount) {
      _ when currentJourney != null => currentJourney.title,
      0 => 'Monte sua primeira trilha pessoal',
      _ when widget.checkInsCount == 0 =>
        'Registre como voce esta para receber a direcao do dia',
      _ when widget.postsCount == 0 =>
        'Encontre uma reflexao curta para o seu momento',
      _ => 'Respiracao guiada',
    };
    final paceAction = switch (widget.trailsCount) {
      _ when currentJourney != null => widget.onOpenTrails,
      0 => widget.onOpenTrails,
      _ when widget.checkInsCount == 0 => _submitQuickCheckIn,
      _ when widget.postsCount == 0 => widget.onOpenFeed,
      _ => widget.onOpenTrails,
    };
    final paceButtonLabel = switch (widget.trailsCount) {
      _ when currentJourney != null => 'Continuar jornada',
      0 => 'Ver trilhas',
      _ when widget.checkInsCount == 0 => 'Fazer check-in',
      _ when widget.postsCount == 0 => 'Ver reflexoes',
      _ => 'Comecar agora',
    };
    final paceMeta = _PaceMeta.fromContext(
      hasJourney: currentJourney != null,
      hasInsight: latestInsight != null,
      checkInsCount: widget.checkInsCount,
      suggestedAction: latestInsight?.suggestedAction,
      currentJourneySummary: currentJourney?.summary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CheckInBriefingCard(
          selectedMood: _selectedMood,
          energyLevel: _energyLevel,
          reflectionController: _reflectionController,
          quickMoodOptions: _quickMoodOptions,
          isLoading:
              _isSubmittingCheckIn ||
              (checkInState.isLoading && !checkInState.hasValue),
          onMoodSelected: (mood) => setState(() => _selectedMood = mood),
          onOpenMoodPicker: () => _openMoodPicker(recentItems, latestInsight),
          onEnergyChanged: (value) => setState(() => _energyLevel = value),
          onSubmit: _submitQuickCheckIn,
        ),
        const SizedBox(height: 22),
        _InsightBriefingCard(
          insight: latestInsight,
          onOpenFullAnalysis: latestInsight == null
              ? null
              : () => _openInsightSheet(latestInsight),
        ),
        const SizedBox(height: 24),
        _NextStepHeroCard(
          compact: compact,
          title: paceLabel,
          description:
              currentJourney?.summary ??
              latestInsight?.suggestedAction ??
              'Uma unica acao agora vale mais do que abrir muitas frentes ao mesmo tempo.',
          meta: paceMeta,
          buttonLabel: paceButtonLabel,
          onPrimaryAction: paceAction,
          onOpenCommunity: widget.onOpenCommunity,
        ),
        const SizedBox(height: 22),
        _RhythmBriefingCard(
          compact: compact,
          summary: rhythmSummary,
          onOpenDetails: () => _openRhythmDetails(rhythmSummary, recentItems),
          onOpenLastCheckIns: () =>
              _openRhythmDetails(rhythmSummary, recentItems),
          onOpenProfile: widget.onOpenProfile,
        ),
      ],
    );
  }
}

class _CheckInBriefingCard extends StatelessWidget {
  const _CheckInBriefingCard({
    required this.selectedMood,
    required this.energyLevel,
    required this.reflectionController,
    required this.quickMoodOptions,
    required this.isLoading,
    required this.onMoodSelected,
    required this.onOpenMoodPicker,
    required this.onEnergyChanged,
    required this.onSubmit,
  });

  final String selectedMood;
  final double energyLevel;
  final TextEditingController reflectionController;
  final List<String> quickMoodOptions;
  final bool isLoading;
  final ValueChanged<String> onMoodSelected;
  final VoidCallback onOpenMoodPicker;
  final ValueChanged<double> onEnergyChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: 'Check-in do dia',
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            eyebrow: 'Como estou?',
            title: 'Comece pelo seu estado agora',
            subtitle:
                'Um check-in curto ja da contexto para o seu briefing do dia.',
            accentColor: AppColors.accent,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...quickMoodOptions.map(
                (mood) => ChoiceChip(
                  label: Text(mood),
                  selected: selectedMood == mood,
                  onSelected: (_) => onMoodSelected(mood),
                ),
              ),
              ActionChip(
                tooltip: 'Ver mais estados',
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Mais estados'),
                onPressed: onOpenMoodPicker,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Estado selecionado: $selectedMood',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          Text(
            'Energia percebida: ${energyLevel.round()}/10',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
          ),
          Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: energyLevel,
            onChanged: onEnergyChanged,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: reflectionController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Se quiser, conte o motivo',
              hintText: 'Uma frase simples ajuda a leitura ficar mais precisa.',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isLoading ? null : onSubmit,
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.favorite_rounded),
            label: const Text('Fazer check-in'),
          ),
        ],
      ),
    );
  }
}

class _InsightBriefingCard extends StatelessWidget {
  const _InsightBriefingCard({
    required this.insight,
    required this.onOpenFullAnalysis,
  });

  final CheckInAiInsight? insight;
  final VoidCallback? onOpenFullAnalysis;

  @override
  Widget build(BuildContext context) {
    final riskColor = switch (insight?.riskLevel.toLowerCase()) {
      'high' => AppColors.accentWarm,
      'medium' => AppColors.accentGold,
      _ => AppColors.accent,
    };
    final summary = _summaryFromInsight(insight);

    return PrimaryPanel(
      semanticLabel: 'Leitura inteligente resumida',
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            eyebrow: 'O que isso significa?',
            title: 'Leitura inteligente',
            subtitle: summary,
            accentColor: AppColors.accentWarm,
          ),
          if (insight != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SoftChip(
                  icon: Icons.psychology_alt_rounded,
                  label: 'Risco ${insight!.riskLevel}',
                  color: riskColor,
                ),
                if (insight!.fallbackUsed)
                  const _SoftChip(
                    icon: Icons.shield_outlined,
                    label: 'Modo seguro',
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onOpenFullAnalysis,
              icon: const Icon(Icons.open_in_full_rounded),
              label: const Text('Ver analise completa'),
            ),
          ],
        ],
      ),
    );
  }

  String _summaryFromInsight(CheckInAiInsight? insight) {
    if (insight == null) {
      return 'Depois do proximo check-in, a IA resume o momento e transforma a leitura em uma acao simples.';
    }

    final text = insight.insight.trim();
    if (text.length <= 180) {
      return text;
    }

    return '${text.substring(0, 177).trimRight()}...';
  }
}

class _NextStepHeroCard extends StatelessWidget {
  const _NextStepHeroCard({
    required this.compact,
    required this.title,
    required this.description,
    required this.meta,
    required this.buttonLabel,
    required this.onPrimaryAction,
    required this.onOpenCommunity,
  });

  final bool compact;
  final String title;
  final String description;
  final _PaceMeta meta;
  final String buttonLabel;
  final VoidCallback onPrimaryAction;
  final VoidCallback onOpenCommunity;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: 'Proximo passo principal',
      padding: EdgeInsets.all(compact ? 24 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            eyebrow: 'O que faco agora?',
            title: 'Proximo passo',
            subtitle:
                'A acao principal do seu dia, escolhida para caber no seu momento.',
            accentColor: AppColors.accentGold,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SoftChip(
                icon: Icons.schedule_rounded,
                label: meta.duration,
                color: AppColors.accent,
              ),
              _SoftChip(
                icon: Icons.lightbulb_outline_rounded,
                label: meta.benefit,
                color: AppColors.accentWarm,
              ),
              _SoftChip(
                icon: Icons.auto_awesome_rounded,
                label: meta.reason,
                color: AppColors.accentGold,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onPrimaryAction,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(buttonLabel),
              ),
              OutlinedButton.icon(
                onPressed: onOpenCommunity,
                icon: const Icon(Icons.groups_rounded),
                label: const Text('Espacos'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RhythmBriefingCard extends StatelessWidget {
  const _RhythmBriefingCard({
    required this.compact,
    required this.summary,
    required this.onOpenDetails,
    required this.onOpenLastCheckIns,
    required this.onOpenProfile,
  });

  final bool compact;
  final _RhythmSummary summary;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenLastCheckIns;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: 'Seu ritmo',
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            eyebrow: 'Como anda meu ritmo?',
            title: 'Seu ritmo',
            subtitle: summary.personalInsight,
            accentColor: AppColors.accent,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InsightPill(
                width: compact ? double.infinity : 260,
                icon: Icons.wb_sunny_rounded,
                text: summary.timeInsight,
              ),
              _InsightPill(
                width: compact ? double.infinity : 260,
                icon: Icons.trending_up_rounded,
                text: summary.energyTrend,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenDetails,
                icon: const Icon(Icons.insights_rounded),
                label: const Text('Ver detalhes do seu ritmo'),
              ),
              TextButton.icon(
                onPressed: onOpenLastCheckIns,
                icon: const Icon(Icons.history_rounded),
                label: const Text('Ver ultimos check-ins'),
              ),
              TextButton.icon(
                onPressed: onOpenProfile,
                icon: const Icon(Icons.person_rounded),
                label: const Text('Ver perfil'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodPickerSheet extends StatefulWidget {
  const _MoodPickerSheet({
    required this.recentItems,
    required this.suggestedInsight,
    required this.selectedMood,
    required this.onSelected,
  });

  final List<CheckIn> recentItems;
  final CheckInAiInsight? suggestedInsight;
  final String selectedMood;
  final ValueChanged<String> onSelected;

  @override
  State<_MoodPickerSheet> createState() => _MoodPickerSheetState();
}

class _MoodPickerSheetState extends State<_MoodPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentMoods = widget.recentItems
        .map((item) => _capitalize(item.mood))
        .where((mood) => mood.isNotEmpty)
        .toSet()
        .take(4)
        .toList();
    final suggestedMoods = _suggestedMoods(widget.suggestedInsight);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _BottomSheetHandle(),
                Text(
                  'Escolha um estado',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar estado',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                if (recentMoods.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _MoodGroup(
                    title: 'Recentes',
                    moods: _filterMoods(recentMoods),
                    selectedMood: widget.selectedMood,
                    onSelected: widget.onSelected,
                  ),
                ],
                if (suggestedMoods.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _MoodGroup(
                    title: 'Sugeridos pela IA',
                    moods: _filterMoods(suggestedMoods),
                    selectedMood: widget.selectedMood,
                    onSelected: widget.onSelected,
                  ),
                ],
                ..._moodGroups.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: _MoodGroup(
                      title: entry.key,
                      moods: _filterMoods(entry.value),
                      selectedMood: widget.selectedMood,
                      onSelected: widget.onSelected,
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

  List<String> _filterMoods(List<String> moods) {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return moods;
    }

    return moods
        .where((mood) => mood.toLowerCase().contains(normalizedQuery))
        .toList();
  }

  List<String> _suggestedMoods(CheckInAiInsight? insight) {
    final source = [
      insight?.insight ?? '',
      insight?.suggestedAction ?? '',
      insight?.suggestedTrailReason ?? '',
    ].join(' ').toLowerCase();

    final matches = <String>[];
    for (final moods in _moodGroups.values) {
      for (final mood in moods) {
        if (source.contains(mood.toLowerCase())) {
          matches.add(mood);
        }
      }
    }

    return matches.toSet().take(4).toList();
  }
}

class _MoodGroup extends StatelessWidget {
  const _MoodGroup({
    required this.title,
    required this.moods,
    required this.selectedMood,
    required this.onSelected,
  });

  final String title;
  final List<String> moods;
  final String selectedMood;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (moods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: moods
              .map(
                (mood) => ChoiceChip(
                  label: Text(mood),
                  selected: selectedMood == mood,
                  onSelected: (_) => onSelected(mood),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _RhythmDetailsSheet extends StatelessWidget {
  const _RhythmDetailsSheet({required this.summary, required this.recentItems});

  final _RhythmSummary summary;
  final List<CheckIn> recentItems;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RhythmDetailRow(
          label: 'Energia media',
          value: '${summary.averageEnergy.toStringAsFixed(1)}/10',
        ),
        _RhythmDetailRow(label: 'Melhor horario', value: summary.bestTime),
        _RhythmDetailRow(
          label: 'Estado dominante',
          value: summary.dominantMood,
        ),
        _RhythmDetailRow(
          label: 'Check-ins esta semana',
          value: '${summary.weeklyCheckIns}',
        ),
        _RhythmDetailRow(label: 'Streak', value: '${summary.streak} dias'),
        _RhythmDetailRow(
          label: 'Oscilacao recente',
          value: summary.energyTrend,
        ),
        const SizedBox(height: 18),
        Text(
          'Ultimos check-ins',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        if (recentItems.isEmpty)
          Text(
            'Seus proximos check-ins aparecem aqui.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...recentItems.take(4).map((item) => _RecentCheckInTile(item: item)),
      ],
    );
  }
}

class _BriefingBottomSheet extends StatelessWidget {
  const _BriefingBottomSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.84,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _BottomSheetHandle(),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightPill extends StatelessWidget {
  const _InsightPill({
    required this.width,
    required this.icon,
    required this.text,
  });

  final double width;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.surfaceStrong.withValues(alpha: 0.36),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _RhythmDetailRow extends StatelessWidget {
  const _RhythmDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentCheckInTile extends StatelessWidget {
  const _RecentCheckInTile({required this.item});

  final CheckIn item;

  @override
  Widget build(BuildContext context) {
    final day = item.createdAt.day.toString().padLeft(2, '0');
    final month = item.createdAt.month.toString().padLeft(2, '0');
    final hour = item.createdAt.hour.toString().padLeft(2, '0');
    final minute = item.createdAt.minute.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surfaceStrong.withValues(alpha: 0.32),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _capitalize(item.mood),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
              ),
            ),
            Text(
              '$day/$month $hour:$minute - ${item.energyLevel}/10',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.outline.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _PaceMeta {
  const _PaceMeta({
    required this.duration,
    required this.benefit,
    required this.reason,
  });

  final String duration;
  final String benefit;
  final String reason;

  factory _PaceMeta.fromContext({
    required bool hasJourney,
    required bool hasInsight,
    required int checkInsCount,
    String? suggestedAction,
    String? currentJourneySummary,
  }) {
    if (hasJourney) {
      return const _PaceMeta(
        duration: '8 min',
        benefit: 'mantem constancia',
        reason: 'jornada ativa',
      );
    }

    if (hasInsight) {
      return const _PaceMeta(
        duration: '6 min',
        benefit: 'reduz sobrecarga',
        reason: 'baseado no check-in',
      );
    }

    if (checkInsCount == 0) {
      return const _PaceMeta(
        duration: '2 min',
        benefit: 'clareia o momento',
        reason: 'primeiro contexto',
      );
    }

    return const _PaceMeta(
      duration: '5 min',
      benefit: 'recupera clareza',
      reason: 'ritmo recente',
    );
  }
}

class _RhythmSummary {
  const _RhythmSummary({
    required this.averageEnergy,
    required this.dominantMood,
    required this.bestTime,
    required this.weeklyCheckIns,
    required this.streak,
    required this.energyTrend,
    required this.timeInsight,
    required this.personalInsight,
  });

  final double averageEnergy;
  final String dominantMood;
  final String bestTime;
  final int weeklyCheckIns;
  final int streak;
  final String energyTrend;
  final String timeInsight;
  final String personalInsight;

  factory _RhythmSummary.fromItems(
    List<CheckIn> items, {
    required int fallbackEnergy,
    String? activeJourneyTitle,
  }) {
    final averageEnergy = items.isEmpty
        ? fallbackEnergy.toDouble()
        : items.fold<int>(0, (sum, item) => sum + item.energyLevel) /
              items.length;
    final dominantMood = items.isEmpty
        ? 'sem padrao ainda'
        : _capitalize(_dominantMood(items));
    final bestTime = _bestTimeWindow(items);
    final weeklyCheckIns = _weeklyCheckIns(items);
    final streak = _calculateStreak(items);
    final energyTrend = _energyTrend(items);
    final timeInsight = items.isEmpty
        ? 'Seu melhor horario aparece depois dos primeiros registros.'
        : 'Voce tem respondido melhor em torno de $bestTime.';
    final personalInsight = items.isEmpty
        ? 'Seu ritmo comeca a ficar claro a partir dos proximos check-ins.'
        : activeJourneyTitle == null
        ? 'Seu estado dominante recente foi $dominantMood, com energia media ${averageEnergy.toStringAsFixed(1)}/10.'
        : 'Voce mantem uma jornada ativa e seu padrao recente aponta para $dominantMood.';

    return _RhythmSummary(
      averageEnergy: averageEnergy,
      dominantMood: dominantMood,
      bestTime: bestTime,
      weeklyCheckIns: weeklyCheckIns,
      streak: streak,
      energyTrend: energyTrend,
      timeInsight: timeInsight,
      personalInsight: personalInsight,
    );
  }
}

const _moodGroups = {
  'Emocionais': [
    'Calmo',
    'Ansioso',
    'Triste',
    'Animado',
    'Irritado',
    'Esperancoso',
    'Sobrecarregado',
  ],
  'Mentais': [
    'Distraido',
    'Focado',
    'Confuso',
    'Criativo',
    'Acelerado',
    'Travado',
  ],
  'Fisicos': ['Cansado', 'Energizado', 'Tenso', 'Leve', 'Sonolento', 'Agitado'],
  'Comportamentais': [
    'Evitando',
    'Produtivo',
    'Isolado',
    'Conectado',
    'Procrastinando',
    'Constante',
  ],
};

String _dominantMood(List<CheckIn> items) {
  final counts = <String, int>{};
  for (final item in items) {
    counts.update(item.mood, (value) => value + 1, ifAbsent: () => 1);
  }

  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

String _bestTimeWindow(List<CheckIn> items) {
  if (items.isEmpty) {
    return '09h-11h';
  }

  final buckets = <String, List<int>>{
    '06h-09h': [],
    '09h-11h': [],
    '12h-15h': [],
    '16h-19h': [],
    '20h-22h': [],
  };

  for (final item in items) {
    final hour = item.createdAt.hour;
    final key = switch (hour) {
      >= 6 && < 9 => '06h-09h',
      >= 9 && < 12 => '09h-11h',
      >= 12 && < 16 => '12h-15h',
      >= 16 && < 20 => '16h-19h',
      _ => '20h-22h',
    };
    buckets[key]!.add(item.energyLevel);
  }

  final scored = buckets.entries
      .where((entry) => entry.value.isNotEmpty)
      .map(
        (entry) => MapEntry(
          entry.key,
          entry.value.fold<int>(0, (sum, value) => sum + value) /
              entry.value.length,
        ),
      )
      .toList();

  if (scored.isEmpty) {
    return '09h-11h';
  }

  scored.sort((a, b) => b.value.compareTo(a.value));
  return scored.first.key;
}

int _weeklyCheckIns(List<CheckIn> items) {
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  return items.where((item) => item.createdAt.isAfter(weekAgo)).length;
}

String _energyTrend(List<CheckIn> items) {
  if (items.length < 2) {
    return 'Ainda nao ha oscilacao suficiente para comparar.';
  }

  final midpoint = (items.length / 2).ceil();
  final recent = items.take(midpoint).toList();
  final older = items.skip(midpoint).toList();
  final recentAverage =
      recent.fold<int>(0, (sum, item) => sum + item.energyLevel) /
      recent.length;
  final olderAverage = older.isEmpty
      ? recentAverage
      : older.fold<int>(0, (sum, item) => sum + item.energyLevel) /
            older.length;
  final delta = recentAverage - olderAverage;

  if (delta >= 1) {
    return 'Sua energia subiu no periodo recente.';
  }
  if (delta <= -1) {
    return 'Sua energia caiu no periodo recente.';
  }
  return 'Sua energia ficou relativamente estavel.';
}

int _calculateStreak(List<CheckIn> items) {
  if (items.isEmpty) {
    return 0;
  }

  final days =
      items
          .map(
            (item) => DateTime(
              item.createdAt.year,
              item.createdAt.month,
              item.createdAt.day,
            ),
          )
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

  var streak = 0;
  var cursor = DateTime.now();
  cursor = DateTime(cursor.year, cursor.month, cursor.day);

  for (final day in days) {
    final expected = cursor.subtract(Duration(days: streak));
    if (day == expected) {
      streak++;
      continue;
    }

    if (streak == 0 && day == expected.subtract(const Duration(days: 1))) {
      streak++;
      continue;
    }

    break;
  }

  return streak;
}

String _capitalize(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
}
