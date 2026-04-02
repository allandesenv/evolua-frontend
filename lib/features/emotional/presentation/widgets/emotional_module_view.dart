import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/presentation/widgets/check_in_ai_insight_card.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EmotionalModuleView extends ConsumerStatefulWidget {
  const EmotionalModuleView({super.key});

  @override
  ConsumerState<EmotionalModuleView> createState() => _EmotionalModuleViewState();
}

class _EmotionalModuleViewState extends ConsumerState<EmotionalModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _moodController = TextEditingController(text: 'calmo');
  final _reflectionController = TextEditingController();
  final _searchController = TextEditingController();
  double _energyLevel = 7;
  String _selectedMood = 'Todos';
  String _selectedEnergyRange = 'Todas';
  String _selectedRangePreset = '30 dias';

  @override
  void initState() {
    super.initState();
    ref.listenManual(checkInControllerProvider, (previous, next) {
      if (!next.hasError) return;
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
    _moodController.dispose();
    _reflectionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(checkInControllerProvider.notifier).create(
          mood: _moodController.text.trim(),
          reflection:
              _reflectionController.text.trim().isEmpty ? null : _reflectionController.text.trim(),
          energyLevel: _energyLevel.round(),
        );
    if (!mounted) return;
    _moodController.text = 'calmo';
    _reflectionController.clear();
    setState(() => _energyLevel = 7);
  }

  Future<void> _applyFilters() {
    final range = _resolvePresetRange(_selectedRangePreset);
    return ref.read(checkInControllerProvider.notifier).applyFilters(
          search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
          mood: _selectedMood == 'Todos' ? null : _selectedMood.toLowerCase(),
          energyRange: switch (_selectedEnergyRange) {
            'Baixa (1-3)' => 'low',
            'Moderada (4-7)' => 'medium',
            'Alta (8-10)' => 'high',
            _ => null,
          },
          from: range?.$1,
          to: range?.$2,
        );
  }

  Future<void> _clearFilters() async {
    _searchController.clear();
    setState(() {
      _selectedMood = 'Todos';
      _selectedEnergyRange = 'Todas';
      _selectedRangePreset = '30 dias';
    });
    await ref.read(checkInControllerProvider.notifier).clearFilters();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today),
      saveText: 'Aplicar',
      helpText: 'Selecionar intervalo',
    );
    if (picked == null) return;
    setState(() => _selectedRangePreset = 'Personalizado');
    await ref.read(checkInControllerProvider.notifier).applyFilters(
          search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
          mood: _selectedMood == 'Todos' ? null : _selectedMood.toLowerCase(),
          energyRange: switch (_selectedEnergyRange) {
            'Baixa (1-3)' => 'low',
            'Moderada (4-7)' => 'medium',
            'Alta (8-10)' => 'high',
            _ => null,
          },
          from: picked.start,
          to: picked.end,
        );
  }

  @override
  Widget build(BuildContext context) {
    final checkInState = ref.watch(checkInControllerProvider);
    final isSaving = checkInState.isLoading && !checkInState.hasValue;
    final latestInsight = checkInState.asData?.value.latestCreatedCheckIn?.aiInsight;
    final compact = ResponsiveBreakpoints.isCompact(context);

    return Column(
      children: [
        PrimaryPanel(
          semanticLabel: 'Formulario de check-in emocional',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : 420,
                    child: Text('Check-in emocional', style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(checkInControllerProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Em menos de um minuto, registre como voce esta. Se quiser, conte o que influenciou esse momento para a IA responder com mais contexto.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _moodController,
                      decoration: const InputDecoration(labelText: 'Como voce esta agora?', prefixIcon: Icon(Icons.mood_rounded)),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Informe seu estado.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reflectionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Se quiser, conte o motivo do seu estado atual',
                        hintText: 'Ex.: dormi pouco, tive uma conversa dificil, consegui terminar algo importante...',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.auto_fix_high_rounded),
                      ),
                      validator: (_) => null,
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Energia percebida',
                      value: '${_energyLevel.round()} de 10',
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Energia percebida: ${_energyLevel.round()}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
                        Slider(min: 1, max: 10, divisions: 9, value: _energyLevel, onChanged: (value) => setState(() => _energyLevel = value)),
                      ],
                    ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : _submit,
                        icon: const Icon(Icons.favorite_border_rounded),
                        label: const Text('Registrar agora'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (latestInsight != null) ...[
          const SizedBox(height: 16),
          CheckInAiInsightCard(insight: latestInsight),
        ],
        const SizedBox(height: 16),
        checkInState.when(
          data: (historyState) => _HistoryPanel(
            state: historyState,
            searchController: _searchController,
            selectedMood: _selectedMood,
            selectedEnergyRange: _selectedEnergyRange,
            selectedRangePreset: _selectedRangePreset,
            onPageChanged: (page) => ref.read(checkInControllerProvider.notifier).goToPage(page),
            onSearch: _applyFilters,
            onClearFilters: _clearFilters,
            onRefresh: () => ref.read(checkInControllerProvider.notifier).refresh(),
            onMoodChanged: (value) async {
              setState(() => _selectedMood = value);
              await _applyFilters();
            },
            onEnergyRangeChanged: (value) async {
              setState(() => _selectedEnergyRange = value);
              await _applyFilters();
            },
            onRangePresetChanged: (value) async {
              if (value == 'Personalizado') return _pickCustomRange();
              setState(() => _selectedRangePreset = value);
              await _applyFilters();
            },
          ),
          error: (error, stackTrace) => _ErrorState(
            onRetry: () => ref.read(checkInControllerProvider.notifier).refresh(),
          ),
          loading: () => const _LoadingState(),
        ),
      ],
    );
  }

  (DateTime, DateTime)? _resolvePresetRange(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (preset) {
      '7 dias' => (today.subtract(const Duration(days: 6)), today),
      '30 dias' => (today.subtract(const Duration(days: 29)), today),
      '90 dias' => (today.subtract(const Duration(days: 89)), today),
      'Personalizado' => null,
      _ => (today.subtract(const Duration(days: 29)), today),
    };
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.state,
    required this.searchController,
    required this.selectedMood,
    required this.selectedEnergyRange,
    required this.selectedRangePreset,
    required this.onPageChanged,
    required this.onSearch,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onMoodChanged,
    required this.onEnergyRangeChanged,
    required this.onRangePresetChanged,
  });

  final CheckInHistoryState state;
  final TextEditingController searchController;
  final String selectedMood;
  final String selectedEnergyRange;
  final String selectedRangePreset;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onSearch;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final ValueChanged<String> onMoodChanged;
  final ValueChanged<String> onEnergyRangeChanged;
  final ValueChanged<String> onRangePresetChanged;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    final items = result.items;
    final compact = ResponsiveBreakpoints.isCompact(context);
    final grouped = <String, List<CheckIn>>{};
    for (final item in items) {
      grouped.putIfAbsent(_monthLabel(item.createdAt), () => <CheckIn>[]).add(item);
    }
    final hasActiveFilters = searchController.text.trim().isNotEmpty || selectedMood != 'Todos' || selectedEnergyRange != 'Todas' || selectedRangePreset != '30 dias';
    final totalEnergy = items.fold<int>(0, (sum, item) => sum + item.energyLevel);
    final averageEnergy = items.isEmpty ? 0.0 : totalEnergy / items.length;
    final dominantMood = items.isEmpty ? 'sem dados' : _dominantMood(items);

    return Column(
      children: [
        PrimaryPanel(
          semanticLabel: 'Historico emocional',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : 520,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sua evolucao emocional', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        Text(_narrative(items, averageEnergy, dominantMood), style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  TextButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Atualizar')),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : 260,
                    child: _MetricCard(title: 'Energia media', value: '${averageEnergy.toStringAsFixed(1)}/10', subtitle: 'Registros visiveis'),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : 260,
                    child: _MetricCard(title: 'Humor dominante', value: _capitalize(dominantMood), subtitle: 'Predominio recente'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceStrong.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tendencia recente', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: items.reversed.map((item) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            height: 20 + (item.energyLevel * 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentWarm], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: searchController,
                onFieldSubmitted: (_) => onSearch(),
                decoration: InputDecoration(
                  labelText: 'Buscar por reflexao ou pratica',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(onPressed: onSearch, icon: const Icon(Icons.arrow_forward_rounded)),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: _moodOptions(items, selectedMood).map((option) => ChoiceChip(label: Text(option), selected: option == selectedMood, onSelected: (_) => onMoodChanged(option))).toList()),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: const ['Todas', 'Baixa (1-3)', 'Moderada (4-7)', 'Alta (8-10)'].map((option) => ChoiceChip(label: Text(option), selected: option == selectedEnergyRange, onSelected: (_) => onEnergyRangeChanged(option))).toList()),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: const ['7 dias', '30 dias', '90 dias', 'Personalizado'].map((option) => ChoiceChip(label: Text(option), selected: option == selectedRangePreset, onSelected: (_) => onRangePresetChanged(option))).toList()),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Text('${result.totalItems} registros encontrados nesta leitura.', style: Theme.of(context).textTheme.bodySmall),
                  if (hasActiveFilters) TextButton(onPressed: onClearFilters, child: const Text('Limpar filtros')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          GuidedEmptyState(
            icon: hasActiveFilters ? Icons.filter_alt_off_rounded : Icons.insights_rounded,
            title: hasActiveFilters ? 'Nenhum registro combina com este recorte.' : 'Seu historico emocional vai ganhar forma aqui.',
            subtitle: hasActiveFilters ? 'Tente ampliar o periodo ou remover alguns filtros para enxergar sua evolucao.' : 'Comece com um check-in curto e o app transforma seus dias em uma linha do tempo acompanhavel.',
            actionLabel: hasActiveFilters ? 'Limpar filtros' : 'Atualizar',
            onAction: hasActiveFilters ? onClearFilters : onRefresh,
          )
        else
          Column(
            children: [
              ...grouped.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PrimaryPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(entry.key, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary))),
                          Text('${entry.value.length} registros', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...entry.value.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TimelineEntry(item: item),
                      )),
                    ],
                  ),
                ),
              )),
              PaginationControls(page: result.page, totalPages: result.totalPages, onPageChanged: onPageChanged),
            ],
          ),
      ],
    );
  }

  List<String> _moodOptions(List<CheckIn> items, String selectedMood) => <String>{'Todos', ...items.map((item) => _capitalize(item.mood)), selectedMood}.toList();
  String _monthLabel(DateTime date) => '${const ['Janeiro', 'Fevereiro', 'Marco', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'][date.month - 1]} ${date.year}';
  String _dominantMood(List<CheckIn> items) {
    final counts = <String, int>{};
    for (final item in items) {
      counts.update(item.mood, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts.entries.reduce((best, current) => current.value > best.value ? current : best).key;
  }

  String _narrative(List<CheckIn> items, double averageEnergy, String dominantMood) {
    if (items.isEmpty) return 'Registre seus dias para enxergar como humor, energia e rotina evoluem com o tempo.';
    if (items.length < 2) return 'Humor predominante: ${_capitalize(dominantMood)}. Energia media ${averageEnergy.toStringAsFixed(1)}/10.';
    final midpoint = (items.length / 2).ceil();
    final recent = items.take(midpoint).fold<int>(0, (sum, item) => sum + item.energyLevel) / midpoint;
    final olderItems = items.skip(midpoint).toList();
    final older = olderItems.isEmpty ? recent : olderItems.fold<int>(0, (sum, item) => sum + item.energyLevel) / olderItems.length;
    final stability = recent - older >= 1 ? 'Sua energia esteve mais alta nas ultimas semanas.' : recent - older <= -1 ? 'Sua energia caiu um pouco no periodo recente e vale observar o contexto.' : 'Sua energia esteve mais estavel nas ultimas semanas.';
    return 'Humor predominante: ${_capitalize(dominantMood)}. Energia media ${averageEnergy.toStringAsFixed(1)}/10. $stability';
  }

  String _capitalize(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1).toLowerCase();
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.subtitle});
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.item});
  final CheckIn item;

  @override
  Widget build(BuildContext context) {
    final month = item.createdAt.month.toString().padLeft(2, '0');
    final day = item.createdAt.day.toString().padLeft(2, '0');
    final hour = item.createdAt.hour.toString().padLeft(2, '0');
    final minute = item.createdAt.minute.toString().padLeft(2, '0');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(width: 14, height: 14, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
            Container(width: 2, height: 116, margin: const EdgeInsets.symmetric(vertical: 6), color: AppColors.outline),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceStrong.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.mood[0].toUpperCase() + item.mood.substring(1).toLowerCase(), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary))),
                    Text('$day/$month/${item.createdAt.year} $hour:$minute', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(icon: Icons.bolt_rounded, label: 'Energia ${item.energyLevel}/10'),
                    _InfoChip(icon: Icons.self_improvement_rounded, label: item.recommendedPractice),
                  ],
                ),
                if (item.reflection.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(item.reflection, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const TimelineSkeleton(groups: 2);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GuidedEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Nao conseguimos abrir sua linha do tempo agora.',
      subtitle: 'Atualize a pagina ou tente novamente em alguns instantes para retomar sua leitura.',
      actionLabel: 'Tentar de novo',
      onAction: onRetry,
    );
  }
}
