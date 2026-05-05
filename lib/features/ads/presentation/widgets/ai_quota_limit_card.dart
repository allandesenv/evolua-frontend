import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AiQuotaLimitCard extends StatelessWidget {
  const AiQuotaLimitCard({
    super.key,
    this.message,
    required this.rewardedAdAvailable,
    required this.upgradeRecommended,
    this.isRewardLoading = false,
    this.onWatchRewardedAd,
    this.onOpenPremium,
  });

  final String? message;
  final bool rewardedAdAvailable;
  final bool upgradeRecommended;
  final bool isRewardLoading;
  final VoidCallback? onWatchRewardedAd;
  final VoidCallback? onOpenPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_clock_rounded, color: AppColors.accentGold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Limite de IA atingido',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message?.trim().isNotEmpty == true
                ? message!.trim()
                : 'Seu plano gratuito chegou ao limite de IA de hoje. O check-in continua salvo normalmente.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
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
                      : const Icon(Icons.ondemand_video_rounded),
                  label: Text(
                    isRewardLoading
                        ? 'Carregando anuncio'
                        : 'Assistir anuncio para +1 analise',
                  ),
                ),
              if (upgradeRecommended && onOpenPremium != null)
                OutlinedButton.icon(
                  onPressed: onOpenPremium,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('Assinar Premium'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

