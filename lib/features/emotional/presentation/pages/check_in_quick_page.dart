import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/ads/application/monetization_access_controller.dart';
import 'package:evolua_frontend/features/ads/presentation/widgets/monetization_prompt.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CheckInQuickPage extends StatelessWidget {
  const CheckInQuickPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      resizeToAvoidBottomInset: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveBreakpoints.pagePadding(context),
          vertical: 16,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: CheckInQuickView(
                onCompleted: () {
                  context.go('/home');
                },
                onCancel: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CheckInQuickView extends ConsumerStatefulWidget {
  const CheckInQuickView({super.key, this.onCompleted, this.onCancel});

  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;

  @override
  ConsumerState<CheckInQuickView> createState() => _CheckInQuickViewState();
}

class _CheckInQuickViewState extends ConsumerState<CheckInQuickView> {
  static const _quickMoodOptions = ['Calmo', 'Ansioso', 'Cansado', 'Distraído'];

  final _reflectionController = TextEditingController();
  String _selectedMood = 'Calmo';
  double _energyLevel = 7;
  bool _isSubmitting = false;
  bool _isRewardLoading = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(checkInControllerProvider, (previous, next) {
      if (!next.hasError || !mounted) {
        return;
      }

      AppSnackBar.show(
        context,
        message: _errorMessage(next.error),
        icon: Icons.favorite_border_rounded,
      );
    });
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(checkInControllerProvider.notifier)
          .create(
            mood: _selectedMood.toLowerCase(),
            reflection: _reflectionController.text.trim().isEmpty
                ? null
                : _reflectionController.text.trim(),
            energyLevel: _energyLevel.round(),
          );

      if (!mounted) {
        return;
      }

      _reflectionController.clear();
      final insight = ref
          .read(checkInControllerProvider)
          .asData
          ?.value
          .latestCreatedCheckIn
          ?.aiInsight;
      if (insight?.quotaLimited == true) {
        await _showDeepReadingUnlockSheet();
        return;
      }
      AppSnackBar.show(
        context,
        message: 'Check-in registrado. Continue no seu ritmo.',
        icon: Icons.check_circle_outline_rounded,
      );
      widget.onCompleted?.call();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showDeepReadingUnlockSheet() async {
    if (!mounted) {
      return;
    }
    var completed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
        ),
        child: RewardedAdPrompt(
          title: 'Deseja desbloquear mais uma leitura emocional?',
          message:
              'Seu check-in foi salvo. A leitura básica continua disponível, e você pode liberar uma leitura aprofundada assistindo a um anúncio ou assinando Premium.',
          rewardLabel: 'Recompensa: +1 leitura emocional aprofundada hoje.',
          rewardedAdAvailable: true,
          isRewardLoading: _isRewardLoading,
          onWatchRewardedAd: () async {
            if (_isRewardLoading) {
              return;
            }
            setState(() => _isRewardLoading = true);
            final unlocked = await ref
                .read(monetizationAccessControllerProvider.notifier)
                .unlockWithRewardedAd(resource: 'DEEP_EMOTIONAL_READING');
            if (unlocked) {
              await ref
                  .read(checkInControllerProvider.notifier)
                  .generateDeepReadingForLatest();
            }
            if (!mounted || !sheetContext.mounted) {
              return;
            }
            setState(() => _isRewardLoading = false);
            Navigator.of(sheetContext).pop();
            AppSnackBar.show(
              context,
              message: unlocked
                  ? 'Leitura aprofundada liberada para hoje.'
                  : 'Não foi possível confirmar o anúncio agora. Seu check-in continua salvo.',
              icon: unlocked
                  ? Icons.ondemand_video_rounded
                  : Icons.info_outline_rounded,
            );
            completed = true;
            widget.onCompleted?.call();
          },
          onOpenPremium: () {
            Navigator.of(sheetContext).pop();
            completed = true;
            widget.onCompleted?.call();
          },
          premiumLabel: 'Assinar Premium',
        ),
      ),
    );
    if (mounted && !_isRewardLoading && !completed) {
      widget.onCompleted?.call();
    }
  }

  void _openMoodPicker(List<CheckIn> recentItems, CheckInAiInsight? insight) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _MoodPickerSheet(
        recentItems: recentItems,
        suggestedInsight: insight,
        selectedMood: _selectedMood,
        onSelected: (mood) {
          setState(() => _selectedMood = mood);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkInState = ref.watch(checkInControllerProvider);
    final history = checkInState.asData?.value;
    final recentItems = history?.result.items ?? const <CheckIn>[];
    final latestInsight =
        history?.latestCreatedCheckIn?.aiInsight ??
        recentItems
            .where((item) => item.aiInsight != null)
            .map((item) => item.aiInsight!)
            .firstOrNull;

    return _CheckInBriefingCard(
      selectedMood: _selectedMood,
      energyLevel: _energyLevel,
      reflectionController: _reflectionController,
      quickMoodOptions: _quickMoodOptions,
      isLoading:
          _isSubmitting || (checkInState.isLoading && !checkInState.hasValue),
      onMoodSelected: (mood) => setState(() => _selectedMood = mood),
      onOpenMoodPicker: () => _openMoodPicker(recentItems, latestInsight),
      onEnergyChanged: (value) => setState(() => _energyLevel = value),
      onSubmit: _submit,
      onCancel: widget.onCancel ?? () => Navigator.of(context).maybePop(),
    );
  }

  String _errorMessage(Object? error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final details = data['details'];
        if (details is List && details.isNotEmpty) {
          return details.join(', ');
        }
      }
      return error.message ?? 'Não foi possível salvar o check-in.';
    }

    return 'Não foi possível salvar o check-in.';
  }
}

class _CheckInBriefingCard extends StatelessWidget {
  const _CheckInBriefingCard({
    required this.selectedMood,
    required this.energyLevel,
    required this.reflectionController,
    required this.quickMoodOptions,
    required this.isLoading,
    required this.onMoodSelected,
    required this.onOpenMoodPicker,
    required this.onEnergyChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  final String selectedMood;
  final double energyLevel;
  final TextEditingController reflectionController;
  final List<String> quickMoodOptions;
  final bool isLoading;
  final ValueChanged<String> onMoodSelected;
  final VoidCallback onOpenMoodPicker;
  final ValueChanged<double> onEnergyChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: 'Check-in do dia',
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            eyebrow: 'Como estou?',
            title: 'Comece pelo seu estado agora',
            subtitle:
                'Um check-in curto já dá contexto para o seu briefing do dia.',
            accentColor: AppColors.accent,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...quickMoodOptions.map(
                (mood) => ChoiceChip(
                  label: Text(mood),
                  selected: selectedMood == mood,
                  onSelected: (_) => onMoodSelected(mood),
                ),
              ),
              ActionChip(
                tooltip: 'Ver mais estados',
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Mais estados'),
                onPressed: onOpenMoodPicker,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Estado selecionado: $selectedMood',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          Text(
            'Energia percebida: ${energyLevel.round()}/10',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
          ),
          Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: energyLevel,
            onChanged: onEnergyChanged,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: reflectionController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Se quiser, conte o motivo',
              hintText: 'Uma frase simples ajuda a leitura ficar mais precisa.',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite_rounded),
                label: const Text('Fazer check-in'),
              ),
              OutlinedButton.icon(
                onPressed: isLoading ? null : onCancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Agora não'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodPickerSheet extends StatefulWidget {
  const _MoodPickerSheet({
    required this.recentItems,
    required this.suggestedInsight,
    required this.selectedMood,
    required this.onSelected,
  });

  final List<CheckIn> recentItems;
  final CheckInAiInsight? suggestedInsight;
  final String selectedMood;
  final ValueChanged<String> onSelected;

  @override
  State<_MoodPickerSheet> createState() => _MoodPickerSheetState();
}

class _MoodPickerSheetState extends State<_MoodPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentMoods = widget.recentItems
        .map((item) => _capitalize(item.mood))
        .where((mood) => mood.isNotEmpty)
        .toSet()
        .take(4)
        .toList();
    final suggestedMoods = _suggestedMoods(widget.suggestedInsight);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BottomSheetHandle(),
                Text(
                  'Escolha um estado',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar estado',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                if (recentMoods.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _MoodGroup(
                    title: 'Recentes',
                    moods: _filterMoods(recentMoods),
                    selectedMood: widget.selectedMood,
                    onSelected: widget.onSelected,
                  ),
                ],
                if (suggestedMoods.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _MoodGroup(
                    title: 'Sugeridos pela IA',
                    moods: _filterMoods(suggestedMoods),
                    selectedMood: widget.selectedMood,
                    onSelected: widget.onSelected,
                  ),
                ],
                ..._moodGroups.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: _MoodGroup(
                      title: entry.key,
                      moods: _filterMoods(entry.value),
                      selectedMood: widget.selectedMood,
                      onSelected: widget.onSelected,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _filterMoods(List<String> moods) {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return moods;
    }

    return moods
        .where((mood) => mood.toLowerCase().contains(normalizedQuery))
        .toList();
  }

  List<String> _suggestedMoods(CheckInAiInsight? insight) {
    final source = [
      insight?.insight ?? '',
      insight?.suggestedAction ?? '',
      insight?.suggestedTrailReason ?? '',
    ].join(' ').toLowerCase();

    final matches = <String>[];
    for (final moods in _moodGroups.values) {
      for (final mood in moods) {
        if (source.contains(mood.toLowerCase())) {
          matches.add(mood);
        }
      }
    }

    return matches.toSet().take(4).toList();
  }
}

class _MoodGroup extends StatelessWidget {
  const _MoodGroup({
    required this.title,
    required this.moods,
    required this.selectedMood,
    required this.onSelected,
  });

  final String title;
  final List<String> moods;
  final String selectedMood;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (moods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: moods
              .map(
                (mood) => ChoiceChip(
                  label: Text(mood),
                  selected: selectedMood == mood,
                  onSelected: (_) => onSelected(mood),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _BottomSheetHandle extends StatelessWidget {
  const _BottomSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.outline.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

const _moodGroups = {
  'Emocionais': [
    'Calmo',
    'Ansioso',
    'Triste',
    'Animado',
    'Irritado',
    'Esperancoso',
    'Sobrecarregado',
  ],
  'Mentais': [
    'Distraído',
    'Focado',
    'Confuso',
    'Criativo',
    'Acelerado',
    'Travado',
  ],
  'Fisicos': ['Cansado', 'Energizado', 'Tenso', 'Leve', 'Sonolento', 'Agitado'],
  'Comportamentais': [
    'Evitando',
    'Produtivo',
    'Isolado',
    'Conectado',
    'Procrastinando',
    'Constante',
  ],
};

String _capitalize(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
}
