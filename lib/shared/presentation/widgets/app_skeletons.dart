import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

class HeroSkeleton extends StatelessWidget {
  const HeroSkeleton({
    super.key,
    this.showActions = true,
  });

  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: 'Carregando destaque',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBox(width: 160, height: 14),
          const SizedBox(height: 14),
          const _SkeletonBox(width: 360, height: 30),
          const SizedBox(height: 10),
          const _SkeletonBox(width: double.infinity, height: 18),
          const SizedBox(height: 8),
          const _SkeletonBox(width: 280, height: 18),
          if (showActions) ...[
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _SkeletonPill(width: 170),
                _SkeletonPill(width: 150),
                _SkeletonPill(width: 182),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class FormSkeleton extends StatelessWidget {
  const FormSkeleton({
    super.key,
    this.fields = 3,
    this.showButton = true,
  });

  final int fields;
  final bool showButton;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: 'Carregando formulario',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBox(width: 220, height: 26),
          const SizedBox(height: 12),
          const _SkeletonBox(width: double.infinity, height: 18),
          const SizedBox(height: 22),
          ...List.generate(
            fields,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == fields - 1 ? 0 : 16),
              child: const _SkeletonBox(width: double.infinity, height: 58, radius: 22),
            ),
          ),
          if (showButton) ...[
            const SizedBox(height: 18),
            const _SkeletonPill(width: 190, height: 54),
          ],
        ],
      ),
    );
  }
}

class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({
    super.key,
    this.cards = 3,
  });

  final int cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        cards,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == cards - 1 ? 0 : 12),
          child: PrimaryPanel(
            semanticLabel: 'Carregando card',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBox(width: 180, height: 20),
                SizedBox(height: 12),
                _SkeletonBox(width: double.infinity, height: 16),
                SizedBox(height: 8),
                _SkeletonBox(width: 280, height: 16),
                SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SkeletonPill(width: 90, height: 30),
                    _SkeletonPill(width: 110, height: 30),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TimelineSkeleton extends StatelessWidget {
  const TimelineSkeleton({
    super.key,
    this.groups = 2,
  });

  final int groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HeroSkeleton(showActions: false),
        const SizedBox(height: 16),
        ...List.generate(
          groups,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == groups - 1 ? 0 : 12),
            child: PrimaryPanel(
              semanticLabel: 'Carregando linha do tempo',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SkeletonBox(width: 150, height: 20),
                  SizedBox(height: 16),
                  _SkeletonBox(width: double.infinity, height: 120, radius: 22),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 14,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? double.infinity : width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: AppColors.surfaceStrong.withValues(alpha: 0.36),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill({
    required this.width,
    this.height = 36,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _SkeletonBox(width: width, height: height, radius: 999);
  }
}
