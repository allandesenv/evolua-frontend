import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/admin_trail_management_view.dart';
import 'package:evolua_frontend/features/notification/presentation/widgets/notification_module_view.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

enum AdminPanelSection { overview, trails, notifications }

class AdminPanelView extends StatelessWidget {
  const AdminPanelView({
    super.key,
    required this.section,
    required this.onOpenSection,
  });

  final AdminPanelSection section;
  final ValueChanged<AdminPanelSection> onOpenSection;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      AdminPanelSection.overview => _AdminPanelOverview(
        onOpenSection: onOpenSection,
      ),
      AdminPanelSection.trails => const AdminTrailManagementView(),
      AdminPanelSection.notifications => const NotificationAdminConsole(),
    };
  }
}

class AdminAccessDeniedPanel extends StatelessWidget {
  const AdminAccessDeniedPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            color: context.evoluaColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Painel restrito',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Esta area esta disponivel apenas para administradores.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _AdminPanelOverview extends StatelessWidget {
  const _AdminPanelOverview({required this.onOpenSection});

  final ValueChanged<AdminPanelSection> onOpenSection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Painel Admin',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: context.evoluaColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gerencie conteudos e comunicacoes operacionais do Evolua em telas separadas.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _AdminActionCard(
              icon: Icons.auto_stories_rounded,
              title: 'Trilhas',
              subtitle: 'Criar, editar, excluir e revisar midias do catalogo.',
              onTap: () => onOpenSection(AdminPanelSection.trails),
            ),
            _AdminActionCard(
              icon: Icons.notifications_active_rounded,
              title: 'Notificações',
              subtitle: 'Enviar comunicacoes manuais para usuarios.',
              onTap: () => onOpenSection(AdminPanelSection.notifications),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: PrimaryPanel(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: AppColors.accent),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Abrir'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
