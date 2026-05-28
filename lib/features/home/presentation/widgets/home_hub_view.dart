import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/presentation/widgets/check_in_ai_insight_card.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_controller.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/l10n/app_l10n.dart';
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
    required this.onOpenFutureMessages,
    required this.onOpenFutureMessage,
    required this.onOpenCareShare,
    required this.onOpenDailyRitual,
    required this.onOpenCheckIn,
    this.onOpenPremium,
    this.mentorPremiumPassEndsAt,
    this.now,
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
  final VoidCallback onOpenFutureMessages;
  final ValueChanged<int> onOpenFutureMessage;
  final VoidCallback onOpenCareShare;
  final ValueChanged<String> onOpenDailyRitual;
  final VoidCallback onOpenCheckIn;
  final VoidCallback? onOpenPremium;
  final DateTime? mentorPremiumPassEndsAt;
  final DateTime? now;

  @override
  ConsumerState<HomeHubView> createState() => _HomeHubViewState();
}

class _HomeHubViewState extends ConsumerState<HomeHubView> {
  bool _isRewardLoading = false;
  bool _isReadingActionLoading = false;

  void _openInsightSheet(CheckIn checkIn, CheckInAiInsight insight) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.evoluaColors.surface,
      builder: (context) => _BriefingBottomSheet(
        title: 'Análise completa',
        child: CheckInAiInsightCard(
          insight: insight,
          onOpenTrails: () {
            Navigator.of(context).pop();
            widget.onOpenTrails();
          },
          isRewardLoading: _isRewardLoading,
          onWatchRewardedAd: _watchRewardedAd,
          onOpenPremium: widget.onOpenPremium,
          isReadingActionLoading: _isReadingActionLoading,
          isSaved: checkIn.savedReading,
          onRegenerate: (style) => _regenerateReading(context, style),
          onSaveReading: () => _saveReading(context, checkIn.id),
          onCreateRitual: () => _createRitualFromReading(context, checkIn.id),
        ),
      ),
    );
  }

  Future<void> _regenerateReading(
    BuildContext sheetContext,
    String style,
  ) async {
    if (_isReadingActionLoading) {
      return;
    }

    setState(() => _isReadingActionLoading = true);
    try {
      await ref
          .read(checkInControllerProvider.notifier)
          .generateDeepReadingForLatest(style: style);
      if (!mounted) {
        return;
      }
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).maybePop();
      }
      AppSnackBar.show(
        context,
        message: 'Leitura atualizada com um novo foco.',
        icon: Icons.auto_awesome_rounded,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: 'Nao foi possivel gerar outra leitura agora.',
        icon: Icons.wifi_off_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isReadingActionLoading = false);
      }
    }
  }

  Future<void> _saveReading(BuildContext sheetContext, int checkInId) async {
    if (_isReadingActionLoading) {
      return;
    }

    setState(() => _isReadingActionLoading = true);
    try {
      await ref.read(checkInControllerProvider.notifier).saveReading(checkInId);
      if (!mounted) {
        return;
      }
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).maybePop();
      }
      AppSnackBar.show(
        context,
        message: 'Leitura salva para voce retomar depois.',
        icon: Icons.bookmark_added_rounded,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: 'Nao foi possivel salvar a leitura agora.',
        icon: Icons.wifi_off_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isReadingActionLoading = false);
      }
    }
  }

  Future<void> _createRitualFromReading(
    BuildContext sheetContext,
    int checkInId,
  ) async {
    if (_isReadingActionLoading) {
      return;
    }

    setState(() => _isReadingActionLoading = true);
    try {
      await ref
          .read(checkInControllerProvider.notifier)
          .createRitualFromReading(checkInId);
      if (!mounted) {
        return;
      }
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).maybePop();
      }
      AppSnackBar.show(
        context,
        message: 'Ritual criado a partir da sua leitura.',
        icon: Icons.self_improvement_rounded,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: 'Nao foi possivel criar o ritual agora.',
        icon: Icons.wifi_off_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isReadingActionLoading = false);
      }
    }
  }

  Future<void> _watchRewardedAd() async {
    if (_isRewardLoading) {
      return;
    }

    setState(() => _isRewardLoading = true);
    try {
      final rewarded = await ref
          .read(rewardedAdServiceProvider)
          .showRewardedAd(rewardType: 'DEEP_EMOTIONAL_READING');
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
            ? 'Crédito extra de IA liberado. Faça um novo check-in quando quiser.'
            : 'Anúncio indisponível neste dispositivo. Você ainda pode assinar Premium.',
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
            'Não foi possível carregar o anúncio agora. Tente novamente em instantes.',
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
    final session = ref.watch(authControllerProvider).asData?.value;
    final checkInState = ref.watch(checkInControllerProvider);
    final futureMessageState = ref.watch(futureMessageControllerProvider);
    final dailyRitualState = ref.watch(dailyRitualControllerProvider);
    final currentJourney = ref.watch(currentJourneyTrailProvider).asData?.value;
    final checkInHistory = checkInState.asData?.value;
    final canUseCheckInState =
        session == null ||
        checkInHistory?.belongsToUser(session.userId) == true;
    final result = canUseCheckInState ? checkInHistory?.result : null;
    final recentItems = result?.items ?? const <CheckIn>[];
    final latestCreatedCheckIn = canUseCheckInState
        ? checkInHistory?.latestCreatedCheckIn
        : null;
    final isInsightPending = canUseCheckInState
        ? checkInHistory?.isLatestInsightPending ?? false
        : false;
    final isInsightUnavailable = canUseCheckInState
        ? checkInHistory?.isLatestInsightUnavailable ?? false
        : false;
    final latestInsightCheckIn = latestCreatedCheckIn?.aiInsight != null
        ? latestCreatedCheckIn
        : recentItems.where((item) => item.aiInsight != null).firstOrNull;
    final latestInsight = latestInsightCheckIn?.aiInsight;
    final latestReadingCheckIn =
        latestInsightCheckIn ?? latestCreatedCheckIn ?? recentItems.firstOrNull;
    final isWaitingForInsight =
        latestInsight == null &&
        latestReadingCheckIn != null &&
        !isInsightUnavailable;
    final rhythmSummary = _RhythmSummary.fromItems(
      recentItems,
      fallbackEnergy: 7,
      activeJourneyTitle: currentJourney?.title,
    );

    final paceLabel = switch (widget.trailsCount) {
      _ when currentJourney != null => currentJourney.title,
      0 => 'Monte sua primeira trilha pessoal',
      _ when widget.checkInsCount == 0 =>
        'Registre como você está para receber a direção do dia',
      _ when widget.postsCount == 0 =>
        'Encontre uma reflexao curta para o seu momento',
      _ => 'Respiração guiada',
    };
    final paceAction = switch (widget.trailsCount) {
      _ when currentJourney != null => widget.onOpenTrails,
      0 => widget.onOpenTrails,
      _ when widget.checkInsCount == 0 => widget.onOpenCheckIn,
      _ when widget.postsCount == 0 => widget.onOpenFeed,
      _ => widget.onOpenTrails,
    };
    final paceButtonLabel = switch (widget.trailsCount) {
      _ when currentJourney != null => 'Continuar trilha',
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
    final currentTime = widget.now ?? DateTime.now();
    final readyFutureMessage =
        futureMessageState.asData?.value.readyToRead.firstOrNull;
    final showFutureMessage =
        readyFutureMessage != null &&
        _isDifficultCheckIn(latestCreatedCheckIn ?? recentItems.firstOrNull);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DailyJourneyCard(
          displayName: widget.displayName,
          now: currentTime,
          morningRitual: dailyRitualState.asData?.value.morning,
          eveningRitual: dailyRitualState.asData?.value.evening,
          isLoading: dailyRitualState.isLoading && !dailyRitualState.hasValue,
          onCheckIn: widget.onOpenCheckIn,
          onOpenDailyRitual: widget.onOpenDailyRitual,
          onOpenNextStep: widget.onOpenTrails,
          onOpenReflection: widget.onOpenFeed,
        ),
        const SizedBox(height: 14),
        _ContextMiniCardsCarousel(
          insight: latestInsight,
          isInsightPreparing: isWaitingForInsight || isInsightPending,
          onOpenFutureMessages: widget.onOpenFutureMessages,
          onOpenReflection: widget.onOpenFeed,
          onOpenInsight: latestInsight == null
              ? widget.onOpenCheckIn
              : () => _openInsightSheet(latestReadingCheckIn!, latestInsight),
          onOpenEvolutionMirror: widget.onOpenEvolutionMirror,
          onOpenCareShare: widget.onOpenCareShare,
        ),
        if (showFutureMessage) ...[
          const SizedBox(height: 14),
          _FutureMessageReadyCard(
            message: readyFutureMessage,
            onOpen: () => widget.onOpenFutureMessage(readyFutureMessage.id),
          ),
        ],
        const SizedBox(height: 18),
        _InsightBriefingCard(
          insight: latestInsight,
          checkIn: latestReadingCheckIn,
          isLoading: isInsightPending || isWaitingForInsight,
          isUnavailable: isInsightUnavailable,
          onOpenFullAnalysis: latestInsight == null
              ? null
              : () => _openInsightSheet(latestReadingCheckIn!, latestInsight),
        ),
        const SizedBox(height: 24),
        _NextStepHeroCard(
          compact: compact,
          title: paceLabel,
          description:
              currentJourney?.summary ??
              latestInsight?.suggestedAction ??
              'Uma única ação agora vale mais do que abrir muitas frentes ao mesmo tempo.',
          meta: paceMeta,
          buttonLabel: paceButtonLabel,
          onPrimaryAction: paceAction,
          onOpenCommunity: widget.onOpenCommunity,
        ),
        const SizedBox(height: 22),
        _RhythmBriefingCard(
          compact: compact,
          summary: rhythmSummary,
          onOpenEvolutionMirror: widget.onOpenEvolutionMirror,
          onOpenLastCheckIns: () =>
              _openRhythmDetails(rhythmSummary, recentItems),
          onOpenProfile: widget.onOpenProfile,
        ),
      ],
    );
  }

  bool _isDifficultCheckIn(CheckIn? checkIn) {
    if (checkIn == null) {
      return false;
    }
    final mood = checkIn.mood.toLowerCase();
    return checkIn.energyLevel <= 4 ||
        mood.contains('ans') ||
        mood.contains('cans') ||
        mood.contains('trist') ||
        mood.contains('desanim');
  }
}

class _DailyJourneyCard extends StatelessWidget {
  const _DailyJourneyCard({
    required this.displayName,
    required this.now,
    required this.morningRitual,
    required this.eveningRitual,
    required this.isLoading,
    required this.onCheckIn,
    required this.onOpenDailyRitual,
    required this.onOpenNextStep,
    required this.onOpenReflection,
  });

  final String? displayName;
  final DateTime now;
  final DailyRitual? morningRitual;
  final DailyRitual? eveningRitual;
  final bool isLoading;
  final VoidCallback onCheckIn;
  final ValueChanged<String> onOpenDailyRitual;
  final VoidCallback onOpenNextStep;
  final VoidCallback onOpenReflection;

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveBreakpoints.isCompact(context);
    final model = _DailyJourneyCardModel.from(
      context: context,
      displayName: displayName,
      now: now,
      morningRitual: morningRitual,
      eveningRitual: eveningRitual,
      onCheckIn: onCheckIn,
      onOpenDailyRitual: onOpenDailyRitual,
      onOpenNextStep: onOpenNextStep,
      onOpenReflection: onOpenReflection,
    );

    return PrimaryPanel(
      semanticLabel: 'Jornada Diária',
      padding: const EdgeInsets.all(18),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _DailyJourneyIcon(),
                    const SizedBox(width: 12),
                    Expanded(child: _DailyJourneyTitle(title: model.title)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  model.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (model.ritual != null) ...[
                  const SizedBox(height: 12),
                  _DailyJourneySummary(ritual: model.ritual!),
                ],
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _dailyJourneyActions(model, compact: compact),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DailyJourneyIcon(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DailyJourneyTitle(title: model.title),
                      const SizedBox(height: 6),
                      Text(
                        model.message,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (model.ritual != null) ...[
                        const SizedBox(height: 12),
                        _DailyJourneySummary(ritual: model.ritual!),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _dailyJourneyActions(model, compact: compact),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _dailyJourneyActions(
    _DailyJourneyCardModel model, {
    required bool compact,
  }) {
    final actions = [
      FilledButton.icon(
        onPressed: isLoading ? null : model.primaryAction,
        icon: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(model.primaryIcon),
        label: Text(
          model.primaryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      OutlinedButton.icon(
        onPressed: isLoading ? null : model.secondaryAction,
        icon: Icon(model.secondaryIcon),
        label: Text(
          model.secondaryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];

    if (!compact) {
      return actions;
    }

    return [
      for (final (index, action) in actions.indexed) ...[
        if (index > 0) const SizedBox(height: 8),
        action,
      ],
    ];
  }
}

class _DailyJourneyIcon extends StatelessWidget {
  const _DailyJourneyIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.accent.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
      ),
      child: const Icon(Icons.wb_sunny_rounded, color: AppColors.accent),
    );
  }
}

class _DailyJourneyTitle extends StatelessWidget {
  const _DailyJourneyTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: context.evoluaColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _DailyJourneySummary extends StatelessWidget {
  const _DailyJourneySummary({required this.ritual});

  final DailyRitual ritual;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.28),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Intencao de hoje: ${ritual.intention}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pequeno passo: ${ritual.microAction}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DailyJourneyCardModel {
  const _DailyJourneyCardModel({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.primaryAction,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.secondaryAction,
    this.ritual,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback primaryAction;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback secondaryAction;
  final DailyRitual? ritual;

  static _DailyJourneyCardModel from({
    required BuildContext context,
    required String? displayName,
    required DateTime now,
    required DailyRitual? morningRitual,
    required DailyRitual? eveningRitual,
    required VoidCallback onCheckIn,
    required ValueChanged<String> onOpenDailyRitual,
    required VoidCallback onOpenNextStep,
    required VoidCallback onOpenReflection,
  }) {
    final l10n = context.l10n;
    final name = _firstName(displayName);
    final hour = now.toLocal().hour;
    final isDayRitualWindow = hour >= 6 && hour < 18;
    final isEvening = !isDayRitualWindow;

    if (isEvening) {
      if (eveningRitual != null) {
        return _DailyJourneyCardModel(
          title: 'Fechamento do Dia concluído',
          message:
              'Você ja fechou o dia com mais consciencia. Agora pode descansar com menos peso.',
          ritual: eveningRitual,
          primaryLabel: l10n.homeDailyViewRitual,
          primaryIcon: Icons.visibility_rounded,
          primaryAction: () => onOpenDailyRitual(DailyRitualType.evening),
          secondaryLabel: l10n.homeDailyEveningSecondary,
          secondaryIcon: Icons.edit_note_rounded,
          secondaryAction: onOpenReflection,
        );
      }
      return _DailyJourneyCardModel(
        title: l10n.homeDailyEveningTitle,
        message: l10n.homeDailyEveningBody,
        primaryLabel: l10n.homeDailyEveningPrimary,
        primaryIcon: Icons.nightlight_round,
        primaryAction: () => onOpenDailyRitual(DailyRitualType.evening),
        secondaryLabel: l10n.homeDailyEveningSecondary,
        secondaryIcon: Icons.edit_note_rounded,
        secondaryAction: onOpenReflection,
      );
    }

    if (morningRitual != null) {
      return _DailyJourneyCardModel(
        title: l10n.homeDailyRitualDone,
        message: 'Sua jornada diaria ja tem um norte simples para hoje.',
        ritual: morningRitual,
        primaryLabel: l10n.homeDailyViewRitual,
        primaryIcon: Icons.visibility_rounded,
        primaryAction: () => onOpenDailyRitual(DailyRitualType.morning),
        secondaryLabel: l10n.homeDailyDayPrimary,
        secondaryIcon: Icons.favorite_rounded,
        secondaryAction: onCheckIn,
      );
    }

    if (isDayRitualWindow) {
      return _DailyJourneyCardModel(
        title: name == null
            ? l10n.homeDailyMorningTitleNoName
            : l10n.homeDailyMorningTitle(name),
        message: l10n.homeDailyMorningBody,
        primaryLabel: l10n.homeDailyMorningPrimary,
        primaryIcon: Icons.wb_sunny_rounded,
        primaryAction: () => onOpenDailyRitual(DailyRitualType.morning),
        secondaryLabel: l10n.homeDailyDayPrimary,
        secondaryIcon: Icons.favorite_rounded,
        secondaryAction: onCheckIn,
      );
    }

    return _DailyJourneyCardModel(
      title: l10n.homeDailyDayTitle,
      message: l10n.homeDailyDayBody,
      primaryLabel: l10n.homeDailyDayPrimary,
      primaryIcon: Icons.favorite_rounded,
      primaryAction: onCheckIn,
      secondaryLabel: l10n.homeDailyDaySecondary,
      secondaryIcon: Icons.play_arrow_rounded,
      secondaryAction: onOpenNextStep,
    );
  }

  static String? _firstName(String? displayName) {
    final normalized = displayName?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized.split(RegExp(r'\s+')).first;
  }
}

class _FutureMessageReadyCard extends StatelessWidget {
  const _FutureMessageReadyCard({required this.message, required this.onOpen});

  final FutureMessage message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.accentWarm.withValues(alpha: 0.16),
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              color: AppColors.accentWarm,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ha uma mensagem sua pronta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hoje parece um dia que merece cuidado. Uma carta do seu eu anterior pode ajudar a atravessar esse momento.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Quero ler'),
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
    required this.checkIn,
    required this.isLoading,
    required this.isUnavailable,
    required this.onOpenFullAnalysis,
  });

  final CheckInAiInsight? insight;
  final CheckIn? checkIn;
  final bool isLoading;
  final bool isUnavailable;
  final VoidCallback? onOpenFullAnalysis;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = _summaryFromInsight(context, insight);
    final showPreparingState = isLoading;

    return PrimaryPanel(
      semanticLabel: l10n.homeIntelligentReadingTitle,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            eyebrow: l10n.homeIntelligentReadingEyebrow,
            title: l10n.homeIntelligentReadingTitle,
            subtitle: summary,
            accentColor: AppColors.accentWarm,
          ),
          if (showPreparingState) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Preparando sua leitura inteligente...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.evoluaColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (insight != null) ...[
            const SizedBox(height: 14),
            _InsightBullet(
              text: l10n.homeEnergyBullet(
                checkIn == null ? '-' : checkIn!.energyLevel.toString(),
              ),
            ),
            _InsightBullet(
              text: l10n.homeStateBullet(
                checkIn == null ? '-' : _capitalize(checkIn!.mood),
              ),
            ),
            _InsightBullet(
              text: l10n.homeBestResponseBullet(
                _compactText(insight!.suggestedAction, maxLength: 72),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenFullAnalysis,
                icon: const Icon(Icons.open_in_full_rounded),
                label: Text(l10n.homeFullAnalysis),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _summaryFromInsight(BuildContext context, CheckInAiInsight? insight) {
    if (isLoading) {
      return 'Seu check-in foi salvo. Estamos atualizando a leitura para este momento.';
    }
    if (isUnavailable) {
      return 'Seu check-in foi salvo, mas a leitura ainda não ficou disponível. Tente atualizar em instantes.';
    }
    if (insight == null && checkIn != null) {
      return 'Seu check-in foi salvo. A leitura inteligente aparece aqui assim que estiver pronta.';
    }
    if (insight == null) {
      return context.l10n.homeIntelligentReadingEmpty;
    }

    return _compactText(_firstSentence(insight.insight), maxLength: 118);
  }

  String _firstSentence(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return 'Seu momento atual pede uma ação simples e possível.';
    }

    final stops = [
      '.',
      '!',
      '?',
    ].map(text.indexOf).where((index) => index >= 24).toList();
    if (stops.isEmpty) {
      return text;
    }

    stops.sort();
    return text.substring(0, stops.first + 1);
  }
}

class _InsightBullet extends StatelessWidget {
  const _InsightBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentWarm,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.evoluaColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextMiniCardsCarousel extends StatelessWidget {
  const _ContextMiniCardsCarousel({
    required this.insight,
    required this.isInsightPreparing,
    required this.onOpenFutureMessages,
    required this.onOpenReflection,
    required this.onOpenInsight,
    required this.onOpenEvolutionMirror,
    required this.onOpenCareShare,
  });

  final CheckInAiInsight? insight;
  final bool isInsightPreparing;
  final VoidCallback onOpenFutureMessages;
  final VoidCallback onOpenReflection;
  final VoidCallback onOpenInsight;
  final VoidCallback onOpenEvolutionMirror;
  final VoidCallback onOpenCareShare;

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveBreakpoints.isCompact(context);
    final l10n = context.l10n;
    final cardWidth = compact ? 168.0 : 190.0;
    final cards = [
      _ContextMiniCard(
        width: cardWidth,
        icon: Icons.mail_outline_rounded,
        title: l10n.homeFutureLetter,
        subtitle: 'Escreva ou leia uma mensagem sua.',
        color: AppColors.accent,
        onTap: onOpenFutureMessages,
      ),
      _ContextMiniCard(
        width: cardWidth,
        icon: Icons.health_and_safety_outlined,
        title: 'Evolua Care',
        subtitle: 'Compartilhe com seu terapeuta.',
        color: AppColors.accent,
        onTap: onOpenCareShare,
      ),
      _ContextMiniCard(
        width: cardWidth,
        icon: Icons.edit_note_rounded,
        title: l10n.homeRecentReflection,
        subtitle: 'Volte para o que você sentiu.',
        color: AppColors.accentWarm,
        onTap: onOpenReflection,
      ),
      _ContextMiniCard(
        width: cardWidth,
        icon: Icons.bolt_rounded,
        title: l10n.homeQuickInsight,
        subtitle: insight != null
            ? 'Veja a leitura do momento.'
            : isInsightPreparing
            ? 'Preparando sua leitura.'
            : 'Faça um check-in para liberar.',
        color: AppColors.accentGold,
        onTap: onOpenInsight,
      ),
      _ContextMiniCard(
        width: cardWidth,
        icon: Icons.auto_graph_rounded,
        title: l10n.homeEvolutionMilestone,
        subtitle: 'Compare seu agora com antes.',
        color: AppColors.accent,
        onTap: onOpenEvolutionMirror,
      ),
    ];

    return Semantics(
      label: 'Atalhos contextuais da Home',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (final (index, card) in cards.indexed) ...[
              if (index > 0) const SizedBox(width: 10),
              card,
            ],
          ],
        ),
      ),
    );
  }
}

class _ContextMiniCard extends StatelessWidget {
  const _ContextMiniCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.42),
              border: Border.all(
                color: context.evoluaColors.outline.withValues(alpha: 0.58),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: color.withValues(alpha: 0.14),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      semanticLabel: 'Próximo passo principal',
      padding: EdgeInsets.all(compact ? 24 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            eyebrow: 'O que faço agora?',
            title: 'Próximo passo',
            subtitle:
                'A ação principal do seu dia, escolhida para caber no seu momento.',
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
                label: const Text('Espaços'),
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
    required this.onOpenEvolutionMirror,
    required this.onOpenLastCheckIns,
    required this.onOpenProfile,
  });

  final bool compact;
  final _RhythmSummary summary;
  final VoidCallback onOpenEvolutionMirror;
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
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _rhythmActions(),
            )
          else
            Wrap(spacing: 12, runSpacing: 12, children: _rhythmActions()),
        ],
      ),
    );
  }

  List<Widget> _rhythmActions() {
    final actions = [
      OutlinedButton.icon(
        onPressed: onOpenEvolutionMirror,
        icon: const Icon(Icons.auto_graph_rounded),
        label: const Text(
          'Ver Espelho da Evolução',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      TextButton.icon(
        onPressed: onOpenLastCheckIns,
        icon: const Icon(Icons.history_rounded),
        label: const Text(
          'Ver últimos check-ins',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      TextButton.icon(
        onPressed: onOpenProfile,
        icon: const Icon(Icons.person_rounded),
        label: const Text('Ver perfil'),
      ),
    ];

    if (!compact) {
      return actions;
    }

    return [
      for (final (index, action) in actions.indexed) ...[
        if (index > 0) const SizedBox(height: 8),
        action,
      ],
    ];
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
              label: 'Energia média',
              value: '${summary.averageEnergy.toStringAsFixed(1)}/10',
            ),
            _RhythmMetric(
              icon: Icons.schedule_rounded,
              label: 'Melhor horário',
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
          'Consistência da semana',
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
              ? 'Seu ritmo ainda está se formando. Um check-in curto já ajuda a criar contexto.'
              : 'Você registrou ${summary.weeklyCheckIns} momento(s) nesta semana.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 22),
        Text(
          'Últimos check-ins',
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
              'Seus próximos check-ins aparecem aqui.',
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
            label: const Text('Abrir Espelho da Evolução'),
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
        benefit: 'mantém constância',
        reason: 'trilha ativa',
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
        ? 'sem padrão ainda'
        : _capitalize(_dominantMood(items));
    final bestTime = _bestTimeWindow(items);
    final weeklyCheckIns = _weeklyCheckIns(items);
    final streak = _calculateStreak(items);
    final energyTrend = _energyTrend(items);
    final timeInsight = items.isEmpty
        ? 'Seu melhor horario aparece depois dos primeiros registros.'
        : 'Você tem respondido melhor em torno de $bestTime.';
    final personalInsight = items.isEmpty
        ? 'Seu ritmo comeca a ficar claro a partir dos próximos check-ins.'
        : activeJourneyTitle == null
        ? 'Seu estado dominante recente foi $dominantMood, com energia média ${averageEnergy.toStringAsFixed(1)}/10.'
        : 'Você mantém uma jornada ativa e seu padrão recente aponta para $dominantMood.';

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
    return 'Ainda não ha oscilação suficiente para comparar.';
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

String _compactText(String value, {required int maxLength}) {
  final text = value.trim();
  if (text.length <= maxLength) {
    return _stripTrailingSentenceMark(text);
  }

  final clipped = text.substring(0, maxLength).trimRight();
  final lastSpace = clipped.lastIndexOf(' ');
  final safeClip = lastSpace > 24 ? clipped.substring(0, lastSpace) : clipped;
  return '${_stripTrailingSentenceMark(safeClip)}...';
}

String _stripTrailingSentenceMark(String value) {
  return value.replaceFirst(RegExp(r'[.!?]+$'), '');
}
