import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PrimaryPanel extends StatelessWidget {
  const PrimaryPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final panel = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.42),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );

    if (semanticLabel == null) {
      return panel;
    }

    return Semantics(
      container: true,
      label: semanticLabel,
      child: panel,
    );
  }
}
