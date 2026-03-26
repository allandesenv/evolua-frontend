import 'package:dio/dio.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final theme = Theme.of(context);

    return PrimaryPanel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
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
          const SizedBox(height: 24),
          Text(
            _isRegisterMode ? 'Comece sua jornada hoje' : 'Seu espaco seguro para evoluir',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            _isRegisterMode
                ? 'Crie sua conta em poucos segundos e siga para o primeiro check-in.'
                : 'Entre para retomar sua jornada com clareza e consistencia.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Form(
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
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isRegisterMode ? 'Criar conta' : 'Entrar'),
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
                  'Sessao persistente e acesso rapido para voce voltar ao app sem friccao.',
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
