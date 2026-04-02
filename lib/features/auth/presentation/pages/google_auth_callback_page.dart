import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GoogleAuthCallbackPage extends ConsumerStatefulWidget {
  const GoogleAuthCallbackPage({
    super.key,
    this.code,
    this.error,
  });

  final String? code;
  final String? error;

  @override
  ConsumerState<GoogleAuthCallbackPage> createState() => _GoogleAuthCallbackPageState();
}

class _GoogleAuthCallbackPageState extends ConsumerState<GoogleAuthCallbackPage> {
  String? _errorMessage;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }

    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.error != null && widget.error!.isNotEmpty) {
        setState(() => _errorMessage = 'Nao foi possivel autenticar com Google.');
        return;
      }

      final code = widget.code;
      if (code == null || code.isEmpty) {
        setState(() => _errorMessage = 'Callback de autenticacao sem codigo.');
        return;
      }

      try {
        await ref.read(authControllerProvider.notifier).completeGoogleLogin(code: code);
        if (!mounted) {
          return;
        }
        context.go('/home');
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() => _errorMessage = 'Falha ao concluir o login com Google.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading && !authState.hasValue;

    return GradientScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle_rounded, size: 42),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage == null ? 'Concluindo seu login com Google' : 'Nao foi possivel entrar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage ??
                        'Estamos validando sua autenticacao e preparando a sessao.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage == null && isLoading)
                    const CircularProgressIndicator()
                  else
                    FilledButton(
                      onPressed: () {
                        context.go('/auth');
                      },
                      child: const Text('Voltar para login'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
