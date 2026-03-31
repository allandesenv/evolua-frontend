import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ContentModuleView extends ConsumerStatefulWidget {
  const ContentModuleView({super.key});

  @override
  ConsumerState<ContentModuleView> createState() => _ContentModuleViewState();
}

class _ContentModuleViewState extends ConsumerState<ContentModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController(text: 'ansiedade');
  final _searchController = TextEditingController();
  final List<_EditableMediaLink> _mediaLinks = [_EditableMediaLink.live()];
  bool _premium = false;
  bool? _premiumFilter;

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

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    _searchController.dispose();
    for (final link in _mediaLinks) {
      link.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(trailControllerProvider.notifier).create(
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim(),
          content: _contentController.text.trim(),
          category: _categoryController.text.trim(),
          premium: _premium,
          mediaLinks: _buildMediaLinks(),
        );

    if (!mounted) {
      return;
    }

    _titleController.clear();
    _summaryController.clear();
    _contentController.clear();
    _categoryController.text = 'ansiedade';
    setState(() {
      _premium = false;
      for (final link in _mediaLinks) {
        link.dispose();
      }
      _mediaLinks
        ..clear()
        ..add(_EditableMediaLink.live());
    });
  }

  Future<void> _applyFilters() {
    return ref.read(trailControllerProvider.notifier).applyFilters(
          search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
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
            type: item.type == 'auto' ? _detectType(item.urlController.text.trim()) : item.type,
          ),
        )
        .toList();
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

  @override
  Widget build(BuildContext context) {
    final trailsState = ref.watch(trailControllerProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final profile = ref.watch(currentProfileProvider);
    final isAdmin = session?.isAdmin ?? false;
    final hasPremiumAccess = (session?.isPremium ?? false) || (profile?.premium ?? false);
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
                      'Trilhas para seguir no seu tempo',
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
                isAdmin
                    ? 'Como administradora, voce pode criar trilhas com resumo, conteudo rico em Markdown e links de apoio.'
                    : hasPremiumAccess
                        ? 'Seu acesso premium libera trilhas completas, inclusive conteudos exclusivos com apoio multimidia.'
                        : 'No plano gratuito, voce explora trilhas essenciais e pode ver onde o premium aprofunda a experiencia.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              if (isAdmin) _AdminTrailEditor(formKey: _formKey, titleController: _titleController, summaryController: _summaryController, contentController: _contentController, categoryController: _categoryController, premium: _premium, onPremiumChanged: (value) => setState(() => _premium = value), mediaLinks: _mediaLinks, onAddLink: () => setState(() => _mediaLinks.add(_EditableMediaLink.live())), onRemoveLink: (index) => setState(() { _mediaLinks[index].dispose(); _mediaLinks.removeAt(index); if (_mediaLinks.isEmpty) _mediaLinks.add(_EditableMediaLink.live()); }), onSubmit: isSaving ? null : _submit),
            ],
          ),
        ),
        const SizedBox(height: 16),
        trailsState.when(
          data: (result) => _TrailExplorer(
            result: result,
            isAdmin: isAdmin,
            hasPremiumAccess: hasPremiumAccess,
            searchController: _searchController,
            premiumFilter: _premiumFilter,
            onSearchChanged: (_) => _applyFilters(),
            onPremiumFilterChanged: (value) {
              setState(() => _premiumFilter = value);
              _applyFilters();
            },
            onPageChanged: (page) => ref.read(trailControllerProvider.notifier).goToPage(page),
          ),
          error: (error, stackTrace) => _ContentErrorState(
            onRetry: () => ref.read(trailControllerProvider.notifier).refresh(),
          ),
          loading: () => const _ContentLoadingState(),
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
    required this.contentController,
    required this.categoryController,
    required this.premium,
    required this.onPremiumChanged,
    required this.mediaLinks,
    required this.onAddLink,
    required this.onRemoveLink,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController contentController;
  final TextEditingController categoryController;
  final bool premium;
  final ValueChanged<bool> onPremiumChanged;
  final List<_EditableMediaLink> mediaLinks;
  final VoidCallback onAddLink;
  final ValueChanged<int> onRemoveLink;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          const SizedBox(height: 24),
          TextFormField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Titulo da trilha',
              prefixIcon: Icon(Icons.auto_stories_rounded),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Informe o titulo.' : null,
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
          TextFormField(
            controller: contentController,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Conteudo principal em Markdown',
              alignLabelWithHint: true,
              helperText: 'Exemplos: # Titulo, ## Secao, - lista, [link](https://...)',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Escreva o conteudo principal.' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Informe a categoria.' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Links de apoio',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 12),
          ...mediaLinks.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MediaLinkEditor(
                  item: entry.value,
                  onRemove: mediaLinks.length == 1 ? null : () => onRemoveLink(entry.key),
                ),
              )),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddLink,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Adicionar link'),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Criar trilha'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaLinkEditor extends StatelessWidget {
  const _MediaLinkEditor({
    required this.item,
    required this.onRemove,
  });

  final _EditableMediaLink item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.labelController,
                  decoration: const InputDecoration(
                    labelText: 'Rotulo do link',
                    prefixIcon: Icon(Icons.label_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: item.type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    prefixIcon: Icon(Icons.video_library_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto detectar')),
                    DropdownMenuItem(value: 'youtube', child: Text('YouTube')),
                    DropdownMenuItem(value: 'video', child: Text('Video')),
                    DropdownMenuItem(value: 'article', child: Text('Artigo')),
                    DropdownMenuItem(value: 'audio', child: Text('Audio')),
                    DropdownMenuItem(value: 'external', child: Text('Externo')),
                  ],
                  onChanged: (value) => item.type = value ?? 'auto',
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
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
          if (item.urlController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.urlController.text.toLowerCase().contains('youtu')
                    ? 'Preview detectado: YouTube'
                    : 'Preview detectado: link externo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.accentWarm),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrailExplorer extends StatelessWidget {
  const _TrailExplorer({
    required this.result,
    required this.isAdmin,
    required this.hasPremiumAccess,
    required this.searchController,
    required this.premiumFilter,
    required this.onSearchChanged,
    required this.onPremiumFilterChanged,
    required this.onPageChanged,
  });

  final PaginatedResponse<Trail> result;
  final bool isAdmin;
  final bool hasPremiumAccess;
  final TextEditingController searchController;
  final bool? premiumFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool?> onPremiumFilterChanged;
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
                'Encontrar uma trilha certa',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.totalItems} trilhas encontradas nesta busca.',
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
                  ChoiceChip(label: const Text('Todas'), selected: premiumFilter == null, onSelected: (_) => onPremiumFilterChanged(null)),
                  ChoiceChip(label: const Text('Essenciais'), selected: premiumFilter == false, onSelected: (_) => onPremiumFilterChanged(false)),
                  ChoiceChip(label: const Text('Premium'), selected: premiumFilter == true, onSelected: (_) => onPremiumFilterChanged(true)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (result.items.isEmpty)
          GuidedEmptyState(
            icon: Icons.spa_rounded,
            title: 'Nenhuma trilha aparece com esse filtro.',
            subtitle: 'Experimente outro termo ou limpe os filtros para ampliar sua busca.',
            actionLabel: 'Ver todas as trilhas',
            onAction: () {
              searchController.clear();
              onPremiumFilterChanged(null);
            },
          )
        else
          Column(
            children: [
              ...result.items.map(
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
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
                              ),
                            ),
                            Text(
                              trail.category,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.accent),
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
                            _StatusBadge(
                              label: trail.premium ? 'Premium' : 'Essencial',
                              color: trail.premium ? AppColors.accentGold : AppColors.accent,
                            ),
                            if (trail.mediaLinks.isNotEmpty)
                              _StatusBadge(
                                label: '${trail.mediaLinks.length} links',
                                color: AppColors.accentWarm,
                              ),
                            if (!trail.accessible && !isAdmin && !hasPremiumAccess)
                              const _StatusBadge(
                                label: 'Faca upgrade para acessar',
                                color: AppColors.danger,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () => _showTrailDetails(context, trail),
                            icon: const Icon(Icons.visibility_rounded),
                            label: Text(trail.accessible ? 'Abrir trilha' : 'Ver detalhes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PaginationControls(page: result.page, totalPages: result.totalPages, onPageChanged: onPageChanged),
            ],
          ),
      ],
    );
  }

  void _showTrailDetails(BuildContext context, Trail trail) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.backgroundSecondary,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trail.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(trail.summary, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    child: trail.accessible
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MarkdownBody(
                                data: trail.content ?? '',
                                selectable: true,
                                onTapLink: (text, href, title) {
                                  if (href != null) {
                                    launchUrlString(href);
                                  }
                                },
                                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                  p: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
                                  h1: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary),
                                  h2: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
                                  listBullet: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.accent),
                                ),
                              ),
                              if (trail.mediaLinks.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text('Conteudos de apoio', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
                                const SizedBox(height: 12),
                                ...trail.mediaLinks.map(
                                  (link) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: InkWell(
                                      onTap: () => launchUrlString(link.url),
                                      borderRadius: BorderRadius.circular(18),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceStrong.withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(link.isYoutube ? Icons.ondemand_video_rounded : Icons.link_rounded, color: link.isYoutube ? AppColors.danger : AppColors.accentWarm),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(link.label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textPrimary)),
                                                  const SizedBox(height: 4),
                                                  Text(link.url, style: Theme.of(context).textTheme.bodySmall),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : GuidedEmptyState(
                            icon: Icons.workspace_premium_rounded,
                            title: 'Conteudo completo liberado no premium',
                            subtitle: 'Voce pode visualizar o resumo da trilha agora e desbloquear o conteudo completo com upgrade.',
                            actionLabel: 'Entendi',
                            onAction: () => Navigator.of(context).pop(),
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
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

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

class _ContentLoadingState extends StatelessWidget {
  const _ContentLoadingState();

  @override
  Widget build(BuildContext context) {
    return const FeedSkeleton(cards: 3);
  }
}

class _ContentErrorState extends StatelessWidget {
  const _ContentErrorState({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GuidedEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Nao conseguimos abrir as trilhas agora.',
      subtitle: 'Atualize a pagina ou tente novamente em instantes.',
      actionLabel: 'Tentar novamente',
      onAction: onRetry,
    );
  }
}

class _EditableMediaLink {
  _EditableMediaLink.live()
      : labelController = TextEditingController(),
        urlController = TextEditingController(),
        type = 'auto';

  final TextEditingController labelController;
  final TextEditingController urlController;
  String type;

  void dispose() {
    labelController.dispose();
    urlController.dispose();
  }
}
