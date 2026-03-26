import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
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
  double _energyLevel = 7;

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
                      'Check-ins emocionais',
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
                'Registre humor, reflexao, energia e pratica recomendada para alimentar a jornada emocional.',
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
                        labelText: 'Humor',
                        prefixIcon: Icon(Icons.mood_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Informe o humor.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reflectionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reflexao',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.auto_fix_high_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Informe a reflexao.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _practiceController,
                      decoration: const InputDecoration(
                        labelText: 'Pratica recomendada',
                        prefixIcon: Icon(Icons.self_improvement_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Informe a pratica.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nivel de energia: ${_energyLevel.round()}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textPrimary,
                              ),
                        ),
                        Slider(
                          min: 1,
                          max: 10,
                          divisions: 9,
                          value: _energyLevel,
                          onChanged: (value) {
                            setState(() => _energyLevel = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : _submit,
                        icon: const Icon(Icons.favorite_border_rounded),
                        label: const Text('Salvar check-in'),
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
          data: (items) => _CheckInList(items: items),
          error: (error, stackTrace) => const _EmotionalErrorState(),
          loading: () => const _EmotionalLoadingState(),
        ),
      ],
    );
  }
}

class _CheckInList extends StatelessWidget {
  const _CheckInList({required this.items});

  final List<CheckIn> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmotionalEmptyState();
    }

    return Column(
      children: items
          .map(
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
                            item.mood,
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
          )
          .toList(),
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
          Text('Carregando check-ins...'),
        ],
      ),
    );
  }
}

class _EmotionalEmptyState extends StatelessWidget {
  const _EmotionalEmptyState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nenhum check-in registrado.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text('Use o formulario acima para registrar o primeiro estado emocional.'),
        ],
      ),
    );
  }
}

class _EmotionalErrorState extends StatelessWidget {
  const _EmotionalErrorState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Text(
        'Nao foi possivel carregar check-ins.',
        style: TextStyle(color: AppColors.danger),
      ),
    );
  }
}
