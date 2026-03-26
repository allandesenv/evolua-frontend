import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileModuleView extends ConsumerStatefulWidget {
  const ProfileModuleView({super.key});

  @override
  ConsumerState<ProfileModuleView> createState() => _ProfileModuleViewState();
}

class _ProfileModuleViewState extends ConsumerState<ProfileModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  double _journeyLevel = 1;
  bool _premium = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(profileControllerProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DioException
            ? (error.response?.data is Map<String, dynamic>
                ? ((error.response?.data['details'] as List?)?.join(', ') ??
                    error.message ??
                    'Nao foi possivel salvar o perfil.')
                : error.message ?? 'Nao foi possivel salvar o perfil.')
            : 'Nao foi possivel salvar o perfil.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(profileControllerProvider.notifier).create(
          displayName: _displayNameController.text.trim(),
          bio: _bioController.text.trim(),
          journeyLevel: _journeyLevel.round(),
          premium: _premium,
        );

    if (!mounted) {
      return;
    }

    _displayNameController.clear();
    _bioController.clear();
    setState(() {
      _journeyLevel = 1;
      _premium = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profilesState = ref.watch(profileControllerProvider);
    final isSaving = profilesState.isLoading && !(profilesState.hasValue);

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
                      'Perfil e jornada',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(profileControllerProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Crie o perfil inicial do usuario com nome, bio, nivel de jornada e status premium.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome de exibicao',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Informe o nome do perfil.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Informe uma bio curta.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nivel da jornada: ${_journeyLevel.round()}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              Slider(
                                min: 1,
                                max: 10,
                                divisions: 9,
                                value: _journeyLevel,
                                onChanged: (value) {
                                  setState(() => _journeyLevel = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Conta premium'),
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
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Salvar perfil'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        profilesState.when(
          data: (profiles) => _ProfileList(profiles: profiles),
          error: (error, stackTrace) => const _ModuleErrorState(
            title: 'Nao foi possivel carregar perfis.',
          ),
          loading: () => const _ModuleLoadingState(label: 'Carregando perfis...'),
        ),
      ],
    );
  }
}

class _ProfileList extends StatelessWidget {
  const _ProfileList({required this.profiles});

  final List<Profile> profiles;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return const _ModuleEmptyState(
        title: 'Nenhum perfil criado ainda.',
        subtitle: 'Preencha o formulario acima para iniciar a jornada do usuario.',
      );
    }

    return Column(
      children: profiles
          .map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PrimaryPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.displayName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: (profile.premium ? AppColors.accentGold : AppColors.accent)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            profile.premium ? 'Premium' : 'Essencial',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: profile.premium ? AppColors.accentGold : AppColors.accent,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(profile.bio, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 14),
                    Text(
                      'Nivel da jornada ${profile.journeyLevel} · criado em ${profile.createdAt.day.toString().padLeft(2, '0')}/${profile.createdAt.month.toString().padLeft(2, '0')}/${profile.createdAt.year}',
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

class _ModuleLoadingState extends StatelessWidget {
  const _ModuleLoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

class _ModuleEmptyState extends StatelessWidget {
  const _ModuleEmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ModuleErrorState extends StatelessWidget {
  const _ModuleErrorState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.danger,
            ),
      ),
    );
  }
}
