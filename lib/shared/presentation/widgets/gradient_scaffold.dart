import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:flutter/material.dart';

class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.child,
    this.resizeToAvoidBottomInset,
  });

  final Widget child;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final colors = context.evoluaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.background,
              colors.backgroundSecondary,
              isDark ? const Color(0xFF0F1828) : colors.surfaceStrong,
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
                color: colors.accent.withValues(alpha: isDark ? 0.12 : 0.1),
                size: 300,
              ),
            ),
            Positioned(
              bottom: -120,
              right: -40,
              child: _GlowOrb(
                color: colors.accentWarm.withValues(alpha: isDark ? 0.1 : 0.08),
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
  const _GlowOrb({required this.color, required this.size});

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
            BoxShadow(color: color, blurRadius: 140, spreadRadius: 24),
          ],
        ),
      ),
    );
  }
}
