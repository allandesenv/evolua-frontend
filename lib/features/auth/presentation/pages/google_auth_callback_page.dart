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
        final session = await _completeGoogleCallback(
          code,
        ).timeout(widget.completionTimeout);

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
          debugPrint(
            'Google OAuth callback failed '
            '(errorType=${error.runtimeType}, '
            'providerErrorType=${_providerExceptionType(error)}).',
          );
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

  Future<AuthSession?> _completeGoogleCallback(String code) async {
    await _ensureAuthControllerReady();
    if (!mounted) {
      return null;
    }

    late AuthController controller;
    try {
      controller = ref.read(authControllerProvider.notifier);
    } catch (error) {
      _logAuthPreparationFailure(
        stage: 'notifier_read',
        error: error,
        authState: _readAuthState(),
      );
      try {
        await _rebuildAuthController();
        controller = ref.read(authControllerProvider.notifier);
      } catch (rebuildError) {
        _logAuthPreparationFailure(
          stage: 'notifier_read_after_rebuild',
          error: rebuildError,
          authState: _readAuthState(),
        );
        throw StateError('AuthController indisponivel para concluir OAuth.');
      }
    }

    try {
      return await controller.completeGoogleLogin(code: code);
    } catch (error) {
      _logAuthPreparationFailure(
        stage: 'exchange',
        error: error,
        authState: _readAuthState(),
      );
      rethrow;
    }
  }

  Future<void> _ensureAuthControllerReady() async {
    var authState = _readAuthState();
    Object? initialReadError = authState.readError;
    Object? bootstrapError;
    Object? rebuildError;

    if (authState.isLoadingWithoutData) {
      try {
        await ref.read(authControllerProvider.future);
      } catch (error) {
        bootstrapError = error;
      }
      authState = _readAuthState();
      initialReadError ??= authState.readError;
    }

    if (authState.isUsable) {
      return;
    }

    if (authState.hasError || authState.isUnreadable) {
      try {
        await _rebuildAuthController();
      } catch (error) {
        rebuildError = error;
      }

      authState = _readAuthState();
      if (authState.isUsable) {
        return;
      }
    }

    _logAuthPreparationFailure(
      stage: initialReadError != null
          ? 'initial_state_read'
          : rebuildError != null
          ? 'rebuild'
          : bootstrapError != null
          ? 'initial_bootstrap'
          : 'state_check',
      error: initialReadError ?? rebuildError ?? bootstrapError,
      authState: authState,
    );

    throw StateError('AuthController indisponivel para concluir OAuth.');
  }

  Future<void> _rebuildAuthController() async {
    final rebuild = ref.refresh(authControllerProvider.future);
    await rebuild;
  }

  _AuthStateSnapshot _readAuthState() {
    try {
      return _AuthStateSnapshot(ref.read(authControllerProvider));
    } catch (error) {
      return _AuthStateSnapshot.unreadable(error);
    }
  }

  void _logAuthPreparationFailure({
    required String stage,
    required Object? error,
    required _AuthStateSnapshot authState,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      'Google OAuth auth preparation failed '
      '(stage=$stage, errorType=${error?.runtimeType}, '
      'providerErrorType=${_providerExceptionType(error)}, '
      'finalState=${_describeAuthState(authState)}).',
    );
  }

  String? _providerExceptionType(Object? error) {
    try {
      final dynamic providerException = error;
      final Object? inner = providerException.exception as Object?;
      return inner?.runtimeType.toString();
    } catch (_) {
      return null;
    }
  }

  String _describeAuthState(_AuthStateSnapshot authState) {
    if (authState.isUnreadable) {
      return 'unreadable';
    }
    final state = authState.value!;
    if (state.hasError) {
      return 'error';
    }
    if (state.asData != null) {
      return 'data';
    }
    if (state.isLoading) {
      return 'loading';
    }
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
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

class _AuthStateSnapshot {
  const _AuthStateSnapshot(this.value) : readError = null;

  const _AuthStateSnapshot.unreadable(this.readError) : value = null;

  final AsyncValue<AuthSession?>? value;
  final Object? readError;

  bool get isUnreadable => value == null;

  bool get isLoadingWithoutData {
    final state = value;
    return state != null && state.isLoading && state.asData == null;
  }

  bool get hasError {
    final state = value;
    return readError != null || (state != null && state.hasError);
  }

  bool get isUsable {
    final state = value;
    return state != null && state.asData != null && !state.hasError;
  }
}
