import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_controller.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:evolua_frontend/features/notification/application/local_check_in_reminder_controller.dart';
import 'package:evolua_frontend/features/subscription/presentation/widgets/subscription_module_view.dart';
import 'package:evolua_frontend/features/user/application/accessibility_preferences_controller.dart';
import 'package:evolua_frontend/features/user/application/feedback_controller.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/application/settings_privacy_preferences_controller.dart';
import 'package:evolua_frontend/features/user/application/support_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:evolua_frontend/l10n/locale_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

typedef LegalUrlLauncher = Future<bool> Function(Uri url);

final legalUrlLauncherProvider = Provider<LegalUrlLauncher>((ref) {
  return (url) => launchUrl(url, mode: LaunchMode.externalApplication);
});

enum ProfileModuleSection {
  overview,
  settingsPrivacy,
  helpSupport,
  displayAccessibility,
  feedback,
  plansSubscriptions,
  evolutionMirror,
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
  final _birthDateController = TextEditingController();
  final _bioController = TextEditingController();
  final _customGenderController = TextEditingController();
  final _picker = ImagePicker();
  double _journeyLevel = 1;
  String _gender = 'MALE';
  DateTime? _birthDate;
  String? _birthDateError;
  bool _didSeedForm = false;
  bool _isSavingProfile = false;
  bool _isUploadingAvatar = false;
  Uint8List? _avatarPreviewBytes;
  int _avatarRefreshNonce = 0;
  late ProfileModuleSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.section;
    ref.listenManual(profileControllerProvider, (previous, next) {
      if (!next.hasError) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlySettingsError(next.error!))),
      );
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
    _birthDateController.dispose();
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
    _birthDateController.text = _birthDate == null
        ? ''
        : formatBirthDate(_birthDate!);
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
      setState(() {
        _birthDate = selected;
        _birthDateController.text = formatBirthDate(selected);
        _birthDateError = validateBirthDateText(_birthDateController.text);
      });
    }
  }

  void _handleProfileBirthDateChanged(String value) {
    setState(() {
      _birthDate = parseBirthDateText(value);
      _birthDateError = validateBirthDateText(value);
    });
  }

  Future<void> _saveProfile() async {
    if (_isSavingProfile) {
      return;
    }
    _birthDate = parseBirthDateText(_birthDateController.text);
    _birthDateError = validateBirthDateText(_birthDateController.text);
    if (!_formKey.currentState!.validate() || _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_birthDateError ?? 'Informe sua data de nascimento.'),
        ),
      );
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil salvo')));
    } catch (_) {
      // O listener do provider mostra o erro amigável preservando os campos.
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    if (_isUploadingAvatar) {
      return;
    }
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    setState(() {
      _avatarPreviewBytes = bytes;
      _isUploadingAvatar = true;
    });
    try {
      await ref
          .read(profileControllerProvider.notifier)
          .uploadAvatar(bytes: bytes, fileName: image.name);
      if (!mounted) {
        return;
      }
      setState(() => _avatarRefreshNonce++);
      _showSettingsMessage('Foto atualizada.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _avatarPreviewBytes = null);
      _showSettingsMessage(_friendlySettingsError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          if (_avatarPreviewBytes != null) {
            _avatarPreviewBytes = null;
          }
        });
      }
    }
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
      _showSettingsMessage('Preferências salvas com segurança.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
    }
  }

  Future<void> _setDailyCheckInReminderEnabled(bool enabled) async {
    try {
      final reminderEnabled = await ref
          .read(dailyCheckInReminderControllerProvider.notifier)
          .setEnabled(enabled);
      if (!mounted) {
        return;
      }
      _showSettingsMessage(
        reminderEnabled
            ? 'Lembrete diário de check-in ativado.'
            : 'Lembrete diário de check-in desativado.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
    }
  }

  Future<void> _pickDailyCheckInReminderTime() async {
    final reminder =
        ref.read(dailyCheckInReminderControllerProvider).value ??
        DailyCheckInReminderPreferences.defaults();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: reminder.hour, minute: reminder.minute),
      helpText: 'Horário do lembrete',
      cancelText: 'Cancelar',
      confirmText: 'Salvar',
    );
    if (picked == null) {
      return;
    }
    try {
      await ref
          .read(dailyCheckInReminderControllerProvider.notifier)
          .updateReminderTime(hour: picked.hour, minute: picked.minute);
      if (!mounted) {
        return;
      }
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _showSettingsMessage('Lembrete diário ajustado para $formatted.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
    }
  }

  Future<void> _openLegalLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _showSettingsMessage(
        'Não foi possível abrir este documento agora. Tente novamente em instantes.',
      );
      return;
    }

    try {
      final opened = await ref.read(legalUrlLauncherProvider)(uri);
      if (!opened && mounted) {
        _showSettingsMessage(
          'Não foi possível abrir este documento agora. Tente novamente em instantes.',
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(
        'Não foi possível abrir este documento agora. Tente novamente em instantes.',
      );
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
                  'Exportação copiada para a área de transferência.',
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
      _showSettingsMessage('Senha alterada com segurança.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
    }
  }

  Future<void> _revokeSessions() async {
    final confirmed = await _showConfirmDialog(
      title: 'Encerrar sessões ativas',
      message:
          'As outras sessões da sua conta serão encerradas. Você continuará usando este app até precisar entrar novamente.',
      confirmLabel: 'Encerrar sessões',
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(accountSettingsRepositoryProvider).revokeSessions();
      if (!mounted) {
        return;
      }
      _showSettingsMessage('Sessões ativas encerradas.');
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
              'Esta ação e permanente. Para confirmar, digite seu e-mail e informe sua senha atual se sua conta usa email e senha.',
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

  Future<void> _saveAccessibilityPreferences() async {
    try {
      await ref
          .read(accessibilityPreferencesControllerProvider.notifier)
          .save();
      if (!mounted) {
        return;
      }
      _showSettingsMessage('Preferências visuais salvas com conforto.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
    }
  }

  Future<void> _openSupportTicket({
    required String category,
    required String subject,
  }) async {
    final result = await _showSupportTicketDialog(subject: subject);
    if (result == null) {
      return;
    }

    try {
      final ticket = await ref
          .read(supportRepositoryProvider)
          .createTicket(
            category: category,
            subject: result.subject,
            message: result.message,
          );
      if (!mounted) {
        return;
      }
      _showSettingsMessage(
        'Chamado #${ticket.id} aberto. Nosso time vai acompanhar com cuidado.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSettingsMessage(_friendlySettingsError(error));
    }
  }

  Future<void> _openSupportLink(Uri? url, String fallbackMessage) async {
    if (url == null) {
      _showSettingsMessage(fallbackMessage);
      return;
    }
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showSettingsMessage(fallbackMessage);
    }
  }

  Future<_SupportTicketDialogResult?> _showSupportTicketDialog({
    required String subject,
  }) async {
    final subjectController = TextEditingController(text: subject);
    final messageController = TextEditingController();
    return showDialog<_SupportTicketDialogResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abrir chamado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: 'Assunto'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Como podemos ajudar?',
                alignLabelWithHint: true,
              ),
              minLines: 4,
              maxLines: 6,
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
              final normalizedSubject = subjectController.text.trim();
              final message = messageController.text.trim();
              if (normalizedSubject.isEmpty || message.isEmpty) {
                _showSettingsMessage(
                  'Informe o assunto e conte rápidamente como podemos ajudar.',
                );
                return;
              }
              Navigator.of(context).pop(
                _SupportTicketDialogResult(
                  subject: normalizedSubject,
                  message: message,
                ),
              );
            },
            child: const Text('Enviar chamado'),
          ),
        ],
      ),
    );
  }

  String _friendlySettingsError(Object error) {
    const fallback = 'Não foi possível concluir esta ação agora.';
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final details = data['details'];
        if (details is List && details.isNotEmpty) {
          final first = details.first.toString();
          return _isTechnicalMessage(first) ? fallback : first;
        }
        final message = data['message'];
        if (message != null) {
          final text = message.toString();
          return _isTechnicalMessage(text) ? fallback : text;
        }
      }
      if (error.message != null && error.message!.isNotEmpty) {
        return _isTechnicalMessage(error.message!) ? fallback : error.message!;
      }
    }
    return fallback;
  }

  bool _isTechnicalMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('dioexception') ||
        normalized.contains('forbidden') ||
        normalized.contains('stacktrace') ||
        normalized.contains('exception') ||
        normalized.contains('bad request') ||
        normalized.contains('401') ||
        normalized.contains('403') ||
        normalized.contains('500');
  }

  String? _cacheBustedAvatarUrl(String? url, int nonce) {
    if (url == null || url.isEmpty || nonce <= 0) {
      return url;
    }
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=$nonce';
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final settingsState = ref.watch(
      settingsPrivacyPreferencesControllerProvider,
    );
    final checkInReminderState = ref.watch(
      dailyCheckInReminderControllerProvider,
    );
    final localePreference =
        ref.watch(localeControllerProvider).value ?? LocalePreference.ptBr;
    final accessibilityState = ref.watch(
      accessibilityPreferencesControllerProvider,
    );
    final supportConfigState = ref.watch(supportConfigProvider);
    final supportStatusState = ref.watch(supportStatusProvider);
    final checkInState = ref.watch(checkInControllerProvider);
    final futureMessageState = ref.watch(futureMessageControllerProvider);
    final currentJourneyState = ref.watch(currentJourneyTrailProvider);
    final activeJourney = currentJourneyState.asData?.value;
    final journeyState = activeJourney == null
        ? null
        : ref.watch(trailJourneyProvider(activeJourney.id));
    final profile = profileState.asData?.value;
    final isSaving =
        _isSavingProfile || (profileState.isLoading && profileState.hasValue);
    final fallbackName =
        session?.displayName ?? session?.email.split('@').first ?? 'Seu perfil';

    _seedForm(profile, fallbackName);

    return _ProfilePreferencesLayout(
      hero: _ProfileHero(
        displayName: profile?.displayName ?? fallbackName,
        email: session?.email ?? 'você@evolua.app',
        avatarUrl: _cacheBustedAvatarUrl(
          profile?.avatarUrl ?? session?.avatarUrl,
          _avatarRefreshNonce,
        ),
        avatarPreviewBytes: _avatarPreviewBytes,
        isUploadingAvatar: _isUploadingAvatar,
        onRefresh: () => ref.read(profileControllerProvider.notifier).refresh(),
        onChangeAvatar: _pickAvatar,
      ),
      showHero: _section != ProfileModuleSection.evolutionMirror,
      selectedSection: _section,
      onSectionSelected: (section) => setState(() => _section = section),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_section == ProfileModuleSection.overview)
            _OverviewSection(
              formKey: _formKey,
              displayNameController: _displayNameController,
              birthDateController: _birthDateController,
              bioController: _bioController,
              customGenderController: _customGenderController,
              gender: _gender,
              birthDateError: _birthDateError,
              isSaving: isSaving,
              onGenderChanged: (value) => setState(() => _gender = value),
              onPickBirthDate: _pickBirthDate,
              onBirthDateChanged: _handleProfileBirthDateChanged,
              onSubmit: _saveProfile,
            )
          else if (_section == ProfileModuleSection.settingsPrivacy)
            settingsState.when(
              data: (preferences) {
                final settingsController = ref.read(
                  settingsPrivacyPreferencesControllerProvider.notifier,
                );
                return _SettingsPrivacySection(
                  email: session?.email ?? 'você@evolua.app',
                  privateJournal: preferences.privateJournal,
                  hideSocialCheckIns: preferences.hideSocialCheckIns,
                  allowHistoryInsights: preferences.allowHistoryInsights,
                  useEmotionalDataForAi: preferences.useEmotionalDataForAi,
                  contentPreferences: preferences.contentPreferences,
                  checkInReminder:
                      checkInReminderState.value ??
                      DailyCheckInReminderPreferences.defaults(),
                  aiTone: preferences.aiTone,
                  suggestionFrequency: preferences.suggestionFrequency,
                  trailStyle: preferences.trailStyle,
                  onPrivateJournalChanged: (value) =>
                      settingsController.updatePreferences(
                        (current) => current.copyWith(privateJournal: value),
                      ),
                  onHideSocialCheckInsChanged: (value) =>
                      settingsController.updatePreferences(
                        (current) =>
                            current.copyWith(hideSocialCheckIns: value),
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
                  onContentPreferencesChanged: (value) =>
                      settingsController.updatePreferences(
                        (current) =>
                            current.copyWith(contentPreferences: value),
                      ),
                  onCheckInReminderEnabledChanged:
                      _setDailyCheckInReminderEnabled,
                  onPickCheckInReminderTime: _pickDailyCheckInReminderTime,
                  onAiToneChanged: (value) =>
                      settingsController.updatePreferences(
                        (current) => current.copyWith(aiTone: value),
                      ),
                  onSuggestionFrequencyChanged: (value) =>
                      settingsController.updatePreferences(
                        (current) =>
                            current.copyWith(suggestionFrequency: value),
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
                      _deactivateAccount(session?.email ?? 'você@evolua.app'),
                  onDeleteAccount: () =>
                      _deleteAccount(session?.email ?? 'você@evolua.app'),
                  onInformationalAction: () => _showSettingsMessage(
                    'Esta informação será aberta em uma área dedicada em breve.',
                  ),
                  onOpenPrivacyPolicy: () =>
                      _openLegalLink(AppConfig.privacyPolicyUrl),
                  onOpenTermsOfUse: () =>
                      _openLegalLink(AppConfig.termsOfUseUrl),
                  localePreference: localePreference,
                  onLocalePreferenceChanged: (value) => ref
                      .read(localeControllerProvider.notifier)
                      .setPreference(value),
                );
              },
              loading: () =>
                  const PrimaryPanel(child: LinearProgressIndicator()),
              error: (_, _) => PrimaryPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configurações e privacidade',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Não foi possível carregar suas preferências agora.',
                    ),
                  ],
                ),
              ),
            )
          else if (_section == ProfileModuleSection.plansSubscriptions)
            const SubscriptionModuleView()
          else if (_section == ProfileModuleSection.helpSupport)
            _HelpSupportSection(
              configState: supportConfigState,
              statusState: supportStatusState,
              onCreateTicket: (category, subject) =>
                  _openSupportTicket(category: category, subject: subject),
              onOpenLink: _openSupportLink,
              onRefreshStatus: () => ref.invalidate(supportStatusProvider),
            )
          else if (_section == ProfileModuleSection.feedback)
            const _FeedbackSection()
          else if (_section == ProfileModuleSection.evolutionMirror)
            _EvolutionMirrorSection(
              checkInState: checkInState,
              futureMessageState: futureMessageState,
              currentJourneyState: currentJourneyState,
              journeyState: journeyState,
              onOpenFutureMessages: () => context.push('/future-messages'),
            )
          else if (_section == ProfileModuleSection.displayAccessibility)
            accessibilityState.when(
              data: (preferences) {
                final accessibilityController = ref.read(
                  accessibilityPreferencesControllerProvider.notifier,
                );
                return _DisplayAccessibilitySection(
                  preferences: preferences,
                  onThemeModeChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) => current.copyWith(themeMode: value),
                      ),
                  onHighContrastChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) => current.copyWith(highContrast: value),
                      ),
                  onReduceTransparencyChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) =>
                            current.copyWith(reduceTransparency: value),
                      ),
                  onAnimationLevelChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) => current.copyWith(animationLevel: value),
                      ),
                  onTextSizeChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) => current.copyWith(textSize: value),
                      ),
                  onReadingSpacingChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) => current.copyWith(readingSpacing: value),
                      ),
                  onAccessibleFontChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) => current.copyWith(accessibleFont: value),
                      ),
                  onFocusModeChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) => current.copyWith(focusMode: value),
                      ),
                  onReduceMotionChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) => current.copyWith(reduceMotion: value),
                      ),
                  onHapticFeedbackChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) => current.copyWith(hapticFeedback: value),
                      ),
                  onExtendedResponseTimeChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) =>
                            current.copyWith(extendedResponseTime: value),
                      ),
                  onSimplifiedNavigationChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) =>
                            current.copyWith(simplifiedNavigation: value),
                      ),
                  onReduceVisualStimuliChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) =>
                            current.copyWith(reduceVisualStimuli: value),
                      ),
                  onSofterLanguageChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) => current.copyWith(softerLanguage: value),
                      ),
                  onHideSensitiveContentChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) =>
                            current.copyWith(hideSensitiveContent: value),
                      ),
                  onComfortModeChanged: (value) =>
                      accessibilityController.updatePreferences(
                        (current) => current.copyWith(comfortMode: value),
                      ),
                  onSavePreferences: _saveAccessibilityPreferences,
                );
              },
              loading: () =>
                  const PrimaryPanel(child: LinearProgressIndicator()),
              error: (_, _) => PrimaryPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tela e acessibilidade',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Não foi possível carregar suas preferências visuais agora.',
                    ),
                  ],
                ),
              ),
            )
          else
            _SectionPanel(
              title: _sectionLabel(_section),
              subtitle: switch (_section) {
                ProfileModuleSection.settingsPrivacy =>
                  'Ajuste informações pessoais, dados da conta e o que fica visível para você nesta jornada.',
                ProfileModuleSection.helpSupport =>
                  'Use esta área como ponto de apoio para dúvidas, orientações e próximos passos de suporte.',
                ProfileModuleSection.displayAccessibility =>
                  'Centralize preferências de leitura, foco visual e conforto de uso nesta tela.',
                ProfileModuleSection.feedback =>
                  'Registre sugestões e percepções sobre a experiência do app sem sair do seu espaço.',
                ProfileModuleSection.plansSubscriptions =>
                  'Gerencie seu plano atual e as opcoes de assinatura.',
                ProfileModuleSection.evolutionMirror =>
                  'Acompanhe progresso, padrões e conquistas da sua jornada.',
                ProfileModuleSection.overview =>
                  'Visão geral do seu perfil e dos dados principais da sua conta.',
              },
            ),
          if (profileState.isLoading && !profileState.hasValue) ...[
            const SizedBox(height: 16),
            const FeedSkeleton(cards: 2),
          ],
        ],
      ),
    );
  }
}

class _ProfilePreferencesLayout extends StatelessWidget {
  const _ProfilePreferencesLayout({
    required this.hero,
    required this.showHero,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.content,
  });

  final Widget hero;
  final bool showHero;
  final ProfileModuleSection selectedSection;
  final ValueChanged<ProfileModuleSection> onSectionSelected;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final expanded = ResponsiveBreakpoints.isExpanded(context);

    if (expanded) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 288,
            child: PrimaryPanel(
              semanticLabel: 'Preferências do perfil',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHero) ...[hero, const SizedBox(height: 22)],
                  _ProfileSectionNavigation(
                    selectedSection: selectedSection,
                    onSectionSelected: onSectionSelected,
                    compact: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(child: content),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHero) ...[
          PrimaryPanel(semanticLabel: 'Resumo do perfil', child: hero),
          const SizedBox(height: 16),
        ],
        content,
      ],
    );
  }
}

class _ProfileSectionNavigation extends StatelessWidget {
  const _ProfileSectionNavigation({
    required this.selectedSection,
    required this.onSectionSelected,
    required this.compact,
  });

  final ProfileModuleSection selectedSection;
  final ValueChanged<ProfileModuleSection> onSectionSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preferências', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Escolha uma área para ajustar sua experiência no Evolua.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        for (final group in _profileSectionGroups) ...[
          Padding(
            padding: EdgeInsets.only(
              top: group == _profileSectionGroups.first ? 0 : 14,
              bottom: 8,
            ),
            child: Text(
              group.title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.evoluaColors.textSecondary,
              ),
            ),
          ),
          for (final section in group.sections)
            _ProfileSectionNavItem(
              meta: _profileSectionMeta(section),
              selected: selectedSection == section,
              compact: compact,
              onTap: () => onSectionSelected(section),
            ),
        ],
      ],
    );
  }
}

class _ProfileSectionNavItem extends StatelessWidget {
  const _ProfileSectionNavItem({
    required this.meta,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final _ProfileSectionMeta meta;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.evoluaColors;
    final backgroundColor = selected
        ? AppColors.accent.withValues(alpha: 0.16)
        : colors.surfaceStrong.withValues(alpha: 0.24);
    final borderColor = selected
        ? AppColors.accent.withValues(alpha: 0.48)
        : colors.outline.withValues(alpha: 0.14);
    final iconColor = selected ? AppColors.accent : colors.textSecondary;
    final titleColor = selected ? colors.textPrimary : colors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: meta.title,
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 14,
                vertical: compact ? 11 : 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(meta.icon, color: iconColor, size: compact ? 22 : 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: titleColor),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          meta.description,
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.accent,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionGroup {
  const _ProfileSectionGroup({required this.title, required this.sections});

  final String title;
  final List<ProfileModuleSection> sections;
}

class _ProfileSectionMeta {
  const _ProfileSectionMeta({
    required this.section,
    required this.icon,
    required this.title,
    required this.description,
  });

  final ProfileModuleSection section;
  final IconData icon;
  final String title;
  final String description;
}

const _profileSectionGroups = [
  _ProfileSectionGroup(
    title: 'Conta',
    sections: [
      ProfileModuleSection.overview,
      ProfileModuleSection.evolutionMirror,
      ProfileModuleSection.plansSubscriptions,
    ],
  ),
  _ProfileSectionGroup(
    title: 'Preferências',
    sections: [
      ProfileModuleSection.settingsPrivacy,
      ProfileModuleSection.displayAccessibility,
    ],
  ),
  _ProfileSectionGroup(
    title: 'Apoio',
    sections: [ProfileModuleSection.helpSupport, ProfileModuleSection.feedback],
  ),
];

_ProfileSectionMeta _profileSectionMeta(ProfileModuleSection section) {
  return switch (section) {
    ProfileModuleSection.overview => const _ProfileSectionMeta(
      section: ProfileModuleSection.overview,
      icon: Icons.person_rounded,
      title: 'Visão geral',
      description: 'Dados principais e identidade da conta.',
    ),
    ProfileModuleSection.plansSubscriptions => const _ProfileSectionMeta(
      section: ProfileModuleSection.plansSubscriptions,
      icon: Icons.workspace_premium_rounded,
      title: 'Planos e assinaturas',
      description: 'Plano atual, benefícios e upgrade.',
    ),
    ProfileModuleSection.evolutionMirror => const _ProfileSectionMeta(
      section: ProfileModuleSection.evolutionMirror,
      icon: Icons.auto_graph_rounded,
      title: 'Espelho da Evolução',
      description: 'Progresso, padrões, IA e conquistas.',
    ),
    ProfileModuleSection.settingsPrivacy => const _ProfileSectionMeta(
      section: ProfileModuleSection.settingsPrivacy,
      icon: Icons.shield_rounded,
      title: 'Configurações e privacidade',
      description: 'Conta, dados, segurança e preferências.',
    ),
    ProfileModuleSection.displayAccessibility => const _ProfileSectionMeta(
      section: ProfileModuleSection.displayAccessibility,
      icon: Icons.contrast_rounded,
      title: 'Tela e acessibilidade',
      description: 'Conforto visual, leitura e interação.',
    ),
    ProfileModuleSection.helpSupport => const _ProfileSectionMeta(
      section: ProfileModuleSection.helpSupport,
      icon: Icons.help_outline_rounded,
      title: 'Ajuda e suporte',
      description: 'Central de ajuda, chamados e status.',
    ),
    ProfileModuleSection.feedback => const _ProfileSectionMeta(
      section: ProfileModuleSection.feedback,
      icon: Icons.feedback_outlined,
      title: 'Dar feedback',
      description: 'Compartilhe percepções e sugestões.',
    ),
  };
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.avatarPreviewBytes,
    required this.isUploadingAvatar,
    required this.onRefresh,
    required this.onChangeAvatar,
  });

  final String displayName;
  final String email;
  final String? avatarUrl;
  final Uint8List? avatarPreviewBytes;
  final bool isUploadingAvatar;
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
              imageBytes: avatarPreviewBytes,
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
                onPressed: isUploadingAvatar ? null : onChangeAvatar,
                icon: isUploadingAvatar
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_back_rounded),
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
    required this.birthDateController,
    required this.bioController,
    required this.customGenderController,
    required this.gender,
    required this.birthDateError,
    required this.isSaving,
    required this.onGenderChanged,
    required this.onPickBirthDate,
    required this.onBirthDateChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController displayNameController;
  final TextEditingController birthDateController;
  final TextEditingController bioController;
  final TextEditingController customGenderController;
  final String gender;
  final String? birthDateError;
  final bool isSaving;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onPickBirthDate;
  final ValueChanged<String> onBirthDateChanged;
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
              'Visão geral',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Essas informações passam a sustentar seu perfil principal e a experiência personalizada no app.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: displayNameController,
              maxLength: maxDisplayNameLength,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
              validator: validateDisplayName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: birthDateController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: const [_ProfileBirthDateInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Data de nascimento',
                hintText: 'dd/mm/aaaa',
                prefixIcon: const Icon(Icons.cake_rounded),
                errorText: birthDateError,
                suffixIcon: IconButton(
                  tooltip: 'Abrir calendário',
                  onPressed: isSaving ? null : onPickBirthDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
              ),
              validator: (_) => birthDateError,
              onChanged: onBirthDateChanged,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(
                labelText: 'Gênero',
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
                  labelText: 'Como você se identifica',
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
                hintText: 'Conte um pouco sobre você.',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : onSubmit,
                icon: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Salvar perfil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBirthDateInputFormatter extends TextInputFormatter {
  const _ProfileBirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var index = 0; index < limited.length; index++) {
      if (index == 2 || index == 4) {
        buffer.write('/');
      }
      buffer.write(limited[index]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _EvolutionMirrorSection extends ConsumerWidget {
  const _EvolutionMirrorSection({
    required this.checkInState,
    required this.futureMessageState,
    required this.currentJourneyState,
    required this.journeyState,
    required this.onOpenFutureMessages,
  });

  final AsyncValue<CheckInHistoryState> checkInState;
  final AsyncValue<FutureMessageState> futureMessageState;
  final AsyncValue<Trail?> currentJourneyState;
  final AsyncValue<TrailJourney>? journeyState;
  final VoidCallback onOpenFutureMessages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = checkInState.asData?.value;
    final checkIns = history?.result.items ?? const <CheckIn>[];
    final totalCheckIns = history?.result.totalItems ?? checkIns.length;
    final latestInsight =
        history?.latestCreatedCheckIn?.aiInsight ??
        checkIns
            .where((item) => item.aiInsight != null)
            .map((item) => item.aiInsight!)
            .firstOrNull;
    final activeTrail = currentJourneyState.asData?.value;
    final journey = journeyState?.asData?.value;
    final futureMessages = futureMessageState.asData?.value;
    final shouldShowFutureMessages =
        futureMessages != null &&
        (futureMessages.readyToRead.isNotEmpty ||
            futureMessages.delivered.items.isNotEmpty);
    final stats = _EvolutionMirrorStats.from(
      checkIns: checkIns,
      totalCheckIns: totalCheckIns,
      activeTrail: activeTrail,
      journey: journey,
      latestInsight: latestInsight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EvolutionHero(stats: stats),
        const SizedBox(height: 16),
        _EvolutionSectionGroup(
          title: 'Resumo da semana',
          description:
              'Uma leitura curta para entender como seus registros recentes estao se organizando.',
          child: _EvolutionMetricGrid(
            metrics: [
              _EvolutionMetric(
                icon: Icons.favorite_rounded,
                label: 'Check-ins esta semana',
                value: '${stats.weeklyCheckIns}',
              ),
              _EvolutionMetric(
                icon: Icons.mood_rounded,
                label: 'Emocao predominante',
                value: stats.dominantMood,
              ),
              _EvolutionMetric(
                icon: Icons.bolt_rounded,
                label: 'Energia média',
                value: stats.averageEnergyLabel,
              ),
              _EvolutionMetric(
                icon: Icons.local_fire_department_rounded,
                label: 'Consistência',
                value: '${stats.streak} dias',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _EvolutionSectionGroup(
          title: 'Padroes percebidos',
          description:
              'Sinais simples do seu hist??rico, para perceber repeticoes sem transformar isso em cobranca.',
          child: _PatternPanel(stats: stats),
        ),
        const SizedBox(height: 16),
        _EvolutionSectionGroup(
          title: 'Mensagem da IA',
          description:
              'Uma leitura curta a partir do ??ltimo insight salvo, sem gerar nova an??lise.',
          child: _AiInsightMirrorPanel(insight: latestInsight, stats: stats),
        ),
        const SizedBox(height: 16),
        if (shouldShowFutureMessages) ...[
          _EvolutionSectionGroup(
            title: 'Mensagens do seu eu anterior',
            description:
                'Uma carta apareceu porque este momento tem contexto para ser revisitado.',
            child: _FutureMessagesMirrorPanel(
              state: futureMessageState,
              onOpen: onOpenFutureMessages,
            ),
          ),
          const SizedBox(height: 16),
        ],
        _EvolutionSectionGroup(
          title: 'Trilhas em andamento',
          description:
              'Acompanhe a trilha que est?? guiando seus pr??ximos passos.',
          child: _TrailEvolutionPanel(
            currentJourneyState: currentJourneyState,
            journeyState: journeyState,
          ),
        ),
        const SizedBox(height: 16),
        _EvolutionSectionGroup(
          title: 'Marcos da jornada',
          description:
              'Marcos leves para reconhecer movimento real, sem ranking nem pressa.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: stats.milestones
                .map((item) => _MilestoneBadge(milestone: item))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _EvolutionSectionGroup(
          title: 'Consist??ncia',
          description:
              'Uma leitura de continuidade para ajudar voc?? a voltar sem peso quando o ritmo oscilar.',
          child: _ConsistencyPanel(stats: stats),
        ),
      ],
    );
  }
}

class _EvolutionHero extends StatelessWidget {
  const _EvolutionHero({required this.stats});

  final _EvolutionMirrorStats stats;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: 'Espelho da Evolução',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Espelho da Evolução',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Como eu estou evoluindo?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            stats.weeklySummary,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.accent.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_graph_rounded, color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stats.primaryPattern,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.evoluaColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EvolutionSectionGroup extends StatelessWidget {
  const _EvolutionSectionGroup({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EvolutionMetric {
  const _EvolutionMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _EvolutionMetricGrid extends StatelessWidget {
  const _EvolutionMetricGrid({required this.metrics});

  final List<_EvolutionMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metrics
          .map(
            (metric) => SizedBox(
              width: 168,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: context.evoluaColors.surfaceStrong.withValues(
                    alpha: 0.28,
                  ),
                  border: Border.all(
                    color: context.evoluaColors.outline.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(metric.icon, color: AppColors.accent),
                    const SizedBox(height: 10),
                    Text(
                      metric.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.evoluaColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metric.label,
                      style: Theme.of(context).textTheme.bodySmall,
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

class _PatternPanel extends StatelessWidget {
  const _PatternPanel({required this.stats});

  final _EvolutionMirrorStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _EvolutionSignalRow(
          icon: Icons.auto_awesome_rounded,
          label: 'Principal padrão identificado',
          value: stats.patternLabel,
        ),
        _EvolutionSignalRow(
          icon: Icons.schedule_rounded,
          label: 'Melhor horário',
          value: stats.bestTimeWindow,
        ),
        _EvolutionSignalRow(
          icon: Icons.edit_note_rounded,
          label: 'Reflexões registradas',
          value: '${stats.reflectionCount}',
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.28),
            border: Border.all(
              color: context.evoluaColors.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            stats.patternDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EvolutionSignalRow extends StatelessWidget {
  const _EvolutionSignalRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.evoluaColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailEvolutionPanel extends StatelessWidget {
  const _TrailEvolutionPanel({
    required this.currentJourneyState,
    required this.journeyState,
  });

  final AsyncValue<Trail?> currentJourneyState;
  final AsyncValue<TrailJourney>? journeyState;

  @override
  Widget build(BuildContext context) {
    final trail = currentJourneyState.asData?.value;
    if (currentJourneyState.isLoading && trail == null) {
      return const LinearProgressIndicator();
    }
    if (trail == null) {
      return Text(
        'Quando uma trilha estiver ativa, ela aparece aqui como mapa de progresso.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final journey = journeyState?.asData?.value;
    final progress = (journey?.progressPercent ?? 0).clamp(0, 100);
    final nextStep = journey?.nextStep?.title ?? 'Retomar no seu ritmo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trail.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.evoluaColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(trail.summary, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: progress / 100),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _MiniStatusPill(label: '$progress% concluído'),
            if (journey != null)
              _MiniStatusPill(
                label:
                    '${journey.completedSteps}/${journey.steps.length} etapas',
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Próximo passo: $nextStep',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _AiInsightMirrorPanel extends StatelessWidget {
  const _AiInsightMirrorPanel({required this.insight, required this.stats});

  final CheckInAiInsight? insight;
  final _EvolutionMirrorStats stats;

  @override
  Widget build(BuildContext context) {
    if (insight == null) {
      return _AiMessageCard(
        message: stats.localAiFallback,
        nextStep: 'Faça um check-in simples hoje para criar a próxima leitura.',
      );
    }

    return _AiMessageCard(
      message: insight!.insight,
      nextStep: insight!.suggestedAction,
      footer: insight!.suggestedTrailTitle == null
          ? (insight!.fallbackUsed ? 'modo seguro' : insight!.riskLevel)
          : 'Trilha sugerida: ${insight!.suggestedTrailTitle}',
    );
  }
}

class _FutureMessagesMirrorPanel extends StatelessWidget {
  const _FutureMessagesMirrorPanel({required this.state, required this.onOpen});

  final AsyncValue<FutureMessageState> state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final data = state.asData?.value;
    final ready = data?.readyToRead ?? const <FutureMessage>[];
    final delivered = data?.delivered.items ?? const <FutureMessage>[];
    final scheduled =
        data?.result.items.where((item) => item.isScheduled).toList() ??
        const <FutureMessage>[];
    final highlight = ready.firstOrNull ?? delivered.firstOrNull;

    if (state.isLoading && data == null) {
      return const LinearProgressIndicator();
    }

    if (highlight == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quando uma carta encontrar um contexto importante, ela aparece aqui como uma ponte entre momentos da sua jornada.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Abrir mensagens'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FutureMessageTimelineCard(message: highlight),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _MiniStatusPill(
              label: '${ready.length} pronta${ready.length == 1 ? '' : 's'}',
            ),
            _MiniStatusPill(
              label:
                  '${scheduled.length} agendada${scheduled.length == 1 ? '' : 's'}',
            ),
            _MiniStatusPill(
              label:
                  '${delivered.length} entregue${delivered.length == 1 ? '' : 's'}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.mark_email_unread_rounded),
          label: Text(ready.isEmpty ? 'Abrir cartas' : 'Quero ler'),
        ),
      ],
    );
  }
}

class _FutureMessageTimelineCard extends StatelessWidget {
  const _FutureMessageTimelineCard({required this.message});

  final FutureMessage message;

  @override
  Widget build(BuildContext context) {
    final createdMood = message.createdContext['mood']?.toString();
    final deliveredMood = message.deliveredContext['mood']?.toString();
    final createdEnergy = message.createdContext['energyLevel']?.toString();
    final deliveredEnergy = message.deliveredContext['energyLevel']?.toString();
    final statusLabel = message.isRead
        ? 'Você ja leu essa carta.'
        : message.isDelivered
        ? 'Há uma carta sua pronta para ser lida com calma.'
        : 'Essa carta ainda está guardada.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.34),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.title ?? 'Carta para mim mesmo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(statusLabel, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          _EvolutionSignalRow(
            icon: Icons.history_rounded,
            label: 'Quando escreveu',
            value: _contextLabel(createdMood, createdEnergy),
          ),
          _EvolutionSignalRow(
            icon: Icons.today_rounded,
            label: message.isDelivered ? 'Quando chegou' : 'Entrega',
            value: message.isDelivered
                ? _contextLabel(deliveredMood, deliveredEnergy)
                : message.triggerLabel,
          ),
          Text(
            message.bodyPreview.isEmpty
                ? message.triggerLabel
                : message.bodyPreview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _contextLabel(String? mood, String? energy) {
    final cleanMood = mood == null || mood.isEmpty
        ? 'contexto registrado'
        : mood;
    if (energy == null || energy.isEmpty) {
      return cleanMood;
    }
    return '$cleanMood, energia $energy';
  }
}

class _AiMessageCard extends StatelessWidget {
  const _AiMessageCard({
    required this.message,
    required this.nextStep,
    this.footer,
  });

  final String message;
  final String nextStep;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.34),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.task_alt_rounded,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Próximo passo: $nextStep',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            Text(
              footer!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.evoluaColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MilestoneBadge extends StatelessWidget {
  const _MilestoneBadge({required this.milestone});

  final _EvolutionMilestone milestone;

  @override
  Widget build(BuildContext context) {
    final color = milestone.achieved
        ? AppColors.accent
        : context.evoluaColors.textSecondary;
    return Container(
      constraints: const BoxConstraints(maxWidth: 270),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: milestone.achieved ? 0.14 : 0.08),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            milestone.achieved
                ? Icons.emoji_events_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              milestone.label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.evoluaColors.textPrimary,
                fontWeight: milestone.achieved
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.accent.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.evoluaColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConsistencyPanel extends StatelessWidget {
  const _ConsistencyPanel({required this.stats});

  final _EvolutionMirrorStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            7,
            (index) => Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stats.weeklyActivity[index]
                    ? AppColors.accent
                    : context.evoluaColors.surfaceStrong.withValues(
                        alpha: 0.36,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          stats.consistencyMessage,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _EvolutionMirrorStats {
  const _EvolutionMirrorStats({
    required this.weeklyCheckIns,
    required this.streak,
    required this.dominantMood,
    required this.averageEnergyLabel,
    required this.bestTimeWindow,
    required this.reflectionCount,
    required this.primaryPattern,
    required this.patternLabel,
    required this.patternDescription,
    required this.patternIdentified,
    required this.weeklySummary,
    required this.localAiFallback,
    required this.consistencyMessage,
    required this.weeklyActivity,
    required this.milestones,
  });

  final int weeklyCheckIns;
  final int streak;
  final String dominantMood;
  final String averageEnergyLabel;
  final String bestTimeWindow;
  final int reflectionCount;
  final String primaryPattern;
  final String patternLabel;
  final String patternDescription;
  final bool patternIdentified;
  final String weeklySummary;
  final String localAiFallback;
  final String consistencyMessage;
  final List<bool> weeklyActivity;
  final List<_EvolutionMilestone> milestones;

  factory _EvolutionMirrorStats.from({
    required List<CheckIn> checkIns,
    required int totalCheckIns,
    required Trail? activeTrail,
    required TrailJourney? journey,
    required CheckInAiInsight? latestInsight,
  }) {
    final weeklyCheckIns = _mirrorWeeklyCheckIns(checkIns);
    final streak = _mirrorStreak(checkIns);
    final weeklyActivity = _mirrorWeeklyActivity(checkIns);
    final reflectionCount = checkIns
        .where((item) => item.reflection.trim().isNotEmpty)
        .length;
    final averageEnergy = checkIns.isEmpty
        ? null
        : checkIns.fold<int>(0, (sum, item) => sum + item.energyLevel) /
              checkIns.length;
    final dominantMood = checkIns.isEmpty
        ? 'sem padrão ainda'
        : _mirrorCapitalize(_mirrorDominantMood(checkIns));
    final pattern = _mirrorPrimaryPattern(checkIns);
    final milestones = [
      _EvolutionMilestone(
        label: '3 dias de check-in',
        achieved: _mirrorUniqueDays(checkIns) >= 3,
      ),
      _EvolutionMilestone(
        label: 'Primeira trilha concluída',
        achieved: (journey?.progressPercent ?? 0) >= 100,
      ),
      _EvolutionMilestone(
        label: '7 reflexões registradas',
        achieved: reflectionCount >= 7,
      ),
      _EvolutionMilestone(
        label: '1 padrão emocional identificado',
        achieved: pattern.identified,
      ),
      _EvolutionMilestone(
        label: 'Primeiro check-in',
        achieved: totalCheckIns > 0,
      ),
    ];

    return _EvolutionMirrorStats(
      weeklyCheckIns: weeklyCheckIns,
      streak: streak,
      dominantMood: dominantMood,
      averageEnergyLabel: averageEnergy == null
          ? 'sem dados'
          : '${averageEnergy.toStringAsFixed(1)}/10',
      bestTimeWindow: _mirrorBestTimeWindow(checkIns),
      reflectionCount: reflectionCount,
      primaryPattern: pattern.headline,
      patternLabel: pattern.label,
      patternDescription: pattern.description,
      patternIdentified: pattern.identified,
      weeklySummary: _mirrorWeeklySummary(
        weeklyCheckIns: weeklyCheckIns,
        dominantMood: dominantMood,
        averageEnergy: averageEnergy,
        activeTrail: activeTrail,
      ),
      localAiFallback: _mirrorLocalAiFallback(checkIns),
      consistencyMessage: weeklyCheckIns == 0
          ? 'Seu espelho ainda está se formando. Um check-in curto já cria o primeiro ponto de referência.'
          : 'Você registrou $weeklyCheckIns momento(s) nesta semana. A constância aqui é voltar com honestidade, não fazer tudo perfeito.',
      weeklyActivity: weeklyActivity,
      milestones: milestones,
    );
  }
}

class _EvolutionMilestone {
  const _EvolutionMilestone({required this.label, required this.achieved});

  final String label;
  final bool achieved;
}

class _MirrorPattern {
  const _MirrorPattern({
    required this.label,
    required this.headline,
    required this.description,
    required this.identified,
  });

  final String label;
  final String headline;
  final String description;
  final bool identified;
}

String _mirrorDominantMood(List<CheckIn> items) {
  final counts = <String, int>{};
  for (final item in items) {
    counts[item.mood] = (counts[item.mood] ?? 0) + 1;
  }
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

int _mirrorUniqueDays(List<CheckIn> items) {
  return items
      .map(
        (item) => DateTime(
          item.createdAt.year,
          item.createdAt.month,
          item.createdAt.day,
        ),
      )
      .toSet()
      .length;
}

int _mirrorWeeklyCheckIns(List<CheckIn> items) {
  final now = DateTime.now();
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 6));
  return items.where((item) => !item.createdAt.isBefore(start)).length;
}

List<bool> _mirrorWeeklyActivity(List<CheckIn> items) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = items
      .map(
        (item) => DateTime(
          item.createdAt.year,
          item.createdAt.month,
          item.createdAt.day,
        ),
      )
      .toSet();
  return List.generate(7, (index) {
    final day = today.subtract(Duration(days: 6 - index));
    return days.contains(day);
  });
}

int _mirrorStreak(List<CheckIn> items) {
  if (items.isEmpty) {
    return 0;
  }
  final days = items
      .map(
        (item) => DateTime(
          item.createdAt.year,
          item.createdAt.month,
          item.createdAt.day,
        ),
      )
      .toSet();
  final today = DateTime.now();
  final base = DateTime(today.year, today.month, today.day);
  var streak = 0;
  for (var offset = 0; offset < 60; offset++) {
    if (!days.contains(base.subtract(Duration(days: offset)))) {
      break;
    }
    streak++;
  }
  return streak;
}

String _mirrorBestTimeWindow(List<CheckIn> items) {
  if (items.isEmpty) {
    return 'sem dados';
  }
  final averageHour =
      items.fold<int>(0, (sum, item) => sum + item.createdAt.hour) /
      items.length;
  if (averageHour < 12) {
    return 'manha';
  }
  if (averageHour < 18) {
    return 'tarde';
  }
  return 'noite';
}

_MirrorPattern _mirrorPrimaryPattern(List<CheckIn> items) {
  if (items.length < 2) {
    return const _MirrorPattern(
      label: 'em formação',
      headline:
          'Seu espelho ainda está reunindo pontos suficientes para mostrar um padrão confiável.',
      description:
          'Com mais alguns check-ins, o Evolua consegue perceber horarios, energia e emocoes recorrentes com mais clareza.',
      identified: false,
    );
  }

  final nightAnxiety = items
      .where(
        (item) =>
            item.mood.toLowerCase().contains('ansi') &&
            item.createdAt.hour >= 18,
      )
      .length;
  if (nightAnxiety >= 2) {
    return const _MirrorPattern(
      label: 'ansiedade a noite',
      headline: 'Você tende a registrar mais ansiedade à noite.',
      description:
          'Esse pode ser um bom horario para reduzir estímulos, fazer uma pausa curta e escolher uma ação simples antes de dormir.',
      identified: true,
    );
  }

  final morning = items.where((item) => item.createdAt.hour < 12).toList();
  final later = items.where((item) => item.createdAt.hour >= 12).toList();
  final morningAverage = _mirrorAverageEnergy(morning);
  final laterAverage = _mirrorAverageEnergy(later);
  if (morning.length >= 2 &&
      morningAverage != null &&
      (laterAverage == null || morningAverage >= laterAverage + 0.5)) {
    return const _MirrorPattern(
      label: 'manhã fortalece',
      headline: 'Seus melhores dias aparecem quando faz check-in pela manha.',
      description:
          'Registrar cedo parece te ajudar a nomear o momento antes que o dia acelere. Vale manter esse ritual leve.',
      identified: true,
    );
  }

  final distinctMoods = items.map((item) => item.mood.toLowerCase()).toSet();
  if (distinctMoods.length >= 3) {
    return const _MirrorPattern(
      label: 'nomeação emocional',
      headline: 'Você evoluiu na capacidade de nomear emocoes.',
      description:
          'Seu histórico mostra mais nuances emocionais. Isso e sinal de percepcao crescendo, não de instabilidade.',
      identified: true,
    );
  }

  return const _MirrorPattern(
    label: 'constância em construção',
    headline: 'Um padrão emocional já começa a se formar.',
    description:
        'Continue registrando com honestidade. A leitura fica mais precisa quando o histórico ganha ritmo.',
    identified: true,
  );
}

double? _mirrorAverageEnergy(List<CheckIn> items) {
  if (items.isEmpty) {
    return null;
  }
  return items.fold<int>(0, (sum, item) => sum + item.energyLevel) /
      items.length;
}

String _mirrorWeeklySummary({
  required int weeklyCheckIns,
  required String dominantMood,
  required double? averageEnergy,
  required Trail? activeTrail,
}) {
  if (weeklyCheckIns == 0) {
    return 'Esta tela vai ganhar vida conforme você registra seus check-ins, reflexoes e passos nas trilhas.';
  }
  final energy = averageEnergy == null
      ? 'energia ainda em leitura'
      : 'energia média ${averageEnergy.toStringAsFixed(1)}/10';
  final trailText = activeTrail == null
      ? 'sem uma trilha ativa neste momento'
      : 'com a trilha ${activeTrail.title} em movimento';
  return 'Nesta semana, seu estado mais presente foi $dominantMood, com $energy, $trailText.';
}

String _mirrorLocalAiFallback(List<CheckIn> items) {
  if (items.isEmpty) {
    return 'Ainda não ha histórico suficiente para uma mensagem personalizada, mas o primeiro check-in ja cria um ponto de partida.';
  }
  final mood = _mirrorCapitalize(_mirrorDominantMood(items));
  return 'Seu histórico recente aponta para $mood. Um próximo passo simples e escolher uma pratica curta e observar como sua energia responde.';
}

String _mirrorCapitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}

class _FeedbackSection extends ConsumerStatefulWidget {
  const _FeedbackSection();

  @override
  ConsumerState<_FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends ConsumerState<_FeedbackSection> {
  final _workingWellController = TextEditingController();
  final _couldImproveController = TextEditingController();
  final _confusingOrHardController = TextEditingController();
  final _helpedHowController = TextEditingController();
  final _featureSuggestionController = TextEditingController();
  final _contentSuggestionController = TextEditingController();
  final _visualSuggestionController = TextEditingController();
  final _aiSuggestionController = TextEditingController();
  final _problemWhatHappenedController = TextEditingController();
  final _problemWhereController = TextEditingController();
  final _problemCanRepeatController = TextEditingController();
  final _ratingCommentController = TextEditingController();
  final _picker = ImagePicker();
  String? _rating;
  String? _screenshotFileName;
  Uint8List? _screenshotBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _workingWellController.dispose();
    _couldImproveController.dispose();
    _confusingOrHardController.dispose();
    _helpedHowController.dispose();
    _featureSuggestionController.dispose();
    _contentSuggestionController.dispose();
    _visualSuggestionController.dispose();
    _aiSuggestionController.dispose();
    _problemWhatHappenedController.dispose();
    _problemWhereController.dispose();
    _problemCanRepeatController.dispose();
    _ratingCommentController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
    );
    if (image == null) {
      return;
    }
    final bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _screenshotFileName = image.name;
      _screenshotBytes = bytes;
    });
  }

  Future<void> _submit() async {
    final draft = _draft();
    if (!draft.hasMeaningfulContent) {
      _showMessage('Conte pelo menos uma percepcao ou escolha uma avaliação.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await ref.read(feedbackRepositoryProvider).submit(draft);
      if (!mounted) {
        return;
      }
      _clear();
      _showMessage(
        'Feedback #${result.id} enviado. Obrigado por construir o Evolua com a gente.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyFeedbackError(error));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  FeedbackSubmissionDraft _draft() {
    return FeedbackSubmissionDraft(
      workingWell: _workingWellController.text,
      couldImprove: _couldImproveController.text,
      confusingOrHard: _confusingOrHardController.text,
      helpedHow: _helpedHowController.text,
      featureSuggestion: _featureSuggestionController.text,
      contentSuggestion: _contentSuggestionController.text,
      visualSuggestion: _visualSuggestionController.text,
      aiSuggestion: _aiSuggestionController.text,
      problemWhatHappened: _problemWhatHappenedController.text,
      problemWhere: _problemWhereController.text,
      problemCanRepeat: _problemCanRepeatController.text,
      rating: _rating,
      ratingComment: _ratingCommentController.text,
      screenshotBytes: _screenshotBytes,
      screenshotFileName: _screenshotFileName,
    );
  }

  void _clear() {
    for (final controller in [
      _workingWellController,
      _couldImproveController,
      _confusingOrHardController,
      _helpedHowController,
      _featureSuggestionController,
      _contentSuggestionController,
      _visualSuggestionController,
      _aiSuggestionController,
      _problemWhatHappenedController,
      _problemWhereController,
      _problemCanRepeatController,
      _ratingCommentController,
    ]) {
      controller.clear();
    }
    setState(() {
      _rating = null;
      _screenshotFileName = null;
      _screenshotBytes = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyFeedbackError(Object error) {
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
    return 'Não foi possível enviar seu feedback agora.';
  }

  @override
  Widget build(BuildContext context) {
    final feedbackFields = [
      _FeedbackTextField(
        controller: _workingWellController,
        label: 'O que está funcionando bem?',
      ),
      _FeedbackTextField(
        controller: _couldImproveController,
        label: 'O que poderia melhorar?',
      ),
      _FeedbackTextField(
        controller: _confusingOrHardController,
        label: 'Algo parece confuso ou dificil?',
      ),
      _FeedbackTextField(
        controller: _helpedHowController,
        label: 'Como o Evolua tem ajudado você?',
      ),
    ];
    final suggestionFields = [
      _FeedbackTextField(
        controller: _featureSuggestionController,
        label: 'Sugestao de funcionalidade',
      ),
      _FeedbackTextField(
        controller: _contentSuggestionController,
        label: 'Sugestao de conteúdo',
      ),
      _FeedbackTextField(
        controller: _visualSuggestionController,
        label: 'Sugestao de melhoria visual',
      ),
      _FeedbackTextField(
        controller: _aiSuggestionController,
        label: 'Sugestao para IA',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dar feedback',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'O Evolua está em constante evolução. Sua percepção ajuda a construir uma experiência melhor para todos.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Compartilhe sua experiência',
          description: 'Conte como tem sido usar o Evolua no seu dia a dia.',
          microcopy:
              'Sua percepcao mostra onde o app ja apoia bem e onde ainda pode cuidar melhor.',
          children: feedbackFields,
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Sugerir melhoria',
          description: 'Tem uma ideia? Queremos ouvir.',
          microcopy:
              'Boas ideias podem nascer do uso real, no detalhe pequeno do cotidiano.',
          children: suggestionFields,
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Reportar problema',
          description: 'Encontrou algo que não está funcionando como deveria?',
          microcopy:
              'Relatos claros ajudam nosso time a corrigir com mais rapidez e cuidado.',
          children: [
            _FeedbackTextField(
              controller: _problemWhatHappenedController,
              label: 'O que aconteceu?',
            ),
            _FeedbackTextField(
              controller: _problemWhereController,
              label: 'Onde aconteceu?',
            ),
            _FeedbackTextField(
              controller: _problemCanRepeatController,
              label: 'Consegue repetir o problema?',
            ),
            _ScreenshotPickerRow(
              fileName: _screenshotFileName,
              onPick: _pickScreenshot,
              onRemove: () => setState(() {
                _screenshotFileName = null;
                _screenshotBytes = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Avaliação rápida',
          description: 'Como tem sido sua experiência no Evolua?',
          microcopy:
              'Cada feedback ajuda o Evolua a evoluir com mais intencao, clareza e cuidado.',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  const {
                    'MUITO_BOA': 'Muito boa',
                    'BOA': 'Boa',
                    'NEUTRA': 'Neutra',
                    'RUIM': 'Ruim',
                    'MUITO_RUIM': 'Muito ruim',
                  }.entries.map((entry) {
                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: _rating == entry.key,
                      onSelected: (_) => setState(() => _rating = entry.key),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 12),
            _FeedbackTextField(
              controller: _ratingCommentController,
              label: 'Quer contar um pouco mais?',
              minLines: 3,
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryPanel(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isSubmitting ? 'Enviando...' : 'Enviar feedback'),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackTextField extends StatelessWidget {
  const _FeedbackTextField({
    required this.controller,
    required this.label,
    this.minLines = 2,
  });

  final TextEditingController controller;
  final String label;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: 5,
        maxLength: 1200,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          counterText: '',
        ),
      ),
    );
  }
}

class _ScreenshotPickerRow extends StatelessWidget {
  const _ScreenshotPickerRow({
    required this.fileName,
    required this.onPick,
    required this.onRemove,
  });

  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      icon: Icons.image_outlined,
      title: 'Enviar captura de tela',
      subtitle: fileName == null
          ? 'Opcional, útil quando algo visual não está funcionando.'
          : fileName!,
      trailing: fileName == null
          ? TextButton(onPressed: onPick, child: const Text('Anexar'))
          : IconButton(
              tooltip: 'Remover captura',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
    );
  }
}

class _HelpSupportSection extends StatelessWidget {
  const _HelpSupportSection({
    required this.configState,
    required this.statusState,
    required this.onCreateTicket,
    required this.onOpenLink,
    required this.onRefreshStatus,
  });

  final AsyncValue<SupportConfig> configState;
  final AsyncValue<List<SupportStatusItem>> statusState;
  final void Function(String category, String subject) onCreateTicket;
  final Future<void> Function(Uri? url, String fallbackMessage) onOpenLink;
  final VoidCallback onRefreshStatus;

  @override
  Widget build(BuildContext context) {
    final config = configState.asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajuda e suporte',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Se algo não estiver claro, funcionando ou fazendo sentido, estamos aqui para ajudar.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Central de ajuda',
          description:
              'Encontre respostas rápidas para duvidas comuns sobre o Evolua.',
          microcopy:
              'Respostas simples ajudam você a seguir sem precisar pausar a jornada por muito tempo.',
          children: [
            const _HelpFaqTile(
              title: 'Como funcionam as trilhas?',
              answer:
                  'As trilhas organizam praticas, reflexoes e próximos passos em uma sequencia privada para apoiar seu momento atual.',
            ),
            const _HelpFaqTile(
              title: 'O que são check-ins?',
              answer:
                  'Check-ins são registros rápidos do seu estado emocional. Eles ajudam o Evolua a entender seu ritmo e sugerir um cuidado mais coerente.',
            ),
            const _HelpFaqTile(
              title: 'Como a IA gera sugestões?',
              answer:
                  'A IA usa seu check-in e, quando permitido, seu histórico para criar orientacoes de autocuidado. Ela não substitui apoio profissional.',
            ),
            const _HelpFaqTile(
              title: 'Como editar meu perfil?',
              answer:
                  'Abra seu perfil, fique em Visão geral, ajuste os dados desejados e toque em Salvar perfil.',
            ),
            const _HelpFaqTile(
              title: 'Como funciona o plano premium?',
              answer:
                  'O Premium amplia limites e recursos da jornada. Você pode ver detalhes em Planos e assinaturas no menu do perfil.',
            ),
            _SettingsActionRow(
              icon: Icons.open_in_new_rounded,
              title: 'Abrir central de ajuda',
              subtitle: 'Acesse materiais externos quando configurados.',
              onTap: () => onOpenLink(
                config?.helpCenterUrl,
                'A central completa ainda não está configurada. Use as respostas desta página por enquanto.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Suporte humano',
          description:
              'Precisa de ajuda com algo mais especifico? Fale com nosso time.',
          microcopy:
              'Nem tudo precisa ser resolvido sozinho. Quando precisar, estamos aqui.',
          children: [
            _SettingsActionRow(
              icon: Icons.support_agent_rounded,
              title: 'Abrir chamado',
              subtitle: 'Conte o que aconteceu para nosso time acompanhar.',
              onTap: () => onCreateTicket('GENERAL', 'Ajuda com o Evolua'),
            ),
            _SettingsActionRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Falar com suporte',
              subtitle: 'Abra uma conversa registrada com nosso time.',
              onTap: () => onCreateTicket('SUPPORT', 'Falar com suporte'),
            ),
            _SettingsActionRow(
              icon: Icons.bug_report_outlined,
              title: 'Reportar problema tecnico',
              subtitle:
                  'Informe erros, travamentos ou comportamentos estranhos.',
              onTap: () =>
                  onCreateTicket('TECHNICAL', 'Problema tecnico no app'),
            ),
            _SettingsActionRow(
              icon: Icons.workspace_premium_outlined,
              title: 'Solicitar ajuda com assinatura',
              subtitle: 'Receba apoio sobre plano, pagamento ou premium.',
              onTap: () => onCreateTicket('BILLING', 'Ajuda com assinatura'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Bem-estar e suporte emocional',
          description:
              'O Evolua apoia processos de autoconhecimento, mas não substitui acompanhamento profissional.',
          microcopy:
              'O Evolua pode apoiar sua jornada, mas cuidado emocional profundo também merece apoio humano qualificado.',
          children: [
            _SettingsActionRow(
              icon: Icons.health_and_safety_outlined,
              title: 'Quando buscar ajuda profissional',
              subtitle:
                  'Veja orientacoes configuradas para momentos que pedem apoio humano.',
              onTap: () => onOpenLink(
                config?.professionalHelpUrl,
                'Esse recurso de apoio profissional ainda não está configurado.',
              ),
            ),
            _SettingsActionRow(
              icon: Icons.volunteer_activism_outlined,
              title: 'Recursos de apoio emocional',
              subtitle: 'Acesse uma fonte segura configurada pelo Evolua.',
              onTap: () => onOpenLink(
                config?.emotionalResourcesUrl,
                'Os recursos de apoio emocional ainda não estao configurados.',
              ),
            ),
            _SettingsActionRow(
              icon: Icons.psychology_alt_outlined,
              title: 'Limites da IA no cuidado emocional',
              subtitle:
                  'Entenda onde a IA ajuda e onde o apoio humano importa.',
              onTap: () => onOpenLink(
                config?.aiLimitsUrl,
                'A página sobre limites da IA ainda não está configurada.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Status da plataforma',
          description: 'Acompanhe a estabilidade e funcionamento do Evolua.',
          microcopy:
              'Quando algo oscilar, mostramos de forma clara para você não precisar adivinhar.',
          children: [
            statusState.when(
              data: (items) =>
                  Column(children: items.map(_SupportStatusRow.new).toList()),
              loading: () => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => const _SettingsInfoRow(
                icon: Icons.info_outline_rounded,
                title: 'Status indisponível',
                subtitle: 'Não foi possível confirmar a plataforma agora.',
              ),
            ),
            _SettingsActionRow(
              icon: Icons.refresh_rounded,
              title: 'Atualizar status',
              subtitle: 'Verifique novamente os servicos do Evolua.',
              onTap: onRefreshStatus,
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryPanel(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => onCreateTicket('SUPPORT', 'Falar com suporte'),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Falar com suporte'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenLink(
                  config?.helpCenterUrl,
                  'A central completa ainda não está configurada. Use as respostas desta página por enquanto.',
                ),
                icon: const Icon(Icons.help_outline_rounded),
                label: const Text('Abrir central de ajuda'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpFaqTile extends StatelessWidget {
  const _HelpFaqTile({required this.title, required this.answer});

  final String title;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const Icon(Icons.help_outline_rounded),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(answer, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportStatusRow extends StatelessWidget {
  const _SupportStatusRow(this.item);

  final SupportStatusItem item;

  @override
  Widget build(BuildContext context) {
    final operational = item.state == 'OPERATIONAL';
    return _SettingsRowShell(
      icon: operational
          ? Icons.check_circle_outline_rounded
          : Icons.help_outline_rounded,
      iconColor: operational
          ? AppColors.accent
          : context.evoluaColors.textSecondary,
      title: item.label,
      subtitle: item.detail,
      trailing: Text(
        operational ? 'OK' : 'A confirmar',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: operational
              ? AppColors.accent
              : context.evoluaColors.textSecondary,
        ),
      ),
    );
  }
}

class _DisplayAccessibilitySection extends StatelessWidget {
  const _DisplayAccessibilitySection({
    required this.preferences,
    required this.onThemeModeChanged,
    required this.onHighContrastChanged,
    required this.onReduceTransparencyChanged,
    required this.onAnimationLevelChanged,
    required this.onTextSizeChanged,
    required this.onReadingSpacingChanged,
    required this.onAccessibleFontChanged,
    required this.onFocusModeChanged,
    required this.onReduceMotionChanged,
    required this.onHapticFeedbackChanged,
    required this.onExtendedResponseTimeChanged,
    required this.onSimplifiedNavigationChanged,
    required this.onReduceVisualStimuliChanged,
    required this.onSofterLanguageChanged,
    required this.onHideSensitiveContentChanged,
    required this.onComfortModeChanged,
    required this.onSavePreferences,
  });

  final AccessibilityPreferences preferences;
  final ValueChanged<String> onThemeModeChanged;
  final ValueChanged<bool> onHighContrastChanged;
  final ValueChanged<bool> onReduceTransparencyChanged;
  final ValueChanged<String> onAnimationLevelChanged;
  final ValueChanged<String> onTextSizeChanged;
  final ValueChanged<String> onReadingSpacingChanged;
  final ValueChanged<bool> onAccessibleFontChanged;
  final ValueChanged<bool> onFocusModeChanged;
  final ValueChanged<bool> onReduceMotionChanged;
  final ValueChanged<bool> onHapticFeedbackChanged;
  final ValueChanged<bool> onExtendedResponseTimeChanged;
  final ValueChanged<bool> onSimplifiedNavigationChanged;
  final ValueChanged<bool> onReduceVisualStimuliChanged;
  final ValueChanged<bool> onSofterLanguageChanged;
  final ValueChanged<bool> onHideSensitiveContentChanged;
  final ValueChanged<bool> onComfortModeChanged;
  final VoidCallback onSavePreferences;

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
                'Tela e acessibilidade',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Ajuste a interface para uma experiência mais confortável, acessível e alinhada ao seu ritmo.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Aparência',
          description:
              'Adapte a interface ao seu ambiente e preferência visual.',
          microcopy: 'Conforto visual também faz parte do cuidado.',
          children: [
            _AccessibilitySegmentedRow(
              title: 'Tema',
              subtitle: 'Escolha entre escuro, claro ou automático.',
              value: preferences.themeMode,
              options: const {
                'dark': 'Escuro',
                'light': 'Claro',
                'system': 'Auto',
              },
              onChanged: onThemeModeChanged,
            ),
            _SettingsSwitchRow(
              title: 'Contraste elevado',
              subtitle: 'Aumenta a diferença entre texto, fundo e bordas.',
              value: preferences.highContrast,
              onChanged: onHighContrastChanged,
            ),
            _SettingsSwitchRow(
              title: 'Redução de transparência',
              subtitle:
                  'Prefere superfícies mais sólidas e menos translúcidas.',
              value: preferences.reduceTransparency,
              onChanged: onReduceTransparencyChanged,
            ),
            _SettingsDropdownRow(
              title: 'Ajuste de animações',
              subtitle: 'Controle a intensidade das transições.',
              value: preferences.animationLevel,
              items: const {
                'normal': 'Normal',
                'reduced': 'Reduzida',
                'none': 'Sem animações',
              },
              onChanged: onAnimationLevelChanged,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Leitura e legibilidade',
          description: 'Melhore a leitura e reduza o esforço visual.',
          microcopy:
              'Uma interface mais confortável torna a experiência mais leve e presente.',
          children: [
            _SettingsDropdownRow(
              title: 'Tamanho do texto',
              subtitle: 'Ajuste a escala dos textos no app.',
              value: preferences.textSize,
              items: const {
                'small': 'Pequeno',
                'normal': 'Normal',
                'large': 'Grande',
                'extraLarge': 'Extra grande',
              },
              onChanged: onTextSizeChanged,
            ),
            _SettingsDropdownRow(
              title: 'Espaçamento de leitura',
              subtitle: 'Defina o respiro entre as linhas.',
              value: preferences.readingSpacing,
              items: const {
                'compact': 'Compacto',
                'comfortable': 'Confortável',
                'wide': 'Amplo',
              },
              onChanged: onReadingSpacingChanged,
            ),
            _SettingsSwitchRow(
              title: 'Fonte acessível',
              subtitle: 'Usa a fonte do sistema para leitura mais familiar.',
              value: preferences.accessibleFont,
              onChanged: onAccessibleFontChanged,
            ),
            _SettingsSwitchRow(
              title: 'Modo foco',
              subtitle:
                  'Reduz distrações visuais e deixa a interface mais limpa e calma.',
              value: preferences.focusMode,
              onChanged: onFocusModeChanged,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Navegação e interação',
          description: 'Ajuste como você interage com o app.',
          microcopy:
              'Pequenos ajustes tornam a experiência mais fluida e menos cansativa.',
          children: [
            _SettingsSwitchRow(
              title: 'Reduzir movimento',
              subtitle: 'Diminui transições e efeitos animados no app.',
              value: preferences.reduceMotion,
              onChanged: onReduceMotionChanged,
            ),
            _SettingsSwitchRow(
              title: 'Feedback tátil',
              subtitle: 'Permite respostas táteis em ações importantes.',
              value: preferences.hapticFeedback,
              onChanged: onHapticFeedbackChanged,
            ),
            _SettingsSwitchRow(
              title: 'Tempo de resposta estendido',
              subtitle:
                  'Oferece mais tempo para concluir interações importantes.',
              value: preferences.extendedResponseTime,
              onChanged: onExtendedResponseTimeChanged,
            ),
            _SettingsSwitchRow(
              title: 'Navegação simplificada',
              subtitle: 'Prioriza caminhos mais diretos quando disponível.',
              value: preferences.simplifiedNavigation,
              onChanged: onSimplifiedNavigationChanged,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Acessibilidade emocional',
          description:
              'Ajuste estímulos e linguagem para uma experiência mais segura emocionalmente.',
          microcopy:
              'Seu estado emocional importa. A interface também pode respeitar isso.',
          children: [
            _SettingsSwitchRow(
              title: 'Reduzir estímulos visuais',
              subtitle:
                  'Prioriza telas mais limpas e com menos elementos ao mesmo tempo.',
              value: preferences.reduceVisualStimuli,
              onChanged: onReduceVisualStimuliChanged,
            ),
            _SettingsSwitchRow(
              title: 'Linguagem mais suave',
              subtitle: 'Prefere mensagens menos intensas e mais acolhedoras.',
              value: preferences.softerLanguage,
              onChanged: onSofterLanguageChanged,
            ),
            _SettingsSwitchRow(
              title: 'Ocultar conteúdos sensíveis',
              subtitle:
                  'Evita exibir conteúdos que possam ser sensíveis sem aviso.',
              value: preferences.hideSensitiveContent,
              onChanged: onHideSensitiveContentChanged,
            ),
            _SettingsSwitchRow(
              title: 'Modo acolhimento',
              subtitle: 'Prioriza uma experiência mais gentil e acolhedora.',
              value: preferences.comfortMode,
              onChanged: onComfortModeChanged,
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryPanel(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onSavePreferences,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salvar'),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccessibilitySegmentedRow extends StatelessWidget {
  const _AccessibilitySegmentedRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: options.entries
                  .map(
                    (entry) => ButtonSegment<String>(
                      value: entry.key,
                      label: Text(entry.value),
                    ),
                  )
                  .toList(),
              selected: {value},
              onSelectionChanged: (selection) => onChanged(selection.first),
              showSelectedIcon: false,
            ),
          ),
        ],
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
    required this.contentPreferences,
    required this.checkInReminder,
    required this.aiTone,
    required this.suggestionFrequency,
    required this.trailStyle,
    required this.onPrivateJournalChanged,
    required this.onHideSocialCheckInsChanged,
    required this.onAllowHistoryInsightsChanged,
    required this.onUseEmotionalDataForAiChanged,
    required this.onContentPreferencesChanged,
    required this.onCheckInReminderEnabledChanged,
    required this.onPickCheckInReminderTime,
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
    required this.onOpenPrivacyPolicy,
    required this.onOpenTermsOfUse,
    required this.localePreference,
    required this.onLocalePreferenceChanged,
  });

  final String email;
  final bool privateJournal;
  final bool hideSocialCheckIns;
  final bool allowHistoryInsights;
  final bool useEmotionalDataForAi;
  final bool contentPreferences;
  final DailyCheckInReminderPreferences checkInReminder;
  final String aiTone;
  final String suggestionFrequency;
  final String trailStyle;
  final ValueChanged<bool> onPrivateJournalChanged;
  final ValueChanged<bool> onHideSocialCheckInsChanged;
  final ValueChanged<bool> onAllowHistoryInsightsChanged;
  final ValueChanged<bool> onUseEmotionalDataForAiChanged;
  final ValueChanged<bool> onContentPreferencesChanged;
  final ValueChanged<bool> onCheckInReminderEnabledChanged;
  final VoidCallback onPickCheckInReminderTime;
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
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onOpenTermsOfUse;
  final LocalePreference localePreference;
  final ValueChanged<LocalePreference> onLocalePreferenceChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsPrivacyTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Gerencie sua conta, proteja seus dados e personalize como o Evolua funciona para você.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: l10n.languageSectionTitle,
          description: l10n.languageSectionSubtitle,
          microcopy:
              'Você pode usar o Evolua em português, inglês ou acompanhar o idioma do dispositivo.',
          children: [
            _SettingsDropdownRow(
              title: l10n.languageSectionTitle,
              subtitle: l10n.languageSectionSubtitle,
              value: localePreference.storageValue,
              items: {
                LocalePreference.ptBr.storageValue: l10n.languagePortuguese,
                LocalePreference.enUs.storageValue: l10n.languageEnglish,
                LocalePreference.system.storageValue: l10n.languageSystem,
              },
              onChanged: (value) => onLocalePreferenceChanged(
                LocalePreference.fromStorage(value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Conta e acesso',
          description:
              'Controle as informações básicas da sua conta e mantenha seus acessos seguros.',
          microcopy: '',
          children: [
            _SettingsInfoRow(
              icon: Icons.alternate_email_rounded,
              title: 'E-mail de acesso',
              subtitle: email,
            ),
            _SettingsActionRow(
              icon: Icons.lock_reset_rounded,
              title: 'Alterar senha',
              subtitle: 'Atualize sua senha com segurança.',
              onTap: onChangePassword,
            ),
            _SettingsInfoRow(
              icon: Icons.g_mobiledata_rounded,
              title: 'Login com Google',
              subtitle: 'Conexão disponível para entrada rápida.',
            ),
            _SettingsActionRow(
              icon: Icons.devices_rounded,
              title: 'Dispositivos conectados',
              subtitle: 'Revise onde sua conta está ativa.',
              onTap: onInformationalAction,
            ),
            _SettingsActionRow(
              icon: Icons.logout_rounded,
              title: 'Encerrar sessões ativas',
              subtitle:
                  'Proteja sua conta em dispositivos que você não usa mais.',
              onTap: onRevokeSessions,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Privacidade emocional',
          description:
              'Controle como seus registros emocionais aparecem dentro do Evolua. Essas informações são privadas e não são compartilhadas com outras pessoas.',
          microcopy: '',
          children: [
            _SettingsSwitchRow(
              title: 'Tornar diário privado',
              subtitle: 'Mantenha seus registros apenas no seu espaço.',
              value: privateJournal,
              onChanged: onPrivateJournalChanged,
            ),
            _SettingsSwitchRow(
              title: 'Ocultar check-ins da visão social',
              subtitle: 'Evite que check-ins apareçam em áreas sociais.',
              value: hideSocialCheckIns,
              onChanged: onHideSocialCheckInsChanged,
            ),
            _SettingsSwitchRow(
              title: 'Permitir insights com base no histórico',
              subtitle: 'Use seu histórico para leituras mais consistentes.',
              value: allowHistoryInsights,
              onChanged: onAllowHistoryInsightsChanged,
            ),
            _SettingsSwitchRow(
              title: 'Usar dados emocionais para personalização da IA',
              subtitle: 'Ajude a IA a responder com mais contexto.',
              value: useEmotionalDataForAi,
              onChanged: onUseEmotionalDataForAiChanged,
            ),
            _SettingsActionRow(
              icon: Icons.ios_share_rounded,
              title: 'Exportar histórico emocional',
              subtitle: 'Receba uma cópia dos seus registros emocionais.',
              onTap: onExportData,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Dados e segurança',
          description: 'Tenha transparência sobre seus dados e ações da conta.',
          microcopy:
              'Seus dados pertencem a você. O Evolua existe para apoiar sua jornada com privacidade.',
          children: [
            _SettingsActionRow(
              icon: Icons.download_rounded,
              title: 'Baixar meus dados',
              subtitle: 'Solicite uma cópia completa das suas informações.',
              onTap: onExportData,
            ),
            _SettingsActionRow(
              icon: Icons.delete_forever_rounded,
              title: 'Solicitar exclusão da conta',
              subtitle:
                  'A exclusão exige confirmação antes de qualquer remoção.',
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
              title: 'Histórico de atividade',
              subtitle: 'Veja eventos importantes da sua conta.',
              onTap: onInformationalAction,
            ),
            _SettingsActionRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Política de privacidade',
              subtitle: 'Entenda como seus dados são tratados.',
              onTap: onOpenPrivacyPolicy,
            ),
            _SettingsActionRow(
              icon: Icons.article_outlined,
              title: 'Termos de uso',
              subtitle: 'Leia os termos que orientam o uso do Evolua.',
              onTap: onOpenTermsOfUse,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Personalização da experiência',
          description: 'Ajuste como o Evolua se adapta ao seu momento.',
          microcopy: '',
          children: [
            _SettingsDropdownRow(
              title: 'Tom da IA',
              subtitle: 'Escolha como a IA conversa com você.',
              value: aiTone,
              items: const {
                'acolhedor': 'Mais acolhedor',
                'direto': 'Mais direto',
                'reflexivo': 'Mais reflexivo',
              },
              onChanged: onAiToneChanged,
            ),
            _SettingsDropdownRow(
              title: 'Frequência de sugestões',
              subtitle: 'Defina o ritmo das recomendações.',
              value: suggestionFrequency,
              items: const {
                'baixa': 'Baixa',
                'equilibrada': 'Equilibrada',
                'alta': 'Alta',
              },
              onChanged: onSuggestionFrequencyChanged,
            ),
            _SettingsSwitchRow(
              title: 'Lembrete diário de check-in',
              subtitle: checkInReminder.enabled
                  ? 'Ativo todos os dias às ${checkInReminder.formattedTime}.'
                  : 'Receba um convite leve pela manhã para cuidar do seu momento.',
              value: checkInReminder.enabled,
              onChanged: onCheckInReminderEnabledChanged,
            ),
            _SettingsRowShell(
              icon: Icons.schedule_rounded,
              title: 'Horário do lembrete',
              subtitle:
                  'Padrão ${checkInReminder.formattedTime}, no horário local do dispositivo.',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onPickCheckInReminderTime,
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
              title: 'Preferências de conteúdo',
              subtitle: 'Priorize conteúdos alinhados ao seu momento.',
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
          if (microcopy.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              microcopy,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.evoluaColors.textSecondary,
              ),
            ),
          ],
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
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(
          labelText: title,
          helperText: subtitle,
          prefixIcon: const Icon(Icons.tune_rounded),
        ),
        items: items.entries
            .map(
              (entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.32),
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
                              color:
                                  titleColor ??
                                  context.evoluaColors.textPrimary,
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
            label: const Text('Salvar preferências'),
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

class _SupportTicketDialogResult {
  const _SupportTicketDialogResult({
    required this.subject,
    required this.message,
  });

  final String subject;
  final String message;
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
    this.imageBytes,
    required this.radius,
    required this.fallbackText,
  });

  final String? imageUrl;
  final Uint8List? imageBytes;
  final double radius;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl == null || imageUrl!.isEmpty
        ? null
        : imageUrl!;
    final ImageProvider? avatarImage = imageBytes != null
        ? MemoryImage(imageBytes!)
        : (normalizedUrl != null ? NetworkImage(normalizedUrl) : null);
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.evoluaColors.surfaceStrong,
      backgroundImage: avatarImage,
      child: avatarImage == null
          ? Text(
              _initials(fallbackText),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: context.evoluaColors.textPrimary,
              ),
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
    ProfileModuleSection.overview => 'Visão geral',
    ProfileModuleSection.settingsPrivacy => 'Configurações e privacidade',
    ProfileModuleSection.helpSupport => 'Ajuda e suporte',
    ProfileModuleSection.displayAccessibility => 'Tela e acessibilidade',
    ProfileModuleSection.feedback => 'Dar feedback',
    ProfileModuleSection.plansSubscriptions => 'Planos e assinaturas',
    ProfileModuleSection.evolutionMirror => 'Espelho da Evolução',
  };
}
