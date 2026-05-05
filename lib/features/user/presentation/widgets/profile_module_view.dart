import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/notification/presentation/widgets/notification_module_view.dart';
import 'package:evolua_frontend/features/subscription/presentation/widgets/subscription_module_view.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/application/settings_privacy_preferences_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum ProfileModuleSection {
  overview,
  settingsPrivacy,
  helpSupport,
  displayAccessibility,
  feedback,
  plansSubscriptions,
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
    if (_didSeedForm &&
        profile != null &&
        _displayNameController.text.isNotEmpty) {
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

  void _showSettingsMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveSettingsPreferences() async {
    try {
      await ref
          .read(settingsPrivacyPreferencesControllerProvider.notifier)
          .save();
      if (!mounted) {
        return;
      }
      _showSettingsMessage('Preferencias salvas com seguranca.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
    }
  }

  Future<void> _exportSettingsData() async {
    String exportJson;
    try {
      exportJson = await ref
          .read(settingsPrivacyPreferencesControllerProvider.notifier)
          .exportData();
      await Clipboard.setData(ClipboardData(text: exportJson));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
      return;
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Baixar meus dados'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: SelectableText(
                exportJson,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: exportJson));
                Navigator.of(context).pop();
                _showSettingsMessage(
                  'Exportacao copiada para a area de transferencia.',
                );
              },
              child: const Text('Copiar JSON'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword() async {
    final result = await _showPasswordDialog();
    if (result == null) {
      return;
    }
    try {
      await ref
          .read(accountSettingsRepositoryProvider)
          .changePassword(
            currentPassword: result.currentPassword,
            newPassword: result.newPassword,
          );
      if (!mounted) {
        return;
      }
      _showSettingsMessage('Senha alterada com seguranca.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
    }
  }

  Future<void> _revokeSessions() async {
    final confirmed = await _showConfirmDialog(
      title: 'Encerrar sessoes ativas',
      message:
          'As outras sessoes da sua conta serao encerradas. Voce continuara usando este app ate precisar entrar novamente.',
      confirmLabel: 'Encerrar sessoes',
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(accountSettingsRepositoryProvider).revokeSessions();
      if (!mounted) {
        return;
      }
      _showSettingsMessage('Sessoes ativas encerradas.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
    }
  }

  Future<void> _deactivateAccount(String email) async {
    final confirmation = await _showEmailConfirmationDialog(
      title: 'Desativar conta',
      message:
          'Sua conta sera desativada e novos acessos serao bloqueados. Para confirmar, digite seu e-mail.',
      email: email,
      confirmLabel: 'Desativar conta',
    );
    if (confirmation == null) {
      return;
    }
    try {
      await ref
          .read(accountSettingsRepositoryProvider)
          .deactivate(confirmation: confirmation);
      await ref.read(authControllerProvider.notifier).logout();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
    }
  }

  Future<void> _deleteAccount(String email) async {
    final result = await _showDeleteAccountDialog(email);
    if (result == null) {
      return;
    }
    try {
      await ref
          .read(accountSettingsRepositoryProvider)
          .deleteAccount(
            confirmation: result.confirmation,
            currentPassword: result.currentPassword,
          );
      await ref.read(authControllerProvider.notifier).logout();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.accentWarm)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<_PasswordDialogResult?> _showPasswordDialog() async {
    final currentController = TextEditingController();
    final nextController = TextEditingController();
    final confirmController = TextEditingController();
    return showDialog<_PasswordDialogResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha atual'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nextController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nova senha'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar nova senha',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final current = currentController.text.trim();
              final next = nextController.text;
              final confirm = confirmController.text;
              if (current.isEmpty || next.length < 6 || next != confirm) {
                _showSettingsMessage(
                  'Confira a senha atual e use uma nova senha com ao menos 6 caracteres.',
                );
                return;
              }
              Navigator.of(context).pop(
                _PasswordDialogResult(
                  currentPassword: current,
                  newPassword: next,
                ),
              );
            },
            child: const Text('Salvar senha'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showEmailConfirmationDialog({
    required String title,
    required String message,
    required String email,
    required String confirmLabel,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(labelText: email),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.toLowerCase() != email.toLowerCase()) {
                _showSettingsMessage('Digite seu e-mail para confirmar.');
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<_DeleteAccountDialogResult?> _showDeleteAccountDialog(
    String email,
  ) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    return showDialog<_DeleteAccountDialogResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acao e permanente. Para confirmar, digite seu e-mail e informe sua senha atual se sua conta usa email e senha.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: email),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha atual',
                helperText: 'Obrigatoria para contas com email e senha.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final typedEmail = emailController.text.trim();
              if (typedEmail.toLowerCase() != email.toLowerCase()) {
                _showSettingsMessage('Digite seu e-mail para confirmar.');
                return;
              }
              Navigator.of(context).pop(
                _DeleteAccountDialogResult(
                  confirmation: typedEmail,
                  currentPassword: passwordController.text,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentWarm,
            ),
            child: const Text('Excluir conta'),
          ),
        ],
      ),
    );
  }

  String _friendlySettingsError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final details = data['details'];
        if (details is List && details.isNotEmpty) {
          return details.first.toString();
        }
        final message = data['message'];
        if (message != null) {
          return message.toString();
        }
      }
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
      }
    }
    return 'Nao foi possivel concluir esta acao agora.';
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final settingsState = ref.watch(
      settingsPrivacyPreferencesControllerProvider,
    );
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
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ProfileModuleSection.values
                        .map(
                          (section) => ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                            ),
                            child: ChoiceChip(
                              label: Text(
                                _sectionLabel(section),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: _section == section,
                              onSelected: (_) =>
                                  setState(() => _section = section),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
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
            onJourneyLevelChanged: (value) =>
                setState(() => _journeyLevel = value),
            onPickBirthDate: _pickBirthDate,
            onSubmit: _saveProfile,
          )
        else if (_section == ProfileModuleSection.settingsPrivacy)
          settingsState.when(
            data: (preferences) {
              final settingsController = ref.read(
                settingsPrivacyPreferencesControllerProvider.notifier,
              );
              return _SettingsPrivacySection(
                email: session?.email ?? 'voce@evolua.app',
                privateJournal: preferences.privateJournal,
                hideSocialCheckIns: preferences.hideSocialCheckIns,
                allowHistoryInsights: preferences.allowHistoryInsights,
                useEmotionalDataForAi: preferences.useEmotionalDataForAi,
                dailyReminders: preferences.dailyReminders,
                contentPreferences: preferences.contentPreferences,
                aiTone: preferences.aiTone,
                suggestionFrequency: preferences.suggestionFrequency,
                trailStyle: preferences.trailStyle,
                onPrivateJournalChanged: (value) =>
                    settingsController.updatePreferences(
                      (current) => current.copyWith(privateJournal: value),
                    ),
                onHideSocialCheckInsChanged: (value) =>
                    settingsController.updatePreferences(
                      (current) => current.copyWith(hideSocialCheckIns: value),
                    ),
                onAllowHistoryInsightsChanged: (value) =>
                    settingsController.updatePreferences(
                      (current) =>
                          current.copyWith(allowHistoryInsights: value),
                    ),
                onUseEmotionalDataForAiChanged: (value) =>
                    settingsController.updatePreferences(
                      (current) =>
                          current.copyWith(useEmotionalDataForAi: value),
                    ),
                onDailyRemindersChanged: (value) =>
                    settingsController.updatePreferences(
                      (current) => current.copyWith(dailyReminders: value),
                    ),
                onContentPreferencesChanged: (value) =>
                    settingsController.updatePreferences(
                      (current) => current.copyWith(contentPreferences: value),
                    ),
                onAiToneChanged: (value) =>
                    settingsController.updatePreferences(
                      (current) => current.copyWith(aiTone: value),
                    ),
                onSuggestionFrequencyChanged: (value) =>
                    settingsController.updatePreferences(
                      (current) => current.copyWith(suggestionFrequency: value),
                    ),
                onTrailStyleChanged: (value) =>
                    settingsController.updatePreferences(
                      (current) => current.copyWith(trailStyle: value),
                    ),
                onSavePreferences: _saveSettingsPreferences,
                onExportData: _exportSettingsData,
                onChangePassword: _changePassword,
                onRevokeSessions: _revokeSessions,
                onDeactivateAccount: () =>
                    _deactivateAccount(session?.email ?? 'voce@evolua.app'),
                onDeleteAccount: () =>
                    _deleteAccount(session?.email ?? 'voce@evolua.app'),
                onInformationalAction: () => _showSettingsMessage(
                  'Esta informacao sera aberta em uma area dedicada em breve.',
                ),
              );
            },
            loading: () => const PrimaryPanel(child: LinearProgressIndicator()),
            error: (_, _) => PrimaryPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuracoes e privacidade',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nao foi possivel carregar suas preferencias agora.',
                  ),
                ],
              ),
            ),
          )
        else if (_section == ProfileModuleSection.plansSubscriptions)
          const SubscriptionModuleView()
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
              ProfileModuleSection.plansSubscriptions =>
                'Gerencie seu plano atual e as opcoes de assinatura.',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;
        final nameStyle = isCompact
            ? Theme.of(context).textTheme.titleLarge
            : Theme.of(context).textTheme.headlineMedium;
        final identity = Row(
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: nameStyle,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: OutlinedButton.icon(
                onPressed: onChangeAvatar,
                icon: const Icon(Icons.photo_camera_back_rounded),
                label: const Text(
                  'Trocar foto',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Atualizar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, const SizedBox(height: 16), actions],
          );
        }

        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
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

class _SettingsPrivacySection extends StatelessWidget {
  const _SettingsPrivacySection({
    required this.email,
    required this.privateJournal,
    required this.hideSocialCheckIns,
    required this.allowHistoryInsights,
    required this.useEmotionalDataForAi,
    required this.dailyReminders,
    required this.contentPreferences,
    required this.aiTone,
    required this.suggestionFrequency,
    required this.trailStyle,
    required this.onPrivateJournalChanged,
    required this.onHideSocialCheckInsChanged,
    required this.onAllowHistoryInsightsChanged,
    required this.onUseEmotionalDataForAiChanged,
    required this.onDailyRemindersChanged,
    required this.onContentPreferencesChanged,
    required this.onAiToneChanged,
    required this.onSuggestionFrequencyChanged,
    required this.onTrailStyleChanged,
    required this.onSavePreferences,
    required this.onExportData,
    required this.onChangePassword,
    required this.onRevokeSessions,
    required this.onDeactivateAccount,
    required this.onDeleteAccount,
    required this.onInformationalAction,
  });

  final String email;
  final bool privateJournal;
  final bool hideSocialCheckIns;
  final bool allowHistoryInsights;
  final bool useEmotionalDataForAi;
  final bool dailyReminders;
  final bool contentPreferences;
  final String aiTone;
  final String suggestionFrequency;
  final String trailStyle;
  final ValueChanged<bool> onPrivateJournalChanged;
  final ValueChanged<bool> onHideSocialCheckInsChanged;
  final ValueChanged<bool> onAllowHistoryInsightsChanged;
  final ValueChanged<bool> onUseEmotionalDataForAiChanged;
  final ValueChanged<bool> onDailyRemindersChanged;
  final ValueChanged<bool> onContentPreferencesChanged;
  final ValueChanged<String> onAiToneChanged;
  final ValueChanged<String> onSuggestionFrequencyChanged;
  final ValueChanged<String> onTrailStyleChanged;
  final VoidCallback onSavePreferences;
  final VoidCallback onExportData;
  final VoidCallback onChangePassword;
  final VoidCallback onRevokeSessions;
  final VoidCallback onDeactivateAccount;
  final VoidCallback onDeleteAccount;
  final VoidCallback onInformationalAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configuracoes e privacidade',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Gerencie sua conta, proteja seus dados e personalize como o Evolua funciona para voce.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Conta e acesso',
          description:
              'Controle as informacoes basicas da sua conta e como voce acessa o Evolua.',
          microcopy:
              'Sua conta e a base da sua jornada. Mantenha seus acessos seguros e atualizados.',
          children: [
            _SettingsInfoRow(
              icon: Icons.alternate_email_rounded,
              title: 'E-mail de acesso',
              subtitle: email,
            ),
            _SettingsActionRow(
              icon: Icons.lock_reset_rounded,
              title: 'Alterar senha',
              subtitle: 'Atualize sua senha com seguranca.',
              onTap: onChangePassword,
            ),
            _SettingsInfoRow(
              icon: Icons.g_mobiledata_rounded,
              title: 'Login com Google',
              subtitle: 'Conexao disponivel para entrada rapida.',
            ),
            _SettingsActionRow(
              icon: Icons.devices_rounded,
              title: 'Dispositivos conectados',
              subtitle: 'Revise onde sua conta esta ativa.',
              onTap: onInformationalAction,
            ),
            _SettingsActionRow(
              icon: Icons.logout_rounded,
              title: 'Encerrar sessoes ativas',
              subtitle:
                  'Proteja sua conta em dispositivos que voce nao usa mais.',
              onTap: onRevokeSessions,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Privacidade emocional',
          description:
              'Escolha como seus registros emocionais e reflexoes sao tratados dentro da plataforma.',
          microcopy:
              'Seu processo e pessoal. Voce decide o que fica privado e o que pode ser usado para tornar sua experiencia mais precisa.',
          children: [
            _SettingsSwitchRow(
              title: 'Tornar diario privado',
              subtitle: 'Mantenha seus registros apenas no seu espaco.',
              value: privateJournal,
              onChanged: onPrivateJournalChanged,
            ),
            _SettingsSwitchRow(
              title: 'Ocultar check-ins da visao social',
              subtitle: 'Evite que check-ins aparecam em areas sociais.',
              value: hideSocialCheckIns,
              onChanged: onHideSocialCheckInsChanged,
            ),
            _SettingsSwitchRow(
              title: 'Permitir insights com base no historico',
              subtitle: 'Use seu historico para leituras mais consistentes.',
              value: allowHistoryInsights,
              onChanged: onAllowHistoryInsightsChanged,
            ),
            _SettingsSwitchRow(
              title: 'Usar dados emocionais para personalizacao da IA',
              subtitle: 'Ajude a IA a responder com mais contexto.',
              value: useEmotionalDataForAi,
              onChanged: onUseEmotionalDataForAiChanged,
            ),
            _SettingsActionRow(
              icon: Icons.ios_share_rounded,
              title: 'Exportar historico emocional',
              subtitle: 'Receba uma copia dos seus registros emocionais.',
              onTap: onExportData,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Dados e seguranca',
          description: 'Tenha total transparencia sobre seus dados.',
          microcopy:
              'Seus dados pertencem a voce. O Evolua existe para apoiar sua jornada, nao para invadir sua privacidade.',
          children: [
            _SettingsActionRow(
              icon: Icons.download_rounded,
              title: 'Baixar meus dados',
              subtitle: 'Solicite uma copia completa das suas informacoes.',
              onTap: onExportData,
            ),
            _SettingsActionRow(
              icon: Icons.delete_forever_rounded,
              title: 'Solicitar exclusao da conta',
              subtitle:
                  'A exclusao exige confirmacao antes de qualquer remocao.',
              destructive: true,
              onTap: onDeleteAccount,
            ),
            _SettingsActionRow(
              icon: Icons.pause_circle_outline_rounded,
              title: 'Desativar conta',
              subtitle:
                  'Bloqueie novos acessos sem remover seus dados da jornada.',
              destructive: true,
              onTap: onDeactivateAccount,
            ),
            _SettingsActionRow(
              icon: Icons.history_rounded,
              title: 'Historico de atividade',
              subtitle: 'Veja eventos importantes da sua conta.',
              onTap: onInformationalAction,
            ),
            _SettingsActionRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Politica de privacidade',
              subtitle: 'Entenda como seus dados sao tratados.',
              onTap: onInformationalAction,
            ),
            _SettingsActionRow(
              icon: Icons.article_outlined,
              title: 'Termos de uso',
              subtitle: 'Leia os termos que orientam o uso do Evolua.',
              onTap: onInformationalAction,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Personalizacao da experiencia',
          description: 'Ajuste como o Evolua se adapta ao seu momento.',
          microcopy:
              'O Evolua pode se adaptar ao seu ritmo. Ajuste a experiencia para que ela faca sentido no seu momento atual.',
          children: [
            _SettingsDropdownRow(
              title: 'Tom da IA',
              subtitle: 'Escolha como a IA conversa com voce.',
              value: aiTone,
              items: const {
                'acolhedor': 'Mais acolhedor',
                'direto': 'Mais direto',
                'reflexivo': 'Mais reflexivo',
              },
              onChanged: onAiToneChanged,
            ),
            _SettingsDropdownRow(
              title: 'Frequencia de sugestoes',
              subtitle: 'Defina o ritmo das recomendacoes.',
              value: suggestionFrequency,
              items: const {
                'baixa': 'Baixa',
                'equilibrada': 'Equilibrada',
                'alta': 'Alta',
              },
              onChanged: onSuggestionFrequencyChanged,
            ),
            _SettingsSwitchRow(
              title: 'Lembretes diarios',
              subtitle: 'Receba lembretes gentis para manter constancia.',
              value: dailyReminders,
              onChanged: onDailyRemindersChanged,
            ),
            _SettingsDropdownRow(
              title: 'Estilo das trilhas',
              subtitle: 'Escolha como prefere seguir sua jornada.',
              value: trailStyle,
              items: const {
                'guiada': 'Mais guiada',
                'livre': 'Mais livre',
                'profunda': 'Mais profunda',
              },
              onChanged: onTrailStyleChanged,
            ),
            _SettingsSwitchRow(
              title: 'Preferencias de conteudo',
              subtitle: 'Priorize conteudos alinhados ao seu momento.',
              value: contentPreferences,
              onChanged: onContentPreferencesChanged,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsFooterActions(
          onSavePreferences: onSavePreferences,
          onExportData: onExportData,
          onDeactivateAccount: onDeactivateAccount,
          onDeleteAccount: onDeleteAccount,
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.description,
    required this.microcopy,
    required this.children,
  });

  final String title;
  final String description;
  final String microcopy;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 10),
          Text(
            microcopy,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: const Icon(Icons.check_circle_outline_rounded),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.accentWarm : AppColors.accent;
    return _SettingsRowShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      iconColor: color,
      titleColor: destructive ? AppColors.accentWarm : null,
      onTap: onTap,
      trailing: Icon(Icons.chevron_right_rounded, color: color),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      icon: value ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _SettingsDropdownRow extends StatelessWidget {
  const _SettingsDropdownRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: title,
          helperText: subtitle,
          prefixIcon: const Icon(Icons.tune_rounded),
        ),
        items: items.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

class _SettingsRowShell extends StatelessWidget {
  const _SettingsRowShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceStrong.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor ?? AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: titleColor ?? AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsFooterActions extends StatelessWidget {
  const _SettingsFooterActions({
    required this.onSavePreferences,
    required this.onExportData,
    required this.onDeactivateAccount,
    required this.onDeleteAccount,
  });

  final VoidCallback onSavePreferences;
  final VoidCallback onExportData;
  final VoidCallback onDeactivateAccount;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: onSavePreferences,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Salvar preferencias'),
          ),
          OutlinedButton.icon(
            onPressed: onExportData,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Baixar meus dados'),
          ),
          OutlinedButton.icon(
            onPressed: onDeactivateAccount,
            icon: const Icon(Icons.pause_circle_outline_rounded),
            label: const Text('Desativar conta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentWarm,
            ),
          ),
          TextButton.icon(
            onPressed: onDeleteAccount,
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Excluir conta'),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentWarm),
          ),
        ],
      ),
    );
  }
}

class _PasswordDialogResult {
  const _PasswordDialogResult({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;
}

class _DeleteAccountDialogResult {
  const _DeleteAccountDialogResult({
    required this.confirmation,
    required this.currentPassword,
  });

  final String confirmation;
  final String currentPassword;
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
    final normalizedUrl = imageUrl == null || imageUrl!.isEmpty
        ? null
        : imageUrl!;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceStrong,
      backgroundImage: normalizedUrl != null
          ? NetworkImage(normalizedUrl)
          : null,
      child: normalizedUrl == null
          ? Text(
              _initials(fallbackText),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
            )
          : null,
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'E';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

String _sectionLabel(ProfileModuleSection section) {
  return switch (section) {
    ProfileModuleSection.overview => 'Visao geral',
    ProfileModuleSection.settingsPrivacy => 'Configuracoes e privacidade',
    ProfileModuleSection.helpSupport => 'Ajuda e suporte',
    ProfileModuleSection.displayAccessibility => 'Tela e acessibilidade',
    ProfileModuleSection.feedback => 'Dar feedback',
    ProfileModuleSection.plansSubscriptions => 'Planos e assinaturas',
  };
}
