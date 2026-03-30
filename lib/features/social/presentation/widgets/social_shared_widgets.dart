import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:flutter/material.dart';

class SocialMetaPill extends StatelessWidget {
  const SocialMetaPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.surfaceStrong.withValues(alpha: 0.7),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
            ),
      ),
    );
  }
}

class SocialLoadingState extends StatelessWidget {
  const SocialLoadingState({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HeroSkeleton(showActions: false, key: ValueKey(label)),
        const SizedBox(height: 16),
        const FeedSkeleton(cards: 3),
      ],
    );
  }
}

class SocialActionableErrorState extends StatelessWidget {
  const SocialActionableErrorState({
    super.key,
    required this.title,
    required this.onRetry,
  });

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GuidedEmptyState(
      icon: Icons.error_outline_rounded,
      title: title,
      subtitle: 'Atualize a area ou tente novamente daqui a pouco.',
      actionLabel: 'Tentar novamente',
      onAction: onRetry,
    );
  }
}
