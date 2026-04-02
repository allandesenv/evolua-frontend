import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/presentation/widgets/check_in_ai_insight_card.dart';
import 'package:evolua_frontend/features/emotional/presentation/widgets/emotional_module_view.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeHubView extends ConsumerStatefulWidget {
  const HomeHubView({
    super.key,
    required this.profilesCount,
    required this.trailsCount,
    required this.checkInsCount,
    required this.postsCount,
    required this.communitiesCount,
    required this.onOpenTrails,
    required this.onOpenFeed,
    required this.onOpenCommunity,
    required this.onOpenChat,
    required this.onOpenProfile,
  });

  final int profilesCount;
  final int trailsCount;
  final int checkInsCount;
  final int postsCount;
  final int communitiesCount;
  final VoidCallback onOpenTrails;
  final VoidCallback onOpenFeed;
  final VoidCallback onOpenCommunity;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenProfile;

  @override
  ConsumerState<HomeHubView> createState() => _HomeHubViewState();
}

class _HomeHubViewState extends ConsumerState<HomeHubView> {
  final List<String> _moodOptions = const ['Calmo', 'Presente', 'Cansado', 'Ansioso'];
  final _reflectionController = TextEditingController();
  String _selectedMood = 'Calmo';
  double _energyLevel = 7;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(checkInControllerProvider, (previous, next) {
      if (!next.hasError || !mounted) {
        return;
      }

      final error = next.error;
      final message = error is DioException
          ? (error.response?.data is Map<String, dynamic>
              ? ((error.response?.data['details'] as List?)?.join(', ') ??
                  error.message ??
                  'Nao foi possivel salvar o check-in.')
              : error.message ?? 'Nao foi possivel salvar o check-in.')
          : 'Nao foi possivel salvar o check-in.';

      AppSnackBar.show(
        context,
        message: message,
        icon: Icons.favorite_border_rounded,
      );
    });
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _submitQuickCheckIn() async {
    await ref.read(checkInControllerProvider.notifier).create(
          mood: _selectedMood.toLowerCase(),
          reflection:
              _reflectionController.text.trim().isEmpty ? null : _reflectionController.text.trim(),
          energyLevel: _energyLevel.round(),
        );

    if (!mounted) {
      return;
    }

    _reflectionController.clear();

    AppSnackBar.show(
      context,
      message: 'Check-in registrado. Continue no seu ritmo.',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveBreakpoints.isCompact(context);
    final checkInState = ref.watch(checkInControllerProvider);
    final latestInsight = checkInState.asData?.value.latestCreatedCheckIn?.aiInsight;
    final result = checkInState.asData?.value.result;
    final recentItems = result?.items ?? const [];
    final streak = _calculateStreak(recentItems);
    final averageEnergy = recentItems.isEmpty
        ? _energyLevel.round()
        : (recentItems.fold<int>(0, (sum, item) => sum + item.energyLevel) / recentItems.length)
            .round();
    final paceLabel = switch (widget.trailsCount) {
      0 => 'Monte sua primeira trilha pessoal',
      _ when widget.checkInsCount == 0 => 'Registre como voce esta para receber a direcao do dia',
      _ when widget.postsCount == 0 => 'Passe no feed e encontre uma conversa para hoje',
      _ => 'Respiracao guiada - 5 min',
    };
    final paceAction = switch (widget.trailsCount) {
      0 => widget.onOpenTrails,
      _ when widget.checkInsCount == 0 => _submitQuickCheckIn,
      _ when widget.postsCount == 0 => widget.onOpenFeed,
      _ => widget.onOpenTrails,
    };
    final paceButtonLabel = switch (widget.trailsCount) {
      0 => 'Ver trilhas',
      _ when widget.checkInsCount == 0 => 'Fazer check-in',
      _ when widget.postsCount == 0 => 'Abrir feed',
      _ => 'Comecar agora',
    };

    return Column(
      children: [
        PrimaryPanel(
          semanticLabel: 'Foco do dia',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoje',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.accent,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Como voce esta se sentindo?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _moodOptions
                    .map(
                      (mood) => ChoiceChip(
                        label: Text(mood),
                        selected: _selectedMood == mood,
                        onSelected: (_) => setState(() => _selectedMood = mood),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text(
                'Energia: ${_energyLevel.round()}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              Slider(
                min: 1,
                max: 10,
                divisions: 9,
                value: _energyLevel,
                onChanged: (value) => setState(() => _energyLevel = value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reflectionController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Se quiser, conte o motivo do seu estado atual',
                  hintText: 'Isso ajuda a IA a responder com mais precisao.',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: checkInState.isLoading && !checkInState.hasValue
                        ? null
                        : _submitQuickCheckIn,
                    icon: const Icon(Icons.favorite_rounded),
                    label: const Text('Fazer check-in'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showDetails = !_showDetails),
                    icon: Icon(
                      _showDetails ? Icons.expand_less_rounded : Icons.insights_rounded,
                    ),
                    label: Text(
                      _showDetails ? 'Ocultar detalhes' : 'Ver detalhes do seu ritmo',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (latestInsight != null) ...[
          const SizedBox(height: 16),
          CheckInAiInsightCard(
            insight: latestInsight,
            onOpenTrails: widget.onOpenTrails,
          ),
        ],
        const SizedBox(height: 16),
        PrimaryPanel(
          semanticLabel: 'Proxima acao',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Proximo passo',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.accentWarm,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                paceLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Uma unica acao agora vale mais do que abrir muitas frentes ao mesmo tempo.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: paceAction,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(paceButtonLabel),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenCommunity,
                    icon: const Icon(Icons.groups_rounded),
                    label: const Text('Comunidade'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenChat,
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text('Chat'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryPanel(
          semanticLabel: 'Seu ritmo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seu ritmo',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.accentGold,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _RhythmMetric(
                    width: compact ? double.infinity : 170,
                    label: 'Sequencia',
                    value: '$streak dias',
                    hint: streak == 0 ? 'Seu ritmo comeca hoje' : 'Consistencia em construo',
                  ),
                  _RhythmMetric(
                    width: compact ? double.infinity : 170,
                    label: 'Energia media',
                    value: '$averageEnergy/10',
                    hint: 'Baseada nos registros recentes',
                  ),
                  _RhythmMetric(
                    width: compact ? double.infinity : 170,
                    label: 'Feed ativo',
                    value: '${widget.postsCount}',
                    hint: widget.postsCount == 0 ? 'Ainda sem posts para hoje' : 'Conversas em movimento',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onOpenFeed,
                    icon: const Icon(Icons.dynamic_feed_rounded),
                    label: const Text('Abrir feed'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenProfile,
                    icon: const Icon(Icons.person_rounded),
                    label: const Text('Ver perfil'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_showDetails) ...[
          const SizedBox(height: 16),
          const EmotionalModuleView(),
        ],
      ],
    );
  }

  int _calculateStreak(List<dynamic> items) {
    if (items.isEmpty) {
      return 0;
    }

    final days = items
        .map((item) => DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);

    for (final day in days) {
      final expected = cursor.subtract(Duration(days: streak));
      if (day == expected) {
        streak++;
        continue;
      }

      if (streak == 0 && day == expected.subtract(const Duration(days: 1))) {
        streak++;
        continue;
      }

      break;
    }

    return streak;
  }
}

class _RhythmMetric extends StatelessWidget {
  const _RhythmMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.hint,
  });

  final double width;
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surfaceStrong.withValues(alpha: 0.42),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 6),
          Text(hint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
