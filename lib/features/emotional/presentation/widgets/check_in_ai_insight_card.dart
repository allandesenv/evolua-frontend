import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

class CheckInAiInsightCard extends StatelessWidget {
  const CheckInAiInsightCard({
    super.key,
    required this.insight,
    this.onOpenTrails,
  });

  final CheckInAiInsight insight;
  final VoidCallback? onOpenTrails;

  @override
  Widget build(BuildContext context) {
    final riskColor = switch (insight.riskLevel.toLowerCase()) {
      'high' => AppColors.accentWarm,
      'medium' => AppColors.accentGold,
      _ => AppColors.accent,
    };
    final hasLimitedContext = insight.insight.toLowerCase().contains('sem muitos detalhes');
    final trailLabel = insight.suggestedTrailTitle == null ? 'Abrir trilhas' : 'Abrir trilha sugerida';

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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: riskColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'Risco ${insight.riskLevel}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: riskColor),
                ),
              ),
              if (insight.fallbackUsed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceStrong.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Contexto parcial',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
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
                border: Border.all(color: AppColors.outline.withValues(alpha: 0.28)),
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
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
              onPressed: onOpenTrails,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(trailLabel),
            ),
          ],
        ],
      ),
    );
  }
}
