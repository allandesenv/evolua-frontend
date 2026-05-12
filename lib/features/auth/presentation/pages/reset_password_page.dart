import 'package:evolua_frontend/core/network/api_error_message.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isSubmitting = false;
  bool _completed = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _completed) {
      return;
    }
    if (widget.token == null || widget.token!.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Link de recuperacao invalido.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
            token: widget.token!,
            newPassword: _passwordController.text,
          );
      if (!mounted) {
        return;
      }
      setState(() => _completed = true);
      AppSnackBar.show(
        context,
        message: 'Senha redefinida. Voce ja pode entrar.',
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: extractApiErrorMessage(
          error,
          fallback: 'Nao foi possivel redefinir sua senha.',
        ),
        icon: Icons.info_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: PrimaryPanel(
              semanticLabel: 'Redefinir senha',
              padding: const EdgeInsets.all(24),
              child: _completed ? _successContent(context) : _formContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formContent(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Criar nova senha',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Escolha uma senha com ao menos 6 caracteres para voltar ao Evolua.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Nova senha',
              prefixIcon: const Icon(Icons.lock_reset_rounded),
              suffixIcon: IconButton(
                tooltip: _isPasswordVisible ? 'Ocultar senha' : 'Mostrar senha',
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
            validator: validatePassword,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isPasswordVisible,
            decoration: const InputDecoration(
              labelText: 'Confirmar nova senha',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            validator: (value) {
              final passwordError = validatePassword(value);
              if (passwordError != null) {
                return passwordError;
              }
              if (value != _passwordController.text) {
                return 'As senhas nao conferem.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Redefinir senha'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _isSubmitting ? null : () => context.go('/auth'),
            child: const Text('Voltar para entrar'),
          ),
        ],
      ),
    );
  }

  Widget _successContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 42),
        const SizedBox(height: 14),
        Text(
          'Senha redefinida',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        const Text('Agora voce pode entrar usando sua nova senha.'),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/auth'),
            child: const Text('Entrar'),
          ),
        ),
      ],
    );
  }
}
