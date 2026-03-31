import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(authControllerProvider, (previous, next) {
      final error = next.error;

      if (error == null) {
        return;
      }

      final message = error is DioException
          ? (error.response?.data is Map<String, dynamic>
              ? (error.response?.data['message']?.toString() ??
                  error.message ??
                  'Falha ao autenticar.')
              : error.message ?? 'Falha ao autenticar.')
          : error.toString();

      AppSnackBar.show(
        context,
        message: message,
        icon: Icons.info_outline_rounded,
      );
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);

    if (_isRegisterMode) {
      await controller.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      return;
    }

    await controller.login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  void _handleGoogleStub() {
    AppSnackBar.show(
      context,
      message: 'Google login entra na proxima etapa. Por agora, siga com email e senha.',
      icon: Icons.info_outline_rounded,
    );
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
              onPressed: isLoading ? null : _handleGoogleStub,
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
                    onPressed: isLoading ? null : _submit,
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
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceStrong.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perfis de desenvolvimento',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _DevCredentialChip(
                      label: 'Admin',
                      value: 'clara@evolua.local / 123456',
                    ),
                    _DevCredentialChip(
                      label: 'Gratuito',
                      value: 'leo@evolua.local / 123456',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sessao persistente para voce voltar rapido ao app quando quiser.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DevCredentialChip extends StatelessWidget {
  const _DevCredentialChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
