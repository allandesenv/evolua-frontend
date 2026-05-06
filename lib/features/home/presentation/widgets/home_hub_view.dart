import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/presentation/widgets/check_in_ai_insight_card.dart';
import 'package:evolua_frontend/features/home/application/proactive_greeting.dart';
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
    required this.displayName,
    required this.mentorPremiumPassActive,
    required this.onOpenTrails,
    required this.onOpenFeed,
    required this.onOpenCommunity,
    required this.onOpenProfile,
    required this.onOpenEvolutionMirror,
    required this.onOpenCheckIn,
    this.onOpenPremium,
    this.mentorPremiumPassEndsAt,
  });

  final int profilesCount;
  final int trailsCount;
  final int checkInsCount;
  final int postsCount;
  final int communitiesCount;
  final String? displayName;
  final bool mentorPremiumPassActive;
  final VoidCallback onOpenTrails;
  final VoidCallback onOpenFeed;
  final VoidCallback onOpenCommunity;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenEvolutionMirror;
  final VoidCallback onOpenCheckIn;
  final VoidCallback? onOpenPremium;
  final DateTime? mentorPremiumPassEndsAt;

  @override
  ConsumerState<HomeHubView> createState() => _HomeHubViewState();
}

class _HomeHubViewState extends ConsumerState<HomeHubView> {
  bool _isRewardLoading = false;

  void _openInsightSheet(CheckInAiInsight insight) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.evoluaColors.surface,
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
        message:
            'Nao foi possivel carregar o anuncio agora. Tente novamente em instantes.',
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
      backgroundColor: context.evoluaColors.surface,
      builder: (context) => _BriefingBottomSheet(
        title: 'Seu ritmo hoje',
        child: _RhythmDetailsSheet(
          summary: summary,
          recentItems: recentItems,
          onOpenEvolutionMirror: () {
            Navigator.of(context).pop();
            widget.onOpenEvolutionMirror();
          },
        ),
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
    final latestCreatedCheckIn =
        checkInState.asData?.value.latestCreatedCheckIn;
    final latestInsight =
        latestCreatedCheckIn?.aiInsight ??
        recentItems
            .where((item) => item.aiInsight != null)
            .map((item) => item.aiInsight!)
            .firstOrNull;
    final rhythmSummary = _RhythmSummary.fromItems(
      recentItems,
      fallbackEnergy: 7,
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
      _ when widget.checkInsCount == 0 => widget.onOpenCheckIn,
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
    final proactiveGreeting = buildProactiveGreeting(
      displayName: widget.displayName,
      checkIns: recentItems,
      latestCreatedCheckIn: latestCreatedCheckIn,
      activeJourney: currentJourney,
      mentorPremiumPassActive: widget.mentorPremiumPassActive,
      mentorPremiumPassEndsAt: widget.mentorPremiumPassEndsAt,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProactiveGreetingCard(
          greeting: proactiveGreeting,
          onCheckIn: widget.onOpenCheckIn,
          onContinueJourney: widget.onOpenTrails,
          onOpenEvolutionMirror: widget.onOpenEvolutionMirror,
        ),
        const SizedBox(height: 18),
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

class _ProactiveGreetingCard extends StatelessWidget {
  const _ProactiveGreetingCard({
    required this.greeting,
    required this.onCheckIn,
    required this.onContinueJourney,
    required this.onOpenEvolutionMirror,
  });

  final ProactiveGreeting greeting;
  final VoidCallback onCheckIn;
  final VoidCallback onContinueJourney;
  final VoidCallback onOpenEvolutionMirror;

  @override
  Widget build(BuildContext context) {
    final action = switch (greeting.action) {
      ProactiveGreetingAction.checkIn => onCheckIn,
      ProactiveGreetingAction.continueJourney => onContinueJourney,
      ProactiveGreetingAction.evolutionMirror => onOpenEvolutionMirror,
    };
    final icon = switch (greeting.action) {
      ProactiveGreetingAction.checkIn => Icons.favorite_rounded,
      ProactiveGreetingAction.continueJourney => Icons.play_arrow_rounded,
      ProactiveGreetingAction.evolutionMirror => Icons.auto_graph_rounded,
    };

    return PrimaryPanel(
      semanticLabel: 'Mensagem proativa personalizada',
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.accent.withValues(alpha: 0.14),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.24),
              ),
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting.greeting,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  greeting.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: action,
                    icon: Icon(icon),
                    label: Text(greeting.actionLabel),
                  ),
                ),
              ],
            ),
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
                  _SoftChip(
                    icon: Icons.shield_outlined,
                    label: 'Modo seguro',
                    color: context.evoluaColors.textSecondary,
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
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          _PaceMetadataLine(duration: meta.duration, benefit: meta.benefit),
          const SizedBox(height: 10),
          _PaceStatusBadge(label: meta.reason),
          const SizedBox(height: 30),
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

class _PaceMetadataLine extends StatelessWidget {
  const _PaceMetadataLine({required this.duration, required this.benefit});

  final String duration;
  final String benefit;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: context.evoluaColors.textSecondary.withValues(alpha: 0.78),
      fontWeight: FontWeight.w500,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PaceMetadataItem(
          icon: Icons.schedule_rounded,
          label: duration,
          style: style,
        ),
        Text(
          '-',
          style: style?.copyWith(
            color: context.evoluaColors.textSecondary.withValues(alpha: 0.48),
          ),
        ),
        _PaceMetadataItem(
          icon: Icons.lightbulb_outline_rounded,
          label: benefit,
          style: style,
        ),
      ],
    );
  }
}

class _PaceMetadataItem extends StatelessWidget {
  const _PaceMetadataItem({
    required this.icon,
    required this.label,
    required this.style,
  });

  final IconData icon;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: context.evoluaColors.textSecondary.withValues(alpha: 0.68),
        ),
        const SizedBox(width: 5),
        Text(label, style: style),
      ],
    );
  }
}

class _PaceStatusBadge extends StatelessWidget {
  const _PaceStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.18),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 13,
            color: context.evoluaColors.textSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.evoluaColors.textSecondary.withValues(alpha: 0.82),
              fontWeight: FontWeight.w600,
            ),
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

class _RhythmDetailsSheet extends StatelessWidget {
  const _RhythmDetailsSheet({
    required this.summary,
    required this.recentItems,
    required this.onOpenEvolutionMirror,
  });

  final _RhythmSummary summary;
  final List<CheckIn> recentItems;
  final VoidCallback onOpenEvolutionMirror;

  @override
  Widget build(BuildContext context) {
    final consistencyDays = summary.weeklyCheckIns.clamp(0, 7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.accent.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.accent.withValues(alpha: 0.18),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      summary.personalInsight,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.evoluaColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary.energyTrend,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.evoluaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _RhythmMetricGrid(
          metrics: [
            _RhythmMetric(
              icon: Icons.bolt_rounded,
              label: 'Energia media',
              value: '${summary.averageEnergy.toStringAsFixed(1)}/10',
            ),
            _RhythmMetric(
              icon: Icons.schedule_rounded,
              label: 'Melhor horario',
              value: summary.bestTime,
            ),
            _RhythmMetric(
              icon: Icons.mood_rounded,
              label: 'Estado dominante',
              value: summary.dominantMood,
            ),
            _RhythmMetric(
              icon: Icons.event_available_rounded,
              label: 'Check-ins na semana',
              value: '${summary.weeklyCheckIns}',
            ),
            _RhythmMetric(
              icon: Icons.local_fire_department_rounded,
              label: 'Streak',
              value: '${summary.streak} dias',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Consistencia da semana',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.evoluaColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            7,
            (index) => _ConsistencyDot(active: index < consistencyDays),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          summary.weeklyCheckIns == 0
              ? 'Seu ritmo ainda esta se formando. Um check-in curto ja ajuda a criar contexto.'
              : 'Voce registrou ${summary.weeklyCheckIns} momento(s) nesta semana.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 22),
        Text(
          'Ultimos check-ins',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.evoluaColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (recentItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.28),
            ),
            child: Text(
              'Seus proximos check-ins aparecem aqui.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...recentItems.take(4).map((item) => _RecentCheckInTile(item: item)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onOpenEvolutionMirror,
            icon: const Icon(Icons.auto_graph_rounded),
            label: const Text('Abrir Espelho da Evolucao'),
          ),
        ),
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
            color: context.evoluaColors.textPrimary,
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
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.evoluaColors.textPrimary,
              ),
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
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.36),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.28),
        ),
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

class _RhythmMetric {
  const _RhythmMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _RhythmMetricGrid extends StatelessWidget {
  const _RhythmMetricGrid({required this.metrics});

  final List<_RhythmMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: metrics
          .map(
            (metric) => SizedBox(
              width: 150,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: context.evoluaColors.surfaceStrong.withValues(
                    alpha: 0.32,
                  ),
                  border: Border.all(
                    color: context.evoluaColors.outline.withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(metric.icon, size: 18, color: AppColors.accent),
                    const SizedBox(height: 9),
                    Text(
                      metric.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.evoluaColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metric.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ConsistencyDot extends StatelessWidget {
  const _ConsistencyDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 220),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? AppColors.accent
            : context.evoluaColors.surfaceStrong.withValues(alpha: 0.36),
        border: Border.all(
          color: active
              ? AppColors.accent.withValues(alpha: 0.42)
              : context.evoluaColors.outline.withValues(alpha: 0.14),
        ),
      ),
      child: active
          ? const Icon(Icons.check_rounded, size: 16, color: AppColors.surface)
          : null,
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
          color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.32),
          border: Border.all(
            color: context.evoluaColors.outline.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.accent.withValues(alpha: 0.14),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 17,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalize(item.mood),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.evoluaColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$day/$month as $hour:$minute',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '${item.energyLevel}/10',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.evoluaColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
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
          color: context.evoluaColors.outline.withValues(alpha: 0.8),
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
