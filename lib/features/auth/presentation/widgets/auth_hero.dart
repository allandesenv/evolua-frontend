import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/shared/presentation/widgets/evolua_logo.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

class AuthHero extends StatelessWidget {
  const AuthHero({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EvoluaLogo(),
        const SizedBox(height: 28),
        Text(
          'Um espaco calmo para voltar a si e seguir com mais clareza.',
          style: theme.textTheme.displayMedium,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Entenda como voce esta, receba uma direcao simples para o agora e transforme pequenas praticas em progresso perceptivel.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: const [
            _SignalChip(
              icon: Icons.track_changes_rounded,
              label: 'Check-ins e diario emocional',
            ),
            _SignalChip(
              icon: Icons.library_books_rounded,
              label: 'Trilhas, audios e exercicios',
            ),
            _SignalChip(
              icon: Icons.groups_rounded,
              label: 'Rede social e comunidade',
            ),
          ],
        ),
        const SizedBox(height: 32),
        const PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O que voce encontra aqui',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 18),
              _HeroMetric(
                value: '7',
                title: 'frentes da experiencia',
                subtitle: 'Cuidado pessoal, trilhas, comunidade, conversa, progresso e planos.',
              ),
              SizedBox(height: 16),
              _HeroMetric(
                value: '<2s',
                title: 'resposta rapida',
                subtitle: 'Fluxos pensados para caber no ritmo do dia a dia.',
              ),
              SizedBox(height: 16),
              _HeroMetric(
                value: 'Web + Mobile',
                title: 'uma experiencia continua',
                subtitle: 'A mesma jornada no navegador e no celular, com linguagem consistente.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final String value;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.accentGold,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
