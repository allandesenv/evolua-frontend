import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              AppColors.backgroundSecondary,
              Color(0xFF0F1828),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -140,
              left: -60,
              child: _GlowOrb(
                color: AppColors.accent.withValues(alpha: 0.12),
                size: 300,
              ),
            ),
            Positioned(
              bottom: -120,
              right: -40,
              child: _GlowOrb(
                color: AppColors.accentWarm.withValues(alpha: 0.1),
                size: 260,
              ),
            ),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 140,
              spreadRadius: 24,
            ),
          ],
        ),
      ),
    );
  }
}
