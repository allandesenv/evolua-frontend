import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContentModuleView extends ConsumerStatefulWidget {
  const ContentModuleView({super.key});

  @override
  ConsumerState<ContentModuleView> createState() => _ContentModuleViewState();
}

class _ContentModuleViewState extends ConsumerState<ContentModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController(text: 'ansiedade');
  bool _premium = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(trailControllerProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DioException
            ? (error.response?.data is Map<String, dynamic>
                ? ((error.response?.data['details'] as List?)?.join(', ') ??
                    error.message ??
                    'Nao foi possivel salvar a trilha.')
                : error.message ?? 'Nao foi possivel salvar a trilha.')
            : 'Nao foi possivel salvar a trilha.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(trailControllerProvider.notifier).create(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _categoryController.text.trim(),
          premium: _premium,
        );

    if (!mounted) {
      return;
    }

    _titleController.clear();
    _descriptionController.clear();
    _categoryController.text = 'ansiedade';
    setState(() => _premium = false);
  }

  @override
  Widget build(BuildContext context) {
    final trailsState = ref.watch(trailControllerProvider);
    final isSaving = trailsState.isLoading && !trailsState.hasValue;

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
                      'Trilhas e conteudos',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(trailControllerProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Monte trilhas com titulo, categoria e descricao para alimentar a experiencia guiada do usuario.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titulo da trilha',
                        prefixIcon: Icon(Icons.auto_stories_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Informe o titulo.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descricao',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Informe a descricao.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _categoryController,
                            decoration: const InputDecoration(
                              labelText: 'Categoria',
                              prefixIcon: Icon(Icons.category_rounded),
                            ),
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'Informe a categoria.'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Trilha premium'),
                            value: _premium,
                            onChanged: (value) {
                              setState(() => _premium = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : _submit,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Criar trilha'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        trailsState.when(
          data: (trails) => _TrailList(trails: trails),
          error: (error, stackTrace) => const _ContentErrorState(),
          loading: () => const _ContentLoadingState(),
        ),
      ],
    );
  }
}

class _TrailList extends StatelessWidget {
  const _TrailList({required this.trails});

  final List<Trail> trails;

  @override
  Widget build(BuildContext context) {
    if (trails.isEmpty) {
      return const _ContentEmptyState();
    }

    return Column(
      children: trails
          .map(
            (trail) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PrimaryPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            trail.title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        Text(
                          trail.category,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.accent,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(trail.description, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 14),
                    Text(
                      trail.premium ? 'Disponivel no plano premium' : 'Disponivel no fluxo essencial',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: trail.premium ? AppColors.accentGold : AppColors.textSecondary,
                          ),
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

class _ContentLoadingState extends StatelessWidget {
  const _ContentLoadingState();

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
          Text('Carregando trilhas...'),
        ],
      ),
    );
  }
}

class _ContentEmptyState extends StatelessWidget {
  const _ContentEmptyState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nenhuma trilha cadastrada.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text('Crie a primeira trilha para iniciar a biblioteca guiada.'),
        ],
      ),
    );
  }
}

class _ContentErrorState extends StatelessWidget {
  const _ContentErrorState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Text(
        'Nao foi possivel carregar trilhas.',
        style: TextStyle(color: AppColors.danger),
      ),
    );
  }
}
