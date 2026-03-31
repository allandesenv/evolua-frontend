import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

class InsightMetricCard extends StatelessWidget {
  const InsightMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.change,
    required this.tone,
  });

  final String label;
  final String value;
  final String change;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: PrimaryPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: tone.withValues(alpha: 0.16),
              ),
              child: Text(
                change,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tone,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
