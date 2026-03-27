import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
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
  final _practiceController = TextEditingController(text: 'respiracao guiada');
  final _searchController = TextEditingController();
  double _energyLevel = 7;
  String _selectedMood = 'Todos';

  @override
  void initState() {
    super.initState();
    ref.listenManual(checkInControllerProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DioException
            ? (error.response?.data is Map<String, dynamic>
                ? ((error.response?.data['details'] as List?)?.join(', ') ??
                    error.message ??
                    'Nao foi possivel salvar o check-in.')
                : error.message ?? 'Nao foi possivel salvar o check-in.')
            : 'Nao foi possivel salvar o check-in.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  @override
  void dispose() {
    _moodController.dispose();
    _reflectionController.dispose();
    _practiceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(checkInControllerProvider.notifier).create(
          mood: _moodController.text.trim(),
          reflection: _reflectionController.text.trim(),
          energyLevel: _energyLevel.round(),
          recommendedPractice: _practiceController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    _moodController.text = 'calmo';
    _reflectionController.clear();
    _practiceController.text = 'respiracao guiada';
    setState(() => _energyLevel = 7);
  }

  Future<void> _applyFilters() {
    return ref.read(checkInControllerProvider.notifier).applyFilters(
          search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
          mood: _selectedMood == 'Todos' ? null : _selectedMood.toLowerCase(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final checkInState = ref.watch(checkInControllerProvider);
    final isSaving = checkInState.isLoading && !checkInState.hasValue;

    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Check-in emocional',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
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
                'Em menos de um minuto, registre como voce esta e deixe o app acompanhar seu ritmo emocional.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _moodController,
                      decoration: const InputDecoration(
                        labelText: 'Como voce esta agora?',
                        prefixIcon: Icon(Icons.mood_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Informe seu estado.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reflectionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'O que mais influenciou seu momento?',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.auto_fix_high_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Escreva uma reflexao curta.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _practiceController,
                      decoration: const InputDecoration(
                        labelText: 'Qual pratica combina com voce agora?',
                        prefixIcon: Icon(Icons.self_improvement_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Informe a pratica sugerida.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Energia percebida: ${_energyLevel.round()}',
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
                      ],
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
        const SizedBox(height: 16),
        checkInState.when(
          data: (result) => _CheckInHistory(
            result: result,
            selectedMood: _selectedMood,
            searchController: _searchController,
            onPageChanged: (page) => ref.read(checkInControllerProvider.notifier).goToPage(page),
            onMoodChanged: (value) {
              setState(() => _selectedMood = value);
              _applyFilters();
            },
            onSearchChanged: (_) => _applyFilters(),
          ),
          error: (error, stackTrace) => const _EmotionalErrorState(),
          loading: () => const _EmotionalLoadingState(),
        ),
      ],
    );
  }
}

class _CheckInHistory extends StatelessWidget {
  const _CheckInHistory({
    required this.result,
    required this.selectedMood,
    required this.searchController,
    required this.onPageChanged,
    required this.onMoodChanged,
    required this.onSearchChanged,
  });

  final PaginatedResponse<CheckIn> result;
  final String selectedMood;
  final TextEditingController searchController;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onMoodChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final moodOptions = <String>{
      'Todos',
      ...result.items.map((item) => _capitalize(item.mood)),
      selectedMood,
    }.toList();

    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historico visual',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.totalItems} registros encontrados no historico.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              _MoodTrendChart(items: result.items),
              const SizedBox(height: 18),
              TextFormField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Buscar por reflexao ou pratica',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: moodOptions
                    .map(
                      (option) => ChoiceChip(
                        label: Text(option),
                        selected: option == selectedMood,
                        onSelected: (_) => onMoodChanged(option),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (result.items.isEmpty)
          GuidedEmptyState(
            icon: Icons.insights_rounded,
            title: 'Nenhum registro combina com esse filtro.',
            subtitle: 'Tente outro humor ou limpe a busca para enxergar melhor seu historico.',
            actionLabel: 'Mostrar tudo',
            onAction: () {
              searchController.clear();
              onMoodChanged('Todos');
            },
          )
        else
          Column(
            children: [
              ...result.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PrimaryPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _capitalize(item.mood),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                            ),
                            Text(
                              'Energia ${item.energyLevel}/10',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.accentWarm,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(item.reflection, style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 12),
                        Text(
                          'Pratica sugerida: ${item.recommendedPractice}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PaginationControls(
                page: result.page,
                totalPages: result.totalPages,
                onPageChanged: onPageChanged,
              ),
            ],
          ),
      ],
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}

class _MoodTrendChart extends StatelessWidget {
  const _MoodTrendChart({required this.items});

  final List<CheckIn> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('Seu historico vai aparecer aqui conforme voce registrar seus dias.');
    }

    final reversed = items.reversed.toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: reversed.map((item) {
        final height = 30 + (item.energyLevel * 10);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: height.toDouble(),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentWarm],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.mood.characters.first.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EmotionalLoadingState extends StatelessWidget {
  const _EmotionalLoadingState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Carregando seu historico emocional...'),
        ],
      ),
    );
  }
}

class _EmotionalErrorState extends StatelessWidget {
  const _EmotionalErrorState();

  @override
  Widget build(BuildContext context) {
    return GuidedEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Nao conseguimos abrir seu historico agora.',
      subtitle: 'Atualize a pagina ou tente novamente em alguns instantes.',
      actionLabel: 'Tentar de novo',
      onAction: () {},
    );
  }
}
