import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocialModuleView extends ConsumerStatefulWidget {
  const SocialModuleView({super.key});

  @override
  ConsumerState<SocialModuleView> createState() => _SocialModuleViewState();
}

class _SocialModuleViewState extends ConsumerState<SocialModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _communityController = TextEditingController(text: 'geral');
  String _visibility = 'PUBLIC';

  @override
  void initState() {
    super.initState();
    ref.listenManual(socialPostControllerProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DioException
            ? (error.response?.data is Map<String, dynamic>
                ? ((error.response?.data['details'] as List?)?.join(', ') ??
                    error.message ??
                    'Nao foi possivel publicar.')
                : error.message ?? 'Nao foi possivel publicar.')
            : 'Nao foi possivel publicar.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _communityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(socialPostControllerProvider.notifier).create(
          content: _contentController.text.trim(),
          community: _communityController.text.trim(),
          visibility: _visibility,
        );

    if (!mounted) {
      return;
    }

    _contentController.clear();
    _communityController.text = 'geral';
    setState(() => _visibility = 'PUBLIC');
  }

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(socialPostControllerProvider);

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
                      'Feed e comunidade',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(socialPostControllerProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Publique posts por comunidade e visibilidade para iniciar a camada social do produto.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _contentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Conteudo do post',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.forum_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Escreva o conteudo.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _communityController,
                            decoration: const InputDecoration(
                              labelText: 'Comunidade',
                              prefixIcon: Icon(Icons.groups_rounded),
                            ),
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'Informe a comunidade.'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _visibility,
                            decoration: const InputDecoration(
                              labelText: 'Visibilidade',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'PUBLIC', child: Text('PUBLIC')),
                              DropdownMenuItem(value: 'PRIVATE', child: Text('PRIVATE')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _visibility = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: postsState.isLoading && !postsState.hasValue ? null : _submit,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Publicar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        postsState.when(
          data: (posts) => _SocialPostList(posts: posts),
          error: (error, stackTrace) => const _SocialErrorState(),
          loading: () => const _SocialLoadingState(),
        ),
      ],
    );
  }
}

class _SocialPostList extends StatelessWidget {
  const _SocialPostList({required this.posts});

  final List<SocialPost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const _SocialEmptyState();
    }

    return Column(
      children: posts
          .map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PrimaryPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.community,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        Text(
                          post.visibility,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.accent,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(post.content, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SocialLoadingState extends StatelessWidget {
  const _SocialLoadingState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Carregando posts...'),
        ],
      ),
    );
  }
}

class _SocialEmptyState extends StatelessWidget {
  const _SocialEmptyState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Text('Nenhum post publicado ainda.'),
    );
  }
}

class _SocialErrorState extends StatelessWidget {
  const _SocialErrorState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Text(
        'Nao foi possivel carregar posts.',
        style: TextStyle(color: AppColors.danger),
      ),
    );
  }
}
