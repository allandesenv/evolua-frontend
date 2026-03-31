import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

class PanelSkeleton extends StatelessWidget {
  const PanelSkeleton({
    super.key,
    this.rows = 3,
    this.tileHeight = 96,
  });

  final int rows;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        children: List.generate(
          rows,
          (index) => Container(
            width: double.infinity,
            height: tileHeight,
            margin: EdgeInsets.only(bottom: index == rows - 1 ? 0 : 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceStrong.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
      ),
    );
  }
}
