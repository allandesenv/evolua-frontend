import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

class SoftPremiumPrompt extends StatelessWidget {
  const SoftPremiumPrompt({
    super.key,
    required this.title,
    required this.message,
    required this.onOpenPremium,
    this.benefit,
    this.primaryLabel = 'Conhecer Premium',
    this.secondaryLabel = 'Continuar no plano gratuito',
    this.onSecondary,
    this.icon = Icons.workspace_premium_rounded,
  });

  final String title;
  final String message;
  final String? benefit;
  final VoidCallback? onOpenPremium;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MonetizationIcon(icon: icon, color: AppColors.accentGold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.evoluaColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(message, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
          if (benefit != null && benefit!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                benefit!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.evoluaColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onOpenPremium != null)
                FilledButton.icon(
                  onPressed: onOpenPremium,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: Text(primaryLabel),
                ),
              if (onSecondary != null)
                TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
            ],
          ),
        ],
      ),
    );
  }
}

class RewardedAdPrompt extends StatelessWidget {
  const RewardedAdPrompt({
    super.key,
    required this.title,
    required this.message,
    required this.rewardLabel,
    required this.rewardedAdAvailable,
    required this.isRewardLoading,
    this.onWatchRewardedAd,
    this.onOpenPremium,
    this.onSecondary,
    this.premiumLabel = 'Aprofundar com Premium',
    this.watchLabel,
    this.loadingLabel = 'Carregando anúncio',
    this.secondaryLabel = 'Agora não',
  });

  final String title;
  final String message;
  final String rewardLabel;
  final bool rewardedAdAvailable;
  final bool isRewardLoading;
  final VoidCallback? onWatchRewardedAd;
  final VoidCallback? onOpenPremium;
  final VoidCallback? onSecondary;
  final String premiumLabel;
  final String? watchLabel;
  final String loadingLabel;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _MonetizationIcon(
                icon: Icons.ondemand_video_rounded,
                color: AppColors.accentGold,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.evoluaColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(message, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
          if (rewardedAdAvailable && rewardLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.evoluaColors.surfaceStrong.withValues(
                  alpha: 0.46,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.evoluaColors.outline.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                rewardLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.evoluaColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (rewardedAdAvailable && onWatchRewardedAd != null)
                FilledButton.icon(
                  onPressed: isRewardLoading ? null : onWatchRewardedAd,
                  icon: isRewardLoading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_rounded),
                  label: Text(
                    isRewardLoading
                        ? loadingLabel
                        : watchLabel ?? 'Assistir anúncio',
                  ),
                ),
              if (onOpenPremium != null)
                OutlinedButton.icon(
                  onPressed: isRewardLoading ? null : onOpenPremium,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: Text(premiumLabel),
                ),
              if (onSecondary != null)
                TextButton(
                  onPressed: isRewardLoading ? null : onSecondary,
                  child: Text(secondaryLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonetizationIcon extends StatelessWidget {
  const _MonetizationIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color),
    );
  }
}
