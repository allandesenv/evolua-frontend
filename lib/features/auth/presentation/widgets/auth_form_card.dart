import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/network/api_error_message.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/presentation/utils/google_oauth_redirect.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthFormCard extends ConsumerStatefulWidget {
  const AuthFormCard({super.key});

  @override
  ConsumerState<AuthFormCard> createState() => _AuthFormCardState();
}

class _AuthFormCardState extends ConsumerState<AuthFormCard> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _customGenderController = TextEditingController();
  bool _isRegisterMode = false;
  DateTime? _birthDate;
  String _gender = 'MALE';

  @override
  void initState() {
    super.initState();
    ref.listenManual(authControllerProvider, (previous, next) {
      final error = next.error;

      if (error == null) {
        return;
      }

      final message = extractApiErrorMessage(
        error,
        fallback: 'Falha ao autenticar.',
      );

      AppSnackBar.show(
        context,
        message: message,
        icon: Icons.info_outline_rounded,
      );
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _customGenderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);

    if (_isRegisterMode) {
      final message = await controller.register(
        displayName: _displayNameController.text.trim(),
        birthDate: _birthDate!,
        gender: _gender,
        customGender: _gender == 'CUSTOM'
            ? _customGenderController.text.trim()
            : null,
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (message != null && mounted) {
        AppSnackBar.show(
          context,
          message: message,
          icon: Icons.info_outline_rounded,
        );
      }
      return;
    }

    await controller.login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  void _handleGoogleLogin() {
    final frontendRedirectUri =
        Uri.parse(Uri.base.origin).resolve('/auth/google/callback').toString();
    final startUri = Uri.parse('${AppConfig.apiBaseUrl}/v1/public/auth/google/start').replace(
      queryParameters: {
        'frontendRedirectUri': frontendRedirectUri,
      },
    );

    try {
      openGoogleOAuthRedirect(startUri.toString());
    } catch (_) {
      AppSnackBar.show(
        context,
        message: 'Google login esta disponivel apenas no Flutter Web.',
        icon: Icons.info_outline_rounded,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final theme = Theme.of(context);
    final compact = ResponsiveBreakpoints.isCompact(context);

    return PrimaryPanel(
      padding: const EdgeInsets.all(28),
      semanticLabel: 'Formulario de autenticacao',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: compact ? double.infinity : null,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.login_rounded),
                  label: Text('Entrar'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.person_add_alt_1_rounded),
                  label: Text('Criar conta'),
                ),
              ],
              selected: {_isRegisterMode},
              onSelectionChanged: (selection) {
                setState(() => _isRegisterMode = selection.first);
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isRegisterMode ? 'Crie sua conta e comece leve' : 'Entre e continue sua jornada',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            _isRegisterMode
                ? 'Cadastro direto, sem ruido, para voce chegar logo ao primeiro check-in.'
                : 'Continue de onde parou com um login simples e sem excesso de passos.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : _handleGoogleLogin,
              icon: const Icon(Icons.account_circle_rounded),
              label: const Text('Continuar com Google'),
            ),
          ),
          const SizedBox(height: 24),
          AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
              children: [
                if (_isRegisterMode) ...[
                  TextFormField(
                    controller: _displayNameController,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      hintText: 'Como voce quer ser chamado',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                    validator: (value) {
                      if (!_isRegisterMode) {
                        return null;
                      }
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe seu nome.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickBirthDate,
                    borderRadius: BorderRadius.circular(18),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data de nascimento',
                        prefixIcon: Icon(Icons.cake_rounded),
                      ),
                      child: Text(
                        _birthDate == null
                            ? 'Selecione sua data'
                            : '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}',
                      ),
                    ),
                  ),
                  if (_birthDate == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Informe sua data de nascimento.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Genero',
                      prefixIcon: Icon(Icons.wc_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'MALE', child: Text('Masculino')),
                      DropdownMenuItem(value: 'FEMALE', child: Text('Feminino')),
                      DropdownMenuItem(value: 'CUSTOM', child: Text('Personalizado')),
                    ],
                    onChanged: (value) {
                      setState(() => _gender = value ?? 'MALE');
                    },
                  ),
                  if (_gender == 'CUSTOM') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _customGenderController,
                      decoration: const InputDecoration(
                        labelText: 'Como voce se identifica',
                        hintText: 'Escreva do seu jeito',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                      validator: (value) {
                        if (_isRegisterMode &&
                            _gender == 'CUSTOM' &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Informe seu genero personalizado.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'voce@evolua.app',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe seu email.';
                    }

                    if (!value.contains('@')) {
                      return 'Use um email valido.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    hintText: 'Minimo de 6 caracteres',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 6) {
                      return 'A senha deve ter ao menos 6 caracteres.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading || (_isRegisterMode && _birthDate == null)
                        ? null
                        : _submit,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isRegisterMode ? 'Criar conta' : 'Entrar'),
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}
