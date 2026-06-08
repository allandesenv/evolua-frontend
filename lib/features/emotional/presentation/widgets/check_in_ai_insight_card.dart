import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/ads/presentation/widgets/ai_quota_limit_card.dart';
import 'package:evolua_frontend/features/ads/presentation/widgets/monetization_prompt.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CheckInAiInsightCard extends ConsumerWidget {
  const CheckInAiInsightCard({
    super.key,
    required this.insight,
    this.onOpenTrails,
    this.isRewardLoading = false,
    this.onWatchRewardedAd,
    this.onOpenPremium,
    this.onRegenerate,
    this.onSaveReading,
    this.onCreateRitual,
    this.isReadingActionLoading = false,
    this.readingActionLoading,
    this.isSaved = false,
  });

  final CheckInAiInsight insight;
  final ValueChanged<int>? onOpenTrails;
  final bool isRewardLoading;
  final VoidCallback? onWatchRewardedAd;
  final VoidCallback? onOpenPremium;
  final ValueChanged<String>? onRegenerate;
  final VoidCallback? onSaveReading;
  final VoidCallback? onCreateRitual;
  final bool isReadingActionLoading;
  final ReadingActionLoading? readingActionLoading;
  final bool isSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = onRegenerate == null
        ? true
        : ref
                  .watch(subscriptionControllerProvider)
                  .asData
                  ?.value
                  .current
                  ?.premium ??
              false;
    final riskColor = switch (insight.riskLevel.toLowerCase()) {
      'high' => AppColors.accentWarm,
      'medium' => AppColors.accentGold,
      _ => AppColors.accent,
    };
    final hasLimitedContext = insight.insight.toLowerCase().contains(
      'sem muitos detalhes',
    );
    final contextSignals = insight.contextSignals.take(3).toList();
    final canCreateRitual =
        onCreateRitual != null &&
        insight.nextStep?.type.toLowerCase() == 'ritual';
    final trailLabel = insight.suggestedTrailTitle == null
        ? 'Abrir trilhas'
        : 'Abrir trilha sugerida';
    final deepReadingSections = _deepReadingSections(insight);
    final hasDeepReading = deepReadingSections.isNotEmpty;

    return PrimaryPanel(
      semanticLabel: 'Leitura inteligente do check-in',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Leitura inteligente',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: riskColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'Risco ${insight.riskLevel}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: riskColor),
                ),
              ),
              if (insight.fallbackUsed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceStrong.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Modo seguro',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              if (hasLimitedContext)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceStrong.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Contexto parcial',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              if (contextSignals.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    'Personalizada',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (contextSignals.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final signal in contextSignals)
                  _ContextSignalChip(label: signal),
              ],
            ),
          ],
          if ((insight.usedContextSummary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              insight.usedContextSummary!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          if (hasDeepReading)
            _DeepReadingSummary(
              title: insight.title,
              sections: deepReadingSections,
            )
          else
            Text(insight.insight, style: Theme.of(context).textTheme.bodyLarge),
          if (hasLimitedContext) ...[
            const SizedBox(height: 10),
            Text(
              'Se voce quiser, no proximo check-in conte rapidamente o que influenciou esse momento para receber uma leitura mais precisa.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            insight.suggestedAction,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
          ),
          if (insight.nextStep != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      insight.nextStep!.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (insight.suggestedTrailReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              insight.suggestedTrailTitle == null
                  ? insight.suggestedTrailReason
                  : '${insight.suggestedTrailTitle}: ${insight.suggestedTrailReason}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (insight.journeyPlan != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceStrong.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.outline.withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.journeyPlan!.journeyTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${insight.journeyPlan!.phaseLabel} • ${insight.journeyPlan!.summary}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
          if (insight.suggestedSpace != null) ...[
            const SizedBox(height: 14),
            Text(
              'Espaco sugerido: ${insight.suggestedSpace!.name}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              insight.suggestedSpace!.reason,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (onOpenTrails != null && insight.suggestedTrailId != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => onOpenTrails?.call(insight.suggestedTrailId!),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(trailLabel),
            ),
          ],
          if (onRegenerate != null ||
              onSaveReading != null ||
              canCreateRitual) ...[
            const SizedBox(height: 16),
            _ReadingActionBar(
              isLoading: isReadingActionLoading || readingActionLoading != null,
              loadingAction: readingActionLoading,
              isSaved: isSaved,
              onRegenerate: onRegenerate == null
                  ? null
                  : (style) => _handleRegenerate(
                      context,
                      isPremium: isPremium,
                      style: style,
                    ),
              onSaveReading: onSaveReading,
              onCreateRitual: canCreateRitual ? onCreateRitual : null,
            ),
          ],
          if (insight.quotaLimited) ...[
            const SizedBox(height: 16),
            AiQuotaLimitCard(
              message: insight.limitMessage,
              rewardedAdAvailable: insight.rewardedAdAvailable,
              upgradeRecommended: insight.upgradeRecommended,
              isRewardLoading: isRewardLoading,
              onWatchRewardedAd: onWatchRewardedAd,
              onOpenPremium: onOpenPremium,
            ),
          ],
        ],
      ),
    );
  }

  List<_DeepReadingSectionData> _deepReadingSections(CheckInAiInsight insight) {
    final sections = [
      _DeepReadingSectionData(
        title: 'O que aparece na superfície',
        body: insight.surface,
      ),
      _DeepReadingSectionData(
        title: 'O que pode estar por trás',
        body: insight.behind,
      ),
      _DeepReadingSectionData(
        title: 'O estado interno identificado',
        body: insight.identifiedState,
      ),
      _DeepReadingSectionData(
        title: 'Pergunta reveladora',
        body: insight.revealingQuestion,
      ),
      _DeepReadingSectionData(
        title: 'Novo estado possível',
        body: insight.possibleNewState,
      ),
      _DeepReadingSectionData(title: 'Microação', body: insight.microAction),
    ];
    return sections
        .where((section) => (section.body ?? '').trim().isNotEmpty)
        .toList(growable: false);
  }

  void _handleRegenerate(
    BuildContext context, {
    required bool isPremium,
    required String style,
  }) {
    if (isPremium) {
      onRegenerate?.call(style);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SoftPremiumPrompt(
          title: 'Recurso Premium',
          message:
              'Os refinamentos da leitura inteligente fazem parte do Premium.',
          benefit:
              'Assine para gerar versões mais curtas, profundas, práticas e variadas das suas leituras.',
          onOpenPremium: onOpenPremium == null
              ? null
              : () {
                  Navigator.of(sheetContext).maybePop();
                  onOpenPremium?.call();
                },
          onSecondary: () => Navigator.of(sheetContext).maybePop(),
        ),
      ),
    );
  }
}

enum ReadingActionLoading { quick, deep, practical, balanced, save, ritual }

class _DeepReadingSectionData {
  const _DeepReadingSectionData({required this.title, required this.body});

  final String title;
  final String? body;
}

class _DeepReadingSummary extends StatelessWidget {
  const _DeepReadingSummary({required this.title, required this.sections});

  final String? title;
  final List<_DeepReadingSectionData> sections;

  @override
  Widget build(BuildContext context) {
    final safeTitle = title?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (safeTitle != null && safeTitle.isNotEmpty) ...[
            Text(
              safeTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (var index = 0; index < sections.length; index++) ...[
            _DeepReadingSection(section: sections[index]),
            if (index < sections.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DeepReadingSection extends StatelessWidget {
  const _DeepReadingSection({required this.section});

  final _DeepReadingSectionData section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(section.body!.trim(), style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ContextSignalChip extends StatelessWidget {
  const _ContextSignalChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.18)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ReadingActionBar extends StatelessWidget {
  const _ReadingActionBar({
    required this.isLoading,
    required this.loadingAction,
    required this.isSaved,
    required this.onRegenerate,
    required this.onSaveReading,
    required this.onCreateRitual,
  });

  final bool isLoading;
  final ReadingActionLoading? loadingAction;
  final bool isSaved;
  final ValueChanged<String>? onRegenerate;
  final VoidCallback? onSaveReading;
  final VoidCallback? onCreateRitual;

  @override
  Widget build(BuildContext context) {
    const loadingIcon = SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    Widget actionIcon(ReadingActionLoading action, IconData icon) {
      return loadingAction == action ? loadingIcon : Icon(icon);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (onRegenerate != null) ...[
          OutlinedButton.icon(
            onPressed: isLoading ? null : () => onRegenerate!('quick'),
            icon: actionIcon(
              ReadingActionLoading.quick,
              Icons.compress_rounded,
            ),
            label: Text(
              loadingAction == ReadingActionLoading.quick
                  ? 'Gerando...'
                  : 'Mais curta',
            ),
          ),
          OutlinedButton.icon(
            onPressed: isLoading ? null : () => onRegenerate!('deep'),
            icon: actionIcon(
              ReadingActionLoading.deep,
              Icons.auto_awesome_rounded,
            ),
            label: Text(
              loadingAction == ReadingActionLoading.deep
                  ? 'Gerando...'
                  : 'Mais profunda',
            ),
          ),
          OutlinedButton.icon(
            onPressed: isLoading ? null : () => onRegenerate!('practical'),
            icon: actionIcon(
              ReadingActionLoading.practical,
              Icons.checklist_rounded,
            ),
            label: Text(
              loadingAction == ReadingActionLoading.practical
                  ? 'Gerando...'
                  : 'Mais pratica',
            ),
          ),
          OutlinedButton.icon(
            onPressed: isLoading ? null : () => onRegenerate!('balanced'),
            icon: actionIcon(
              ReadingActionLoading.balanced,
              Icons.refresh_rounded,
            ),
            label: Text(
              loadingAction == ReadingActionLoading.balanced
                  ? 'Gerando...'
                  : 'Gerar outra versao',
            ),
          ),
        ],
        if (onSaveReading != null)
          FilledButton.tonalIcon(
            onPressed: isLoading || isSaved ? null : onSaveReading,
            icon: loadingAction == ReadingActionLoading.save
                ? loadingIcon
                : Icon(
                    isSaved
                        ? Icons.bookmark_added_rounded
                        : Icons.bookmark_rounded,
                  ),
            label: Text(
              loadingAction == ReadingActionLoading.save
                  ? 'Salvando...'
                  : isSaved
                  ? 'Leitura salva'
                  : 'Salvar leitura',
            ),
          ),
        if (onCreateRitual != null)
          FilledButton.icon(
            onPressed: isLoading ? null : onCreateRitual,
            icon: loadingAction == ReadingActionLoading.ritual
                ? loadingIcon
                : const Icon(Icons.self_improvement_rounded),
            label: Text(
              loadingAction == ReadingActionLoading.ritual
                  ? 'Criando ritual...'
                  : 'Transformar em ritual',
            ),
          ),
      ],
    );
  }
}
