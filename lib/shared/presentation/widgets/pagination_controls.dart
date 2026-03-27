import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  const PaginationControls({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Anterior'),
        ),
        const Spacer(),
        Text(
          'Pagina ${page + 1} de $totalPages',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: page < totalPages - 1 ? () => onPageChanged(page + 1) : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Proxima'),
        ),
      ],
    );
  }
}
