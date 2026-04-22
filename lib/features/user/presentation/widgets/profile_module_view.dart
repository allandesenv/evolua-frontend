import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/notification/presentation/widgets/notification_module_view.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum ProfileModuleSection {
  overview,
  settingsPrivacy,
  helpSupport,
  displayAccessibility,
  feedback,
}

class ProfileModuleView extends ConsumerStatefulWidget {
  const ProfileModuleView({
    super.key,
    this.section = ProfileModuleSection.overview,
  });

  final ProfileModuleSection section;

  @override
  ConsumerState<ProfileModuleView> createState() => _ProfileModuleViewState();
}

class _ProfileModuleViewState extends ConsumerState<ProfileModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _customGenderController = TextEditingController();
  final _picker = ImagePicker();
  double _journeyLevel = 1;
  String _gender = 'MALE';
  DateTime? _birthDate;
  bool _didSeedForm = false;
  late ProfileModuleSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.section;
    ref.listenManual(profileControllerProvider, (previous, next) {
      if (!next.hasError) {
        return;
      }

      final error = next.error;
      final message = error is DioException
          ? (error.response?.data is Map<String, dynamic>
                ? ((error.response?.data['details'] as List?)?.join(', ') ??
                      error.response?.data['message']?.toString() ??
                      error.message ??
                      'Nao foi possivel salvar o perfil.')
                : error.message ?? 'Nao foi possivel salvar o perfil.')
          : 'Nao foi possivel salvar o perfil.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  void didUpdateWidget(covariant ProfileModuleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _section = widget.section;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _customGenderController.dispose();
    super.dispose();
  }

  void _seedForm(Profile? profile, String fallbackName) {
    if (_didSeedForm && profile == null) {
      return;
    }
    if (_didSeedForm && profile != null && _displayNameController.text.isNotEmpty) {
      return;
    }

    _displayNameController.text = profile?.displayName ?? fallbackName;
    _bioController.text = profile?.bio ?? '';
    _journeyLevel = (profile?.journeyLevel ?? 1).toDouble();
    _gender = profile?.gender ?? 'MALE';
    _customGenderController.text = profile?.customGender ?? '';
    _birthDate = profile?.birthDate;
    _didSeedForm = true;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      locale: const Locale('pt', 'BR'),
    );
    if (selected != null) {
      setState(() => _birthDate = selected);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _birthDate == null) {
      return;
    }

    await ref
        .read(profileControllerProvider.notifier)
        .upsertMe(
          displayName: _displayNameController.text.trim(),
          birthDate: _birthDate!,
          gender: _gender,
          customGender: _gender == 'CUSTOM'
              ? _customGenderController.text.trim()
              : null,
          bio: _bioController.text.trim(),
          journeyLevel: _journeyLevel.round(),
        );
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    await ref
        .read(profileControllerProvider.notifier)
        .uploadAvatar(bytes: bytes, fileName: image.name);
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final profile = profileState.asData?.value;
    final isSaving = profileState.isLoading && profileState.hasValue;
    final isAdmin = session?.isAdmin ?? false;
    final fallbackName =
        session?.displayName ?? session?.email.split('@').first ?? 'Seu perfil';

    _seedForm(profile, fallbackName);

    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileHero(
                displayName: profile?.displayName ?? fallbackName,
                email: session?.email ?? 'voce@evolua.app',
                avatarUrl: profile?.avatarUrl ?? session?.avatarUrl,
                onRefresh: () =>
                    ref.read(profileControllerProvider.notifier).refresh(),
                onChangeAvatar: _pickAvatar,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ProfileModuleSection.values
                    .map(
                      (section) => ChoiceChip(
                        label: Text(_sectionLabel(section)),
                        selected: _section == section,
                        onSelected: (_) => setState(() => _section = section),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_section == ProfileModuleSection.overview)
          _OverviewSection(
            formKey: _formKey,
            displayNameController: _displayNameController,
            bioController: _bioController,
            customGenderController: _customGenderController,
            gender: _gender,
            birthDate: _birthDate,
            journeyLevel: _journeyLevel,
            isSaving: isSaving,
            onGenderChanged: (value) => setState(() => _gender = value),
            onJourneyLevelChanged: (value) => setState(() => _journeyLevel = value),
            onPickBirthDate: _pickBirthDate,
            onSubmit: _saveProfile,
          )
        else
          _SectionPanel(
            title: _sectionLabel(_section),
            subtitle: switch (_section) {
              ProfileModuleSection.settingsPrivacy =>
                'Ajuste informacoes pessoais, dados da conta e o que fica visivel para voce nesta jornada.',
              ProfileModuleSection.helpSupport =>
                'Use esta area como ponto de apoio para duvidas, orientacoes e proximos passos de suporte.',
              ProfileModuleSection.displayAccessibility =>
                'Centralize preferencias de leitura, foco visual e conforto de uso nesta tela.',
              ProfileModuleSection.feedback =>
                'Registre sugestoes e percepcoes sobre a experiencia do app sem sair do seu espaco.',
              ProfileModuleSection.overview =>
                'Visao geral do seu perfil e dos dados principais da sua conta.',
            },
          ),
        if (profileState.isLoading && !profileState.hasValue) ...[
          const SizedBox(height: 16),
          const FeedSkeleton(cards: 2),
        ],
        if (isAdmin) ...[
          const SizedBox(height: 16),
          const NotificationAdminConsole(),
        ],
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.onRefresh,
    required this.onChangeAvatar,
  });

  final String displayName;
  final String email;
  final String? avatarUrl;
  final VoidCallback onRefresh;
  final VoidCallback onChangeAvatar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AvatarCircle(
          imageUrl: avatarUrl,
          radius: 34,
          fallbackText: displayName,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(email, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onChangeAvatar,
              icon: const Icon(Icons.photo_camera_back_rounded),
              label: const Text('Trocar foto'),
            ),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Atualizar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.formKey,
    required this.displayNameController,
    required this.bioController,
    required this.customGenderController,
    required this.gender,
    required this.birthDate,
    required this.journeyLevel,
    required this.isSaving,
    required this.onGenderChanged,
    required this.onJourneyLevelChanged,
    required this.onPickBirthDate,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController displayNameController;
  final TextEditingController bioController;
  final TextEditingController customGenderController;
  final String gender;
  final DateTime? birthDate;
  final double journeyLevel;
  final bool isSaving;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<double> onJourneyLevelChanged;
  final VoidCallback onPickBirthDate;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visao geral',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Essas informacoes passam a sustentar seu perfil principal e a experiencia personalizada no app.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: displayNameController,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Informe seu nome.'
                  : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: onPickBirthDate,
              borderRadius: BorderRadius.circular(18),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de nascimento',
                  prefixIcon: Icon(Icons.cake_rounded),
                ),
                child: Text(
                  birthDate == null
                      ? 'Selecione sua data'
                      : '${birthDate!.day.toString().padLeft(2, '0')}/${birthDate!.month.toString().padLeft(2, '0')}/${birthDate!.year}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(
                labelText: 'Genero',
                prefixIcon: Icon(Icons.wc_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'MALE', child: Text('Masculino')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Feminino')),
                DropdownMenuItem(value: 'CUSTOM', child: Text('Personalizado')),
              ],
              onChanged: (value) => onGenderChanged(value ?? 'MALE'),
            ),
            if (gender == 'CUSTOM') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: customGenderController,
                decoration: const InputDecoration(
                  labelText: 'Como voce se identifica',
                  prefixIcon: Icon(Icons.draw_rounded),
                ),
                validator: (value) {
                  if (gender == 'CUSTOM' &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Informe seu genero personalizado.';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: bioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Conte um pouco sobre voce, se quiser.',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nivel da jornada: ${journeyLevel.round()}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Slider(
              min: 1,
              max: 10,
              divisions: 9,
              value: journeyLevel,
              onChanged: onJourneyLevelChanged,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : onSubmit,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Salvar perfil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.imageUrl,
    required this.radius,
    required this.fallbackText,
  });

  final String? imageUrl;
  final double radius;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl == null || imageUrl!.isEmpty ? null : imageUrl!;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceStrong,
      backgroundImage: normalizedUrl != null ? NetworkImage(normalizedUrl) : null,
      child: normalizedUrl == null
          ? Text(
              _initials(fallbackText),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
              ),
            )
          : null,
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((item) => item.isNotEmpty).toList();
    if (parts.isEmpty) {
      return 'E';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

String _sectionLabel(ProfileModuleSection section) {
  return switch (section) {
    ProfileModuleSection.overview => 'Visao geral',
    ProfileModuleSection.settingsPrivacy => 'Configuracoes e privacidade',
    ProfileModuleSection.helpSupport => 'Ajuda e suporte',
    ProfileModuleSection.displayAccessibility => 'Tela e acessibilidade',
    ProfileModuleSection.feedback => 'Dar feedback',
  };
}
