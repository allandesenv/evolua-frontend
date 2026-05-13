import 'package:evolua_frontend/features/ads/presentation/widgets/monetization_prompt.dart';
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
    return RewardedAdPrompt(
      title: 'Limite de IA atingido',
      message: message?.trim().isNotEmpty == true
          ? message!.trim()
          : 'Sua jornada já está salva. O plano gratuito chegou ao limite de IA de hoje, mas você pode continuar amanhã sem perder nada.',
      rewardLabel: 'Assistir um anúncio libera +1 análise de IA hoje.',
      rewardedAdAvailable: rewardedAdAvailable,
      isRewardLoading: isRewardLoading,
      onWatchRewardedAd: onWatchRewardedAd,
      onOpenPremium: upgradeRecommended ? onOpenPremium : null,
      premiumLabel: 'Aprofundar com Premium',
    );
  }
}
