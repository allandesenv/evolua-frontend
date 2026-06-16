import 'package:evolua_frontend/core/network/api_error_message.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/application/consciousness_timeline_controller.dart';
import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConsciousnessTimelinePage extends ConsumerStatefulWidget {
  const ConsciousnessTimelinePage({super.key, this.now});

  final DateTime? now;

  @override
  ConsumerState<ConsciousnessTimelinePage> createState() =>
      _ConsciousnessTimelinePageState();
}

class _ConsciousnessTimelinePageState
    extends ConsumerState<ConsciousnessTimelinePage> {
  static const _ritualAlreadyExistsMessage =
      'Você já possui um ritual criado para hoje. Edite o ritual atual ou remova-o antes de gerar outro.';

  final _moodController = TextEditingController();
  _TimelinePeriod _period = _TimelinePeriod.thirtyDays;
  String? _energyRange;
  bool _rewardLoading = false;
  int? _actionLoadingCheckInId;

  @override
  void dispose() {
    _moodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timelineState = ref.watch(consciousnessTimelineProvider);
    return GradientScaffold(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TimelineHeader(onBack: _leaveTimeline),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverToBoxAdapter(
                child: timelineState.when(
                  loading: () => const _TimelineLoading(),
                  error: (error, _) => _TimelineError(
                    message: friendlyApiErrorMessage(
                      error,
                      context.l10n,
                      fallback:
                          'Não foi possível carregar sua linha do tempo agora.',
                    ),
                    onRetry: () =>
                        ref.invalidate(consciousnessTimelineProvider),
                  ),
                  data: (state) => _TimelineContent(
                    state: state,
                    moodController: _moodController,
                    selectedPeriod: _period,
                    selectedEnergyRange: _energyRange,
                    isRewardLoading: _rewardLoading,
                    actionLoadingCheckInId: _actionLoadingCheckInId,
                    onPeriodChanged: (period) => setState(() {
                      _period = period;
                    }),
                    onEnergyChanged: (value) => setState(() {
                      _energyRange = value;
                    }),
                    onApplyFilters: _applyFilters,
                    onClearFilters: _clearFilters,
                    onLoadMore: () {
                      ref
                          .read(consciousnessTimelineProvider.notifier)
                          .loadMore();
                    },
                    onUnlockFull: _unlockFull,
                    onOpenPremium: () =>
                        context.go('/home?profileSection=plans'),
                    onOpenItem: _openItemDetail,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyFilters() async {
    final range = _rangeForPeriod(_period);
    await ref
        .read(consciousnessTimelineProvider.notifier)
        .applyFilters(
          ConsciousnessTimelineFilters(
            mood: _moodController.text,
            energyRange: _energyRange,
            from: range.$1,
            to: range.$2,
          ),
        );
  }

  Future<void> _clearFilters() async {
    _moodController.clear();
    setState(() {
      _period = _TimelinePeriod.thirtyDays;
      _energyRange = null;
    });
    await ref.read(consciousnessTimelineProvider.notifier).clearFilters();
  }

  Future<void> _unlockFull() async {
    if (_rewardLoading) {
      return;
    }
    setState(() => _rewardLoading = true);
    try {
      final unlocked = await ref
          .read(consciousnessTimelineProvider.notifier)
          .unlockFullWithReward();
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: unlocked
            ? 'Histórico completo liberado para esta jornada.'
            : 'Não conseguimos carregar o anúncio agora. Você ainda pode ver seus últimos registros ou tentar novamente em instantes.',
        icon: unlocked ? Icons.lock_open_rounded : Icons.wifi_off_rounded,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message:
            'Não conseguimos carregar o anúncio agora. Você ainda pode ver seus últimos registros ou tentar novamente em instantes.',
        icon: Icons.wifi_off_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _rewardLoading = false);
      }
    }
  }

  Future<void> _openItemDetail(ConsciousnessTimelineItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.evoluaColors.surface,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => _TimelineItemDetail(
          item: item,
          scrollController: controller,
          isActionLoading: _actionLoadingCheckInId == item.checkInId,
          onSaveReading: item.checkInId <= 0 || item.savedReading
              ? null
              : () => _saveReading(item),
          onCreateRitual: item.checkInId <= 0
              ? null
              : () => _createRitual(item),
          createRitualLabel: _isEveningPeriod
              ? 'Fazer fechamento'
              : 'Criar ritual',
          createRitualLoadingLabel: _isEveningPeriod
              ? 'Abrindo...'
              : 'Criando...',
        ),
      ),
    );
  }

  Future<void> _saveReading(ConsciousnessTimelineItem item) async {
    await _runItemAction(item, () async {
      await ref
          .read(checkInControllerProvider.notifier)
          .saveReading(item.checkInId);
      final filters =
          ref.read(consciousnessTimelineProvider).asData?.value.filters ??
          const ConsciousnessTimelineFilters();
      await ref
          .read(consciousnessTimelineProvider.notifier)
          .loadInitial(filters: filters);
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Leitura salva para você voltar a ela depois.',
          icon: Icons.bookmark_added_rounded,
        );
      }
    });
  }

  Future<void> _createRitual(ConsciousnessTimelineItem item) async {
    await _runItemAction(item, () async {
      final now = widget.now ?? DateTime.now();
      final localDate = DateTime(now.year, now.month, now.day);
      final type = now.hour >= 18
          ? DailyRitualType.evening
          : DailyRitualType.morning;
      if (type == DailyRitualType.evening) {
        if (mounted) {
          context.go('/daily-ritual?type=evening');
        }
        return;
      }
      final existing = await ref
          .read(dailyRitualRepositoryProvider)
          .today(type: type, localDate: localDate);
      if (existing != null) {
        await ref
            .read(dailyRitualControllerProvider.notifier)
            .refresh(localDate: localDate);
        if (mounted) {
          AppSnackBar.show(
            context,
            message: _ritualAlreadyExistsMessage,
            icon: Icons.info_outline_rounded,
            actionLabel: 'Abrir ritual',
            onAction: () => context.go(
              '/daily-ritual?type=${DailyRitualType.toRouteValue(type)}',
            ),
          );
        }
        return;
      }
      await ref
          .read(checkInControllerProvider.notifier)
          .createRitualFromReading(
            item.checkInId,
            localDate: localDate,
            type: type,
          );
      if (mounted) {
        AppSnackBar.show(
          context,
          message: type == DailyRitualType.evening
              ? 'Fechamento do dia criado a partir desta leitura.'
              : 'Ritual do dia criado a partir desta leitura.',
          icon: Icons.self_improvement_rounded,
        );
      }
    });
  }

  bool get _isEveningPeriod {
    final now = widget.now ?? DateTime.now();
    return now.hour >= 18;
  }

  Future<void> _runItemAction(
    ConsciousnessTimelineItem item,
    Future<void> Function() action,
  ) async {
    if (_actionLoadingCheckInId != null) {
      return;
    }
    setState(() => _actionLoadingCheckInId = item.checkInId);
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: friendlyApiErrorMessage(
          error,
          context.l10n,
          fallback:
              'Não foi possível concluir esta ação agora. Tente novamente em instantes.',
        ),
        icon: Icons.info_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoadingCheckInId = null);
      }
    }
  }

  (DateTime?, DateTime?) _rangeForPeriod(_TimelinePeriod period) {
    if (period == _TimelinePeriod.all) {
      return (null, null);
    }
    final today = DateTime.now();
    final start = today.subtract(
      Duration(days: period == _TimelinePeriod.sevenDays ? 7 : 30),
    );
    return (start, today);
  }

  Future<void> _leaveTimeline() async {
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({required this.onBack});

  final Future<void> Function() onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
        const SizedBox(height: 12),
        Text(
          'Linha do Tempo da Consciência',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Um lugar para perceber como seus estados internos vêm mudando, sem julgamento.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _TimelineContent extends StatelessWidget {
  const _TimelineContent({
    required this.state,
    required this.moodController,
    required this.selectedPeriod,
    required this.selectedEnergyRange,
    required this.isRewardLoading,
    required this.actionLoadingCheckInId,
    required this.onPeriodChanged,
    required this.onEnergyChanged,
    required this.onApplyFilters,
    required this.onClearFilters,
    required this.onLoadMore,
    required this.onUnlockFull,
    required this.onOpenPremium,
    required this.onOpenItem,
  });

  final ConsciousnessTimelineState state;
  final TextEditingController moodController;
  final _TimelinePeriod selectedPeriod;
  final String? selectedEnergyRange;
  final bool isRewardLoading;
  final int? actionLoadingCheckInId;
  final ValueChanged<_TimelinePeriod> onPeriodChanged;
  final ValueChanged<String?> onEnergyChanged;
  final VoidCallback onApplyFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onLoadMore;
  final VoidCallback onUnlockFull;
  final VoidCallback onOpenPremium;
  final ValueChanged<ConsciousnessTimelineItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty && state.filters.isEmpty) {
      return const PrimaryPanel(
        child: Text(
          'Seus próximos check-ins vão começar a desenhar esta linha, no seu ritmo.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimelineFilters(
          moodController: moodController,
          selectedPeriod: selectedPeriod,
          selectedEnergyRange: selectedEnergyRange,
          onPeriodChanged: onPeriodChanged,
          onEnergyChanged: onEnergyChanged,
          onApply: onApplyFilters,
          onClear: onClearFilters,
        ),
        const SizedBox(height: 14),
        if (!state.fullAccess) ...[
          _TimelineUnlockCard(
            message: state.limitMessage,
            rewardedAdAvailable: state.rewardedAdAvailable,
            isLoading: isRewardLoading,
            onUnlockFull: onUnlockFull,
            onOpenPremium: onOpenPremium,
          ),
          const SizedBox(height: 14),
        ],
        if (state.items.isEmpty)
          const PrimaryPanel(
            child: Text(
              'Nenhum check-in apareceu com estes filtros. Você pode limpar os filtros e olhar por outro ângulo.',
            ),
          )
        else
          for (final item in state.items) ...[
            _TimelineItemCard(
              item: item,
              isActionLoading: actionLoadingCheckInId == item.checkInId,
              onTap: () => onOpenItem(item),
            ),
            const SizedBox(height: 12),
          ],
        if (state.hasNext) ...[
          const SizedBox(height: 4),
          Center(
            child: OutlinedButton.icon(
              onPressed: state.isLoadingMore ? null : onLoadMore,
              icon: state.isLoadingMore
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(
                state.isLoadingMore ? 'Carregando...' : 'Carregar mais',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimelineFilters extends StatelessWidget {
  const _TimelineFilters({
    required this.moodController,
    required this.selectedPeriod,
    required this.selectedEnergyRange,
    required this.onPeriodChanged,
    required this.onEnergyChanged,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController moodController;
  final _TimelinePeriod selectedPeriod;
  final String? selectedEnergyRange;
  final ValueChanged<_TimelinePeriod> onPeriodChanged;
  final ValueChanged<String?> onEnergyChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtros suaves',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final period in _TimelinePeriod.values)
                ChoiceChip(
                  label: Text(period.label),
                  selected: selectedPeriod == period,
                  onSelected: (_) => onPeriodChanged(period),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: moodController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Estado ou humor',
              hintText: 'Ex.: ansiedade, calma, cansaço',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onSubmitted: (_) => onApply(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Toda energia'),
                selected: selectedEnergyRange == null,
                onSelected: (_) => onEnergyChanged(null),
              ),
              for (final entry in const {
                'LOW': 'Baixa',
                'MEDIUM': 'Média',
                'HIGH': 'Alta',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: selectedEnergyRange == entry.key,
                  onSelected: (_) => onEnergyChanged(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.filter_alt_rounded),
                label: const Text('Aplicar filtros'),
              ),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Limpar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineUnlockCard extends StatelessWidget {
  const _TimelineUnlockCard({
    required this.message,
    required this.rewardedAdAvailable,
    required this.isLoading,
    required this.onUnlockFull,
    required this.onOpenPremium,
  });

  final String? message;
  final bool rewardedAdAvailable;
  final bool isLoading;
  final VoidCallback onUnlockFull;
  final VoidCallback onOpenPremium;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ver histórico completo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message ??
                'Você está vendo um resumo recente. O histórico completo pode ser liberado com anúncio recompensado ou Premium.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (rewardedAdAvailable)
                FilledButton.icon(
                  onPressed: isLoading ? null : onUnlockFull,
                  icon: isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_rounded),
                  label: Text(isLoading ? 'Carregando...' : 'Assistir anúncio'),
                ),
              OutlinedButton.icon(
                onPressed: isLoading ? null : onOpenPremium,
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Conhecer Premium'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineItemCard extends StatelessWidget {
  const _TimelineItemCard({
    required this.item,
    required this.isActionLoading,
    required this.onTap,
  });

  final ConsciousnessTimelineItem item;
  final bool isActionLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim().isEmpty
        ? 'Leitura do seu momento'
        : item.title.trim();
    return PrimaryPanel(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _TimelinePill(
                  icon: Icons.schedule_rounded,
                  label: _formatDateTime(item.createdAt),
                ),
                if (item.mood.trim().isNotEmpty)
                  _TimelinePill(
                    icon: Icons.favorite_rounded,
                    label: item.mood.trim(),
                  ),
                _TimelinePill(
                  icon: Icons.bolt_rounded,
                  label: 'Energia ${item.energyLevel ?? '-'}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (item.reflection.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.reflection.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (item.insight.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                item.insight.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.evoluaColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _TimelineField(
              label: 'Estado interno que parece aparecer',
              body: item.identifiedState,
            ),
            _TimelineField(
              label: 'Pergunta reveladora',
              body: item.revealingQuestion,
            ),
            _TimelineField(label: 'Microação', body: item.microAction),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isActionLoading ? null : onTap,
                icon: const Icon(Icons.open_in_full_rounded),
                label: const Text('Abrir detalhes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItemDetail extends StatelessWidget {
  const _TimelineItemDetail({
    required this.item,
    required this.scrollController,
    required this.isActionLoading,
    required this.onSaveReading,
    required this.onCreateRitual,
    required this.createRitualLabel,
    required this.createRitualLoadingLabel,
  });

  final ConsciousnessTimelineItem item;
  final ScrollController scrollController;
  final bool isActionLoading;
  final VoidCallback? onSaveReading;
  final VoidCallback? onCreateRitual;
  final String createRitualLabel;
  final String createRitualLoadingLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: context.evoluaColors.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Detalhes da leitura',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(_formatDateTime(item.createdAt)),
          const SizedBox(height: 18),
          _DetailSection(
            title: 'O que você registrou',
            body: [
              if (item.mood.trim().isNotEmpty) 'Estado: ${item.mood.trim()}',
              'Energia: ${item.energyLevel ?? '-'}',
              if (item.reflection.trim().isNotEmpty) item.reflection.trim(),
            ].join('\n'),
          ),
          _DetailSection(
            title: 'Leitura do seu momento',
            body: [
              if (item.title.trim().isNotEmpty) item.title.trim(),
              if (item.insight.trim().isNotEmpty) item.insight.trim(),
            ].join('\n\n'),
          ),
          _DetailSection(
            title: 'Estado interno que parece aparecer',
            body: item.identifiedState,
          ),
          _DetailSection(
            title: 'Pergunta reveladora',
            body: item.revealingQuestion,
          ),
          _DetailSection(
            title: 'Novo estado possível',
            body: item.possibleNewState,
          ),
          _DetailSection(title: 'Microação', body: item.microAction),
          if (onSaveReading != null || onCreateRitual != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onSaveReading != null)
                  FilledButton.tonalIcon(
                    onPressed: isActionLoading ? null : onSaveReading,
                    icon: isActionLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_rounded),
                    label: Text(
                      isActionLoading ? 'Salvando...' : 'Salvar leitura',
                    ),
                  ),
                if (onCreateRitual != null)
                  FilledButton.icon(
                    onPressed: isActionLoading ? null : onCreateRitual,
                    icon: isActionLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.self_improvement_rounded),
                    label: Text(
                      isActionLoading
                          ? createRitualLoadingLabel
                          : createRitualLabel,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (body.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.evoluaColors.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(body.trim()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineField extends StatelessWidget {
  const _TimelineField({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (body.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: body.trim()),
          ],
        ),
      ),
    );
  }
}

class _TimelinePill extends StatelessWidget {
  const _TimelinePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineLoading extends StatelessWidget {
  const _TimelineLoading();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _TimelineError extends StatelessWidget {
  const _TimelineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

enum _TimelinePeriod {
  sevenDays('7 dias'),
  thirtyDays('30 dias'),
  all('Tudo');

  const _TimelinePeriod(this.label);
  final String label;
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Data não informada';
  }
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} às $hour:$minute';
}
