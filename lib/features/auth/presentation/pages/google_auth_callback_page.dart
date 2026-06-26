import 'dart:async';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:flutter/foundation.dart';
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
        await _completeGoogleCallback(code).timeout(widget.completionTimeout);

        final authState = ref.read(authControllerProvider);
        final session = authState.asData?.value;

        if (!mounted) {
          return;
        }

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
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Google OAuth callback failed (${error.runtimeType}).');
        }
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

  Future<void> _completeGoogleCallback(String code) async {
    await _ensureAuthControllerReady();
    if (!mounted) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .completeGoogleLogin(code: code);
  }

  Future<void> _ensureAuthControllerReady() async {
    var authState = ref.read(authControllerProvider);
    Object? bootstrapError;
    Object? rebuildError;

    if (authState.isLoading && !authState.hasValue) {
      try {
        await ref.read(authControllerProvider.future);
      } catch (error) {
        bootstrapError = error;
      }
      authState = ref.read(authControllerProvider);
    }

    if (authState.hasValue) {
      return;
    }

    if (authState.hasError) {
      try {
        final rebuilt = ref.refresh(authControllerProvider.future);
        await rebuilt;
      } catch (error) {
        rebuildError = error;
      }

      authState = ref.read(authControllerProvider);
      if (authState.hasValue) {
        return;
      }
    }

    if (kDebugMode) {
      final failedStage = rebuildError != null
          ? 'rebuild'
          : bootstrapError != null
          ? 'initial_bootstrap'
          : 'state_check';
      final errorType =
          rebuildError?.runtimeType ?? bootstrapError?.runtimeType;
      debugPrint(
        'Google OAuth auth preparation failed '
        '(stage=$failedStage, errorType=$errorType, '
        'finalState=${_describeAuthState(authState)}).',
      );
    }

    throw StateError('AuthController indisponivel para concluir OAuth.');
  }

  String _describeAuthState(AsyncValue<AuthSession?> authState) {
    if (authState.hasValue) {
      return 'value';
    }
    if (authState.hasError) {
      return 'error';
    }
    if (authState.isLoading) {
      return 'loading';
    }
    return 'unknown';
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
