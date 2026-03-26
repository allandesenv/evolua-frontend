import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/emotional/presentation/widgets/emotional_module_view.dart';
import 'package:evolua_frontend/features/home/presentation/widgets/insight_metric_card.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

class HomeHubView extends StatefulWidget {
  const HomeHubView({
    super.key,
    required this.profilesCount,
    required this.trailsCount,
    required this.checkInsCount,
    required this.postsCount,
    required this.onOpenTrails,
    required this.onOpenCommunity,
    required this.onOpenChat,
    required this.onOpenProfile,
  });

  final int profilesCount;
  final int trailsCount;
  final int checkInsCount;
  final int postsCount;
  final VoidCallback onOpenTrails;
  final VoidCallback onOpenCommunity;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenProfile;

  @override
  State<HomeHubView> createState() => _HomeHubViewState();
}

class _HomeHubViewState extends State<HomeHubView> {
  final GlobalKey _checkInKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seu momento de agora',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Comece pelo check-in, receba uma direcao clara e siga em frente com uma unica proxima acao.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      final checkInContext = _checkInKey.currentContext;
                      if (checkInContext != null) {
                        Scrollable.ensureVisible(
                          checkInContext,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    icon: const Icon(Icons.favorite_rounded),
                    label: const Text('Fazer check-in'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenTrails,
                    icon: const Icon(Icons.auto_stories_rounded),
                    label: const Text('Ver trilhas'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenCommunity,
                    icon: const Icon(Icons.groups_rounded),
                    label: const Text('Explorar comunidade'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            InsightMetricCard(
              label: 'Progresso visivel',
              value: '${widget.checkInsCount} check-ins',
              change: widget.checkInsCount == 0 ? 'Seu primeiro registro comeca aqui' : 'Voce ja esta construindo um historico',
              tone: AppColors.accent,
            ),
            InsightMetricCard(
              label: 'Trilhas disponiveis',
              value: widget.trailsCount.toString(),
              change: widget.trailsCount == 0 ? 'Nenhuma pratica publicada ainda' : 'Escolha uma jornada e continue',
              tone: AppColors.accentWarm,
            ),
            InsightMetricCard(
              label: 'Rede de apoio',
              value: '${widget.postsCount} conversas',
              change: widget.postsCount == 0 ? 'Compartilhe quando fizer sentido' : 'Ha vida social acontecendo',
              tone: AppColors.accentGold,
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sugestao do dia',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.trailsCount == 0
                    ? 'Assim que suas trilhas estiverem prontas, este espaco vai sugerir a melhor proxima pratica.'
                    : 'Voce ja tem trilhas publicadas. Use este espaco para destacar a pratica certa para o estado emocional atual.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _QuickActionChip(
                    label: 'Perfil',
                    icon: Icons.person_rounded,
                      onTap: widget.onOpenProfile,
                  ),
                  _QuickActionChip(
                    label: 'Chat',
                    icon: Icons.chat_bubble_rounded,
                      onTap: widget.onOpenChat,
                  ),
                  _QuickActionChip(
                    label: 'Comunidade',
                    icon: Icons.forum_rounded,
                      onTap: widget.onOpenCommunity,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryPanel(
          child: Row(
            children: [
              Expanded(
                child: _MiniProgress(
                  label: 'Perfil pronto',
                    value: widget.profilesCount > 0 ? 'Sim' : 'Nao ainda',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniProgress(
                  label: 'Habito do dia',
                    value: widget.checkInsCount > 0 ? 'Registrado' : 'Pendente',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniProgress(
                  label: 'Proximo passo',
                    value: widget.trailsCount > 0 ? 'Praticar' : 'Criar trilha',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _checkInKey,
          child: const EmotionalModuleView(),
        ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 18, color: AppColors.accent),
      label: Text(label),
      side: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
      backgroundColor: AppColors.surfaceStrong.withValues(alpha: 0.6),
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.surfaceStrong.withValues(alpha: 0.65),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}
