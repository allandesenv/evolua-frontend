import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_video.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminTrailManagementView extends ConsumerStatefulWidget {
  const AdminTrailManagementView({super.key});

  @override
  ConsumerState<AdminTrailManagementView> createState() =>
      _AdminTrailManagementViewState();
}

class _AdminTrailManagementViewState
    extends ConsumerState<AdminTrailManagementView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _categoryController = TextEditingController(text: 'ansiedade');
  final _searchController = TextEditingController();
  final _draftThemeController = TextEditingController();
  final _draftGoalController = TextEditingController();
  final _draftLevelController = TextEditingController(text: 'leve');
  final _draftStepCountController = TextEditingController(text: '5');
  final List<_EditableMediaLink> _mediaLinks = [_EditableMediaLink.live()];
  final List<_EditableTrailStep> _steps = [_EditableTrailStep.live(0)];
  bool _premium = false;
  bool _draftLoading = false;
  bool? _premiumFilter;
  Trail? _editingTrail;

  @override
  void initState() {
    super.initState();
    ref.listenManual(trailControllerProvider, (previous, next) {
      if (!next.hasError) {
        return;
      }

      final error = next.error;
      final message = error is DioException
          ? (error.response?.data is Map<String, dynamic>
                ? ((error.response?.data['details'] as List?)?.join(', ') ??
                      error.response?.data['message']?.toString() ??
                      error.message ??
                      'Nao foi possivel salvar a trilha.')
                : error.message ?? 'Nao foi possivel salvar a trilha.')
          : 'Nao foi possivel salvar a trilha.';

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _categoryController.dispose();
    _searchController.dispose();
    _draftThemeController.dispose();
    _draftGoalController.dispose();
    _draftLevelController.dispose();
    _draftStepCountController.dispose();
    for (final link in _mediaLinks) {
      link.dispose();
    }
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(trailControllerProvider.notifier);
    final editingTrail = _editingTrail;
    final composedContent = _composeLegacyContent();
    if (editingTrail == null) {
      await controller.create(
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        content: composedContent,
        category: _categoryController.text.trim(),
        premium: _premium,
        mediaLinks: _buildMediaLinks(),
        steps: _buildSteps(),
      );
    } else {
      await controller.updateTrail(
        id: editingTrail.id,
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        content: composedContent,
        category: _categoryController.text.trim(),
        premium: _premium,
        mediaLinks: _buildMediaLinks(),
        steps: _buildSteps(),
      );
    }

    if (!mounted || ref.read(trailControllerProvider).hasError) {
      return;
    }

    _resetEditor();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          editingTrail == null ? 'Trilha criada.' : 'Trilha atualizada.',
        ),
      ),
    );
  }

  void _resetEditor() {
    _titleController.clear();
    _summaryController.clear();
    _categoryController.text = 'ansiedade';
    setState(() {
      _premium = false;
      _editingTrail = null;
      for (final link in _mediaLinks) {
        link.dispose();
      }
      for (final step in _steps) {
        step.dispose();
      }
      _mediaLinks
        ..clear()
        ..add(_EditableMediaLink.live());
      _steps
        ..clear()
        ..add(_EditableTrailStep.live(0));
    });
  }

  void _startEditingTrail(Trail trail) {
    _titleController.text = trail.title;
    _summaryController.text = trail.summary;
    _categoryController.text = trail.category;
    setState(() {
      _premium = trail.premium;
      _editingTrail = trail;
      for (final link in _mediaLinks) {
        link.dispose();
      }
      _mediaLinks
        ..clear()
        ..addAll(
          trail.mediaLinks.isEmpty
              ? [_EditableMediaLink.live()]
              : trail.mediaLinks.map(_EditableMediaLink.fromLink),
        );
      for (final step in _steps) {
        step.dispose();
      }
      _steps
        ..clear()
        ..addAll(
          trail.steps.isEmpty
              ? [_EditableTrailStep.fromLegacyTrail(trail)]
              : trail.steps.map(_EditableTrailStep.fromStep),
        );
    });
  }

  Future<void> _confirmDeleteTrail(Trail trail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir trilha?'),
        content: Text(
          'A trilha "${trail.title}" sera removida, junto com o progresso associado a ela.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(trailControllerProvider.notifier).delete(trail.id);
    if (!mounted || ref.read(trailControllerProvider).hasError) {
      return;
    }

    if (_editingTrail?.id == trail.id) {
      _resetEditor();
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trilha excluida.')));
  }

  Future<void> _applyFilters() {
    return ref
        .read(trailControllerProvider.notifier)
        .applyFilters(
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          premium: _premiumFilter,
        );
  }

  List<TrailMediaLink> _buildMediaLinks() {
    return _mediaLinks
        .where((item) => item.urlController.text.trim().isNotEmpty)
        .map(
          (item) => TrailMediaLink(
            label: item.labelController.text.trim().isEmpty
                ? 'Conteudo complementar'
                : item.labelController.text.trim(),
            url: item.urlController.text.trim(),
            type: item.type == 'auto'
                ? _detectType(item.urlController.text.trim())
                : item.type,
          ),
        )
        .toList();
  }

  List<TrailStep> _buildSteps() {
    return _steps.asMap().entries.map((entry) {
      final step = entry.value;
      return TrailStep(
        position: entry.key,
        title: step.titleController.text.trim(),
        type: step.type,
        summary: step.summaryController.text.trim(),
        durationMinutes: int.tryParse(step.durationController.text.trim()) ?? 5,
        content: step.contentController.text.trim(),
        video: step.type == 'VIDEO'
            ? TrailStepVideo(
                provider: 'YOUTUBE',
                videoId: _extractYoutubeId(step.videoUrlController.text.trim()) ??
                    step.videoIdController.text.trim(),
                url: step.videoUrlController.text.trim().isEmpty
                    ? null
                    : step.videoUrlController.text.trim(),
                thumbnailUrl: step.thumbnailController.text.trim().isEmpty
                    ? null
                    : step.thumbnailController.text.trim(),
                durationSeconds:
                    int.tryParse(step.videoDurationController.text.trim()),
              )
            : null,
        mediaLinks: step.mediaLinks
            .where((item) => item.urlController.text.trim().isNotEmpty)
            .map(
              (item) => TrailMediaLink(
                label: item.labelController.text.trim().isEmpty
                    ? 'Conteudo complementar'
                    : item.labelController.text.trim(),
                url: item.urlController.text.trim(),
                type: item.type == 'auto'
                    ? _detectType(item.urlController.text.trim())
                    : item.type,
              ),
            )
            .toList(),
      );
    }).toList();
  }

  String _composeLegacyContent() {
    final buffer = StringBuffer('# ${_titleController.text.trim()}\n\n');
    buffer.writeln(_summaryController.text.trim());
    for (final step in _steps) {
      buffer
        ..writeln('\n## ${step.titleController.text.trim()}')
        ..writeln()
        ..writeln(step.contentController.text.trim());
    }
    return buffer.toString().trim();
  }

  String _detectType(String url) {
    final normalized = url.toLowerCase();
    if (normalized.contains('youtube.com') || normalized.contains('youtu.be')) {
      return 'youtube';
    }
    if (normalized.endsWith('.mp4') || normalized.contains('vimeo.com')) {
      return 'video';
    }
    if (normalized.endsWith('.mp3') || normalized.contains('spotify.com')) {
      return 'audio';
    }
    return 'external';
  }

  Future<void> _generateDraft() async {
    if (_draftLoading) {
      return;
    }
    final theme = _draftThemeController.text.trim();
    final goal = _draftGoalController.text.trim();
    if (theme.isEmpty || goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe tema e objetivo emocional.')),
      );
      return;
    }
    setState(() => _draftLoading = true);
    try {
      final dio = ref.read(authenticatedDioProvider(AppConfig.aiBaseUrl));
      final response = await dio.post<dynamic>(
        '/v1/ai/admin/trail-drafts',
        data: {
          'theme': theme,
          'category': _categoryController.text.trim().isEmpty
              ? 'emocional'
              : _categoryController.text.trim(),
          'emotionalGoal': goal,
          'level': _draftLevelController.text.trim(),
          'stepCount': int.tryParse(_draftStepCountController.text.trim()) ?? 5,
        },
      );
      final data = ApiPayloadParser.dataMap(response.data);
      final draftSteps = (data['steps'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => _EditableTrailStep.fromDraft(Map<String, dynamic>.from(item)))
          .toList();
      if (draftSteps.isEmpty) {
        throw const FormatException('Rascunho sem etapas.');
      }
      setState(() {
        _titleController.text = data['title']?.toString() ?? theme;
        _summaryController.text = data['summary']?.toString() ?? goal;
        _categoryController.text = data['category']?.toString() ?? 'emocional';
        for (final step in _steps) {
          step.dispose();
        }
        _steps
          ..clear()
          ..addAll(draftSteps);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rascunho gerado. Revise antes de publicar.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel gerar o rascunho agora.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _draftLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trailsState = ref.watch(trailControllerProvider);
    final isSaving = trailsState.isLoading && !trailsState.hasValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin de trilhas',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: context.evoluaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Crie, edite e remova trilhas do catalogo. Videos e links ficam salvos junto da trilha.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryPanel(
          child: _AiDraftPanel(
            themeController: _draftThemeController,
            goalController: _draftGoalController,
            levelController: _draftLevelController,
            stepCountController: _draftStepCountController,
            isLoading: _draftLoading,
            onGenerate: _draftLoading ? null : _generateDraft,
          ),
        ),
        const SizedBox(height: 16),
        PrimaryPanel(
          child: _AdminTrailEditor(
            formKey: _formKey,
            titleController: _titleController,
            summaryController: _summaryController,
            categoryController: _categoryController,
            premium: _premium,
            onPremiumChanged: isSaving
                ? null
                : (value) => setState(() => _premium = value),
            mediaLinks: _mediaLinks,
            steps: _steps,
            editingTrail: _editingTrail,
            onAddLink: isSaving
                ? null
                : () => setState(
                    () => _mediaLinks.add(_EditableMediaLink.live()),
                  ),
            onRemoveLink: isSaving
                ? null
                : (index) => setState(() {
                    _mediaLinks[index].dispose();
                    _mediaLinks.removeAt(index);
                    if (_mediaLinks.isEmpty) {
                      _mediaLinks.add(_EditableMediaLink.live());
                    }
                  }),
            onAddStep: isSaving
                ? null
                : () => setState(
                    () => _steps.add(_EditableTrailStep.live(_steps.length)),
                  ),
            onRemoveStep: isSaving
                ? null
                : (index) => setState(() {
                    _steps[index].dispose();
                    _steps.removeAt(index);
                    if (_steps.isEmpty) {
                      _steps.add(_EditableTrailStep.live(0));
                    }
                  }),
            onMoveStep: isSaving
                ? null
                : (from, to) => setState(() {
                    if (to < 0 || to >= _steps.length) {
                      return;
                    }
                    final item = _steps.removeAt(from);
                    _steps.insert(to, item);
                  }),
            onCancelEditing: _editingTrail == null || isSaving
                ? null
                : _resetEditor,
            onSubmit: isSaving ? null : _submit,
          ),
        ),
        const SizedBox(height: 16),
        trailsState.when(
          data: (result) => _AdminTrailList(
            result: result,
            searchController: _searchController,
            premiumFilter: _premiumFilter,
            onSearchChanged: (_) => _applyFilters(),
            onPremiumFilterChanged: (value) {
              setState(() => _premiumFilter = value);
              _applyFilters();
            },
            onEditTrail: _startEditingTrail,
            onDeleteTrail: isSaving ? null : _confirmDeleteTrail,
            onPageChanged: (page) =>
                ref.read(trailControllerProvider.notifier).goToPage(page),
          ),
          error: (_, _) => GuidedEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Nao conseguimos carregar as trilhas.',
            subtitle: 'Atualize ou tente novamente em instantes.',
            actionLabel: 'Tentar novamente',
            onAction: () =>
                ref.read(trailControllerProvider.notifier).refresh(),
          ),
          loading: () => const FeedSkeleton(cards: 3),
        ),
      ],
    );
  }
}

class _AdminTrailEditor extends StatelessWidget {
  const _AdminTrailEditor({
    required this.formKey,
    required this.titleController,
    required this.summaryController,
    required this.categoryController,
    required this.premium,
    required this.onPremiumChanged,
    required this.mediaLinks,
    required this.steps,
    required this.editingTrail,
    required this.onAddLink,
    required this.onRemoveLink,
    required this.onAddStep,
    required this.onRemoveStep,
    required this.onMoveStep,
    required this.onCancelEditing,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController categoryController;
  final bool premium;
  final ValueChanged<bool>? onPremiumChanged;
  final List<_EditableMediaLink> mediaLinks;
  final List<_EditableTrailStep> steps;
  final Trail? editingTrail;
  final VoidCallback? onAddLink;
  final ValueChanged<int>? onRemoveLink;
  final VoidCallback? onAddStep;
  final ValueChanged<int>? onRemoveStep;
  final void Function(int from, int to)? onMoveStep;
  final VoidCallback? onCancelEditing;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final isEditing = editingTrail != null;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing ? 'Editar trilha' : 'Criar nova trilha',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          if (isEditing) ...[
            const SizedBox(height: 6),
            Text(
              'Editando: ${editingTrail!.title}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          TextFormField(
            controller: titleController,
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
            controller: summaryController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Resumo curto',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.short_text_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Informe um resumo.';
              if (text.length < 12) return 'Use pelo menos 12 caracteres.';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 360,
                child: TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe a categoria.'
                      : null,
                ),
              ),
              SizedBox(
                width: 260,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Trilha premium'),
                  value: premium,
                  onChanged: onPremiumChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Etapas da jornada',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TrailStepEditor(
                index: entry.key,
                item: entry.value,
                onRemove: steps.length == 1 || onRemoveStep == null
                    ? null
                    : () => onRemoveStep!(entry.key),
                onMoveUp: onMoveStep == null || entry.key == 0
                    ? null
                    : () => onMoveStep!(entry.key, entry.key - 1),
                onMoveDown: onMoveStep == null || entry.key == steps.length - 1
                    ? null
                    : () => onMoveStep!(entry.key, entry.key + 1),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAddStep,
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Adicionar etapa'),
          ),
          const SizedBox(height: 20),
          Text(
            'Links gerais da trilha',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...mediaLinks.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MediaLinkEditor(
                item: entry.value,
                onRemove: mediaLinks.length == 1 || onRemoveLink == null
                    ? null
                    : () => onRemoveLink!(entry.key),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAddLink,
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('Adicionar link'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: onSubmit,
                icon: Icon(
                  isEditing
                      ? Icons.save_outlined
                      : Icons.add_circle_outline_rounded,
                ),
                label: Text(isEditing ? 'Salvar alteracoes' : 'Criar trilha'),
              ),
              if (onCancelEditing != null)
                OutlinedButton.icon(
                  onPressed: onCancelEditing,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancelar edicao'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiDraftPanel extends StatelessWidget {
  const _AiDraftPanel({
    required this.themeController,
    required this.goalController,
    required this.levelController,
    required this.stepCountController,
    required this.isLoading,
    required this.onGenerate,
  });

  final TextEditingController themeController;
  final TextEditingController goalController;
  final TextEditingController levelController;
  final TextEditingController stepCountController;
  final bool isLoading;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IA assistida',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.evoluaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Gere um rascunho estruturado por etapas e revise tudo antes de publicar.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 280,
              child: TextFormField(
                controller: themeController,
                decoration: const InputDecoration(
                  labelText: 'Tema',
                  prefixIcon: Icon(Icons.lightbulb_outline_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 320,
              child: TextFormField(
                controller: goalController,
                decoration: const InputDecoration(
                  labelText: 'Objetivo emocional',
                  prefixIcon: Icon(Icons.favorite_border_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextFormField(
                controller: levelController,
                decoration: const InputDecoration(
                  labelText: 'Nivel',
                  prefixIcon: Icon(Icons.tune_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextFormField(
                controller: stepCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Etapas',
                  prefixIcon: Icon(Icons.format_list_numbered_rounded),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onGenerate,
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(isLoading ? 'Gerando rascunho' : 'Gerar rascunho'),
        ),
      ],
    );
  }
}

class _MediaLinkEditor extends StatelessWidget {
  const _MediaLinkEditor({required this.item, required this.onRemove});

  final _EditableMediaLink item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextFormField(
                  controller: item.labelController,
                  decoration: const InputDecoration(
                    labelText: 'Rotulo do link',
                    prefixIcon: Icon(Icons.label_rounded),
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: item.type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto')),
                    DropdownMenuItem(value: 'youtube', child: Text('YouTube')),
                    DropdownMenuItem(value: 'video', child: Text('Video')),
                    DropdownMenuItem(value: 'article', child: Text('Artigo')),
                    DropdownMenuItem(value: 'audio', child: Text('Audio')),
                    DropdownMenuItem(value: 'external', child: Text('Externo')),
                  ],
                  onChanged: (value) => item.type = value ?? 'auto',
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remover link',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: item.urlController,
            decoration: const InputDecoration(
              labelText: 'URL do conteudo',
              hintText: 'https://youtube.com/... ou outro link seguro',
              prefixIcon: Icon(Icons.link_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              if (!text.startsWith('http://') && !text.startsWith('https://')) {
                return 'Use uma URL com http ou https.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _TrailStepEditor extends StatelessWidget {
  const _TrailStepEditor({
    required this.index,
    required this.item,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final _EditableTrailStep item;
  final VoidCallback? onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Etapa ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.evoluaColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mover para cima',
                onPressed: onMoveUp,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: 'Mover para baixo',
                onPressed: onMoveDown,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: 'Remover etapa',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 360,
                child: TextFormField(
                  controller: item.titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titulo da etapa',
                    prefixIcon: Icon(Icons.flag_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe o titulo da etapa.'
                      : null,
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: item.type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'REFLECTION',
                      child: Text('Reflexao'),
                    ),
                    DropdownMenuItem(
                      value: 'EXERCISE',
                      child: Text('Exercicio'),
                    ),
                    DropdownMenuItem(value: 'READING', child: Text('Leitura')),
                    DropdownMenuItem(value: 'VIDEO', child: Text('Video')),
                    DropdownMenuItem(value: 'AUDIO', child: Text('Audio')),
                    DropdownMenuItem(value: 'RITUAL', child: Text('Ritual')),
                    DropdownMenuItem(value: 'AI', child: Text('IA guiada')),
                    DropdownMenuItem(
                      value: 'CHECKPOINT',
                      child: Text('Checkpoint'),
                    ),
                  ],
                  onChanged: (value) {
                    item.type = value ?? 'REFLECTION';
                    (context as Element).markNeedsBuild();
                  },
                ),
              ),
              SizedBox(
                width: 160,
                child: TextFormField(
                  controller: item.durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duracao',
                    suffixText: 'min',
                  ),
                  validator: (value) {
                    final minutes = int.tryParse(value?.trim() ?? '');
                    if (minutes == null || minutes < 1) {
                      return 'Informe minutos.';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: item.summaryController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Resumo da etapa',
              alignLabelWithHint: true,
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Informe o resumo da etapa.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: item.contentController,
            minLines: 4,
            maxLines: 9,
            decoration: const InputDecoration(
              labelText: 'Conteudo da etapa',
              alignLabelWithHint: true,
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Informe o conteudo da etapa.'
                : null,
          ),
          if (item.type == 'VIDEO') ...[
            const SizedBox(height: 12),
            _VideoStepFields(item: item),
          ],
          const SizedBox(height: 12),
          Text(
            'Midia da etapa',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (context, setMediaState) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...item.mediaLinks.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MediaLinkEditor(
                      item: entry.value,
                      onRemove: item.mediaLinks.length == 1
                          ? null
                          : () => setMediaState(() {
                              entry.value.dispose();
                              item.mediaLinks.removeAt(entry.key);
                              if (item.mediaLinks.isEmpty) {
                                item.mediaLinks.add(_EditableMediaLink.live());
                              }
                            }),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setMediaState(
                    () => item.mediaLinks.add(_EditableMediaLink.live()),
                  ),
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Adicionar midia na etapa'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoStepFields extends StatelessWidget {
  const _VideoStepFields({required this.item});

  final _EditableTrailStep item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Video da etapa',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 420,
                child: TextFormField(
                  controller: item.videoUrlController,
                  decoration: const InputDecoration(
                    labelText: 'URL do YouTube',
                    hintText: 'https://youtu.be/... ou youtube.com/watch?v=...',
                    prefixIcon: Icon(Icons.ondemand_video_rounded),
                  ),
                  onChanged: (value) {
                    final videoId = _extractYoutubeId(value);
                    if (videoId != null) {
                      item.videoIdController.text = videoId;
                      item.thumbnailController.text =
                          'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
                    }
                  },
                  validator: (value) {
                    if (item.type != 'VIDEO') return null;
                    final url = value?.trim() ?? '';
                    final id = item.videoIdController.text.trim();
                    if (url.isEmpty && id.isEmpty) {
                      return 'Informe a URL ou o ID do video.';
                    }
                    if (url.isNotEmpty && _extractYoutubeId(url) == null) {
                      return 'Use uma URL do YouTube.';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(
                  controller: item.videoIdController,
                  decoration: const InputDecoration(
                    labelText: 'Video ID',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextFormField(
                  controller: item.videoDurationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duracao',
                    suffixText: 'seg',
                  ),
                  validator: (value) {
                    if (item.type != 'VIDEO') return null;
                    final seconds = int.tryParse(value?.trim() ?? '');
                    if (seconds == null) return 'Informe segundos.';
                    if (seconds < 120 || seconds > 480) {
                      return 'Use 120 a 480 seg.';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: item.thumbnailController,
            decoration: const InputDecoration(
              labelText: 'Thumbnail',
              hintText: 'https://img.youtube.com/vi/.../hqdefault.jpg',
              prefixIcon: Icon(Icons.image_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTrailList extends StatelessWidget {
  const _AdminTrailList({
    required this.result,
    required this.searchController,
    required this.premiumFilter,
    required this.onSearchChanged,
    required this.onPremiumFilterChanged,
    required this.onEditTrail,
    required this.onDeleteTrail,
    required this.onPageChanged,
  });

  final PaginatedResponse<Trail> result;
  final TextEditingController searchController;
  final bool? premiumFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool?> onPremiumFilterChanged;
  final ValueChanged<Trail> onEditTrail;
  final ValueChanged<Trail>? onDeleteTrail;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trilhas publicadas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.evoluaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.totalItems} trilhas no catalogo.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Buscar por titulo, tema ou resumo',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: premiumFilter == null,
                    onSelected: (_) => onPremiumFilterChanged(null),
                  ),
                  ChoiceChip(
                    label: const Text('Essenciais'),
                    selected: premiumFilter == false,
                    onSelected: (_) => onPremiumFilterChanged(false),
                  ),
                  ChoiceChip(
                    label: const Text('Premium'),
                    selected: premiumFilter == true,
                    onSelected: (_) => onPremiumFilterChanged(true),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (result.items.isEmpty)
          GuidedEmptyState(
            icon: Icons.auto_stories_rounded,
            title: 'Nenhuma trilha encontrada.',
            subtitle: 'Ajuste a busca ou crie uma nova trilha acima.',
            actionLabel: 'Limpar filtros',
            onAction: () {
              searchController.clear();
              onPremiumFilterChanged(null);
            },
          )
        else
          ...result.items.map(
            (trail) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AdminTrailCard(
                trail: trail,
                onEdit: () => onEditTrail(trail),
                onDelete: onDeleteTrail == null
                    ? null
                    : () => onDeleteTrail!(trail),
              ),
            ),
          ),
        PaginationControls(
          page: result.page,
          totalPages: result.totalPages,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _AdminTrailCard extends StatelessWidget {
  const _AdminTrailCard({
    required this.trail,
    required this.onEdit,
    required this.onDelete,
  });

  final Trail trail;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  trail.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.evoluaColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                trail.category,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(trail.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AdminStatusBadge(
                label: trail.premium ? 'Premium' : 'Essencial',
                color: trail.premium ? AppColors.accentGold : AppColors.accent,
              ),
              if (trail.mediaLinks.isNotEmpty)
                _AdminStatusBadge(
                  label: '${trail.mediaLinks.length} midias',
                  color: AppColors.accentWarm,
                ),
              if (trail.sourceStyle != null && trail.sourceStyle!.isNotEmpty)
                _AdminStatusBadge(
                  label: trail.sourceStyle!,
                  color: context.evoluaColors.textSecondary,
                ),
            ],
          ),
          if (trail.mediaLinks.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: trail.mediaLinks
                  .map(
                    (link) => OutlinedButton.icon(
                      onPressed: null,
                      icon: Icon(
                        link.isYoutube || link.type == 'video'
                            ? Icons.ondemand_video_rounded
                            : Icons.link_rounded,
                      ),
                      label: Text('${link.label} (${link.type})'),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Excluir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminStatusBadge extends StatelessWidget {
  const _AdminStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

class _EditableMediaLink {
  _EditableMediaLink.live()
    : labelController = TextEditingController(),
      urlController = TextEditingController(),
      type = 'auto';

  _EditableMediaLink.fromLink(TrailMediaLink link)
    : labelController = TextEditingController(text: link.label),
      urlController = TextEditingController(text: link.url),
      type = link.type;

  final TextEditingController labelController;
  final TextEditingController urlController;
  String type;

  void dispose() {
    labelController.dispose();
    urlController.dispose();
  }
}

String? _extractYoutubeId(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  if (host.contains('youtu.be')) {
    return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  }
  if (host.contains('youtube.com')) {
    final queryId = uri.queryParameters['v'];
    if (queryId != null && queryId.isNotEmpty) return queryId;
    final embedIndex = uri.pathSegments.indexOf('embed');
    if (embedIndex >= 0 && uri.pathSegments.length > embedIndex + 1) {
      return uri.pathSegments[embedIndex + 1];
    }
  }
  return null;
}

class _EditableTrailStep {
  _EditableTrailStep.live(int index)
    : titleController = TextEditingController(text: 'Nova etapa ${index + 1}'),
      summaryController = TextEditingController(),
      durationController = TextEditingController(text: '5'),
      contentController = TextEditingController(),
      videoUrlController = TextEditingController(),
      videoIdController = TextEditingController(),
      thumbnailController = TextEditingController(),
      videoDurationController = TextEditingController(text: '180'),
      type = 'REFLECTION',
      mediaLinks = [_EditableMediaLink.live()];

  _EditableTrailStep.fromStep(TrailStep step)
    : titleController = TextEditingController(text: step.title),
      summaryController = TextEditingController(text: step.summary),
      durationController = TextEditingController(
        text: step.durationMinutes.toString(),
      ),
      contentController = TextEditingController(text: step.content),
      videoUrlController = TextEditingController(text: step.video?.url ?? ''),
      videoIdController = TextEditingController(
        text: step.video?.videoId ?? '',
      ),
      thumbnailController = TextEditingController(
        text: step.video?.thumbnailUrl ?? '',
      ),
      videoDurationController = TextEditingController(
        text: (step.video?.durationSeconds ?? 180).toString(),
      ),
      type = step.type,
      mediaLinks = step.mediaLinks.isEmpty
          ? [_EditableMediaLink.live()]
          : step.mediaLinks.map(_EditableMediaLink.fromLink).toList();

  _EditableTrailStep.fromLegacyTrail(Trail trail)
    : titleController = TextEditingController(text: trail.title),
      summaryController = TextEditingController(text: trail.summary),
      durationController = TextEditingController(text: '8'),
      contentController = TextEditingController(text: trail.content ?? ''),
      videoUrlController = TextEditingController(),
      videoIdController = TextEditingController(),
      thumbnailController = TextEditingController(),
      videoDurationController = TextEditingController(text: '180'),
      type = 'READING',
      mediaLinks = trail.mediaLinks.isEmpty
          ? [_EditableMediaLink.live()]
          : trail.mediaLinks.map(_EditableMediaLink.fromLink).toList();

  _EditableTrailStep.fromDraft(Map<String, dynamic> data)
    : titleController = TextEditingController(
        text: data['title']?.toString() ?? 'Nova etapa',
      ),
      summaryController = TextEditingController(
        text: data['summary']?.toString() ?? '',
      ),
      durationController = TextEditingController(
        text: (data['durationMinutes'] ?? 5).toString(),
      ),
      contentController = TextEditingController(
        text: data['content']?.toString() ?? '',
      ),
      videoUrlController = TextEditingController(
        text: data['videoUrl']?.toString() ?? '',
      ),
      videoIdController = TextEditingController(
        text: data['videoId']?.toString() ?? '',
      ),
      thumbnailController = TextEditingController(
        text: data['thumbnailUrl']?.toString() ?? '',
      ),
      videoDurationController = TextEditingController(
        text: (data['durationSeconds'] ?? 180).toString(),
      ),
      type = data['type']?.toString() ?? 'REFLECTION',
      mediaLinks = (data['mediaLinks'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => _EditableMediaLink.fromLink(
              TrailMediaLink(
                label: item['label']?.toString() ?? 'Conteudo complementar',
                url: item['url']?.toString() ?? '',
                type: item['type']?.toString() ?? 'external',
              ),
            ),
          )
          .toList() {
    if (mediaLinks.isEmpty) {
      mediaLinks.add(_EditableMediaLink.live());
    }
  }

  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController durationController;
  final TextEditingController contentController;
  final TextEditingController videoUrlController;
  final TextEditingController videoIdController;
  final TextEditingController thumbnailController;
  final TextEditingController videoDurationController;
  String type;
  final List<_EditableMediaLink> mediaLinks;

  void dispose() {
    titleController.dispose();
    summaryController.dispose();
    durationController.dispose();
    contentController.dispose();
    videoUrlController.dispose();
    videoIdController.dispose();
    thumbnailController.dispose();
    videoDurationController.dispose();
    for (final link in mediaLinks) {
      link.dispose();
    }
  }
}
