import 'dart:async';

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
    this.completionTimeout = const Duration(seconds: 15),
  });

  final String? code;
  final String? error;
  final Duration completionTimeout;

  @override
  ConsumerState<GoogleAuthCallbackPage> createState() =>
      _GoogleAuthCallbackPageState();
}

class _GoogleAuthCallbackPageState
    extends ConsumerState<GoogleAuthCallbackPage> {
  String? _errorMessage;
  bool _isCompleting = true;
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
        if (!mounted) {
          return;
        }
        setState(() {
          _isCompleting = false;
          _errorMessage = 'Nao foi possivel autenticar com Google.';
        });
        return;
      }

      final code = widget.code;
      if (code == null || code.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isCompleting = false;
          _errorMessage = 'Callback de autenticacao sem codigo.';
        });
        return;
      }

      try {
        await ref
            .read(authControllerProvider.notifier)
            .completeGoogleLogin(code: code)
            .timeout(widget.completionTimeout);
        if (!mounted) {
          return;
        }
        final session = ref.read(authControllerProvider).asData?.value;
        if (session == null) {
          setState(() {
            _isCompleting = false;
            _errorMessage = 'Falha ao concluir o login com Google.';
          });
          return;
        }
        context.go('/home');
      } on TimeoutException {
        if (!mounted) {
          return;
        }
        setState(() {
          _isCompleting = false;
          _errorMessage =
              'O login com Google demorou mais que o esperado. Tente novamente.';
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isCompleting = false;
          _errorMessage = 'Falha ao concluir o login com Google.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authControllerProvider);

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
                    _errorMessage == null
                        ? 'Concluindo seu login com Google'
                        : 'Nao foi possivel entrar',
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
                  if (_errorMessage == null && _isCompleting)
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
