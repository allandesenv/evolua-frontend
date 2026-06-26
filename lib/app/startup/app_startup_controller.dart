import 'dart:async';

import 'package:evolua_frontend/app/startup/startup_diagnostics.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/notification/application/local_check_in_reminder_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appStartupControllerProvider = Provider<AppStartupController>((ref) {
  return AppStartupController(ref);
});

class AppStartupController {
  AppStartupController(
    this._ref, {
    bool allowWarmUpInTests = false,
    Future<void> Function()? initializeLocalNotifications,
  }) : _allowWarmUpInTests = allowWarmUpInTests,
       _initializeLocalNotifications =
           initializeLocalNotifications ??
           LocalCheckInReminderNotifications.initialize;

  final Ref _ref;
  final bool _allowWarmUpInTests;
  final Future<void> Function() _initializeLocalNotifications;
  int _sessionGeneration = 0;
  int? _inFlightGeneration;
  int? _completedGeneration;
  Future<void>? _inFlight;

  void warmUpAfterFirstFrame(AuthSession? session) {
    if (session == null) {
      return;
    }
    if (!_allowWarmUpInTests && _isWidgetTestBinding) {
      return;
    }
    unawaited(_startWarmUp(session));
  }

  @visibleForTesting
  Future<void> warmUpForTesting(AuthSession session) {
    return _startWarmUp(session);
  }

  void reset() {
    _sessionGeneration++;
    _inFlightGeneration = null;
    _completedGeneration = null;
    _inFlight = null;
  }

  bool get _isWidgetTestBinding {
    return WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }

  Future<void> _startWarmUp(AuthSession session) {
    final generation = _sessionGeneration;
    final inFlight = _inFlight;
    if (_inFlightGeneration == generation && inFlight != null) {
      return inFlight;
    }
    if (_completedGeneration == generation && _isCurrentSession(session)) {
      return Future<void>.value();
    }

    final future = _warmUp(session, generation);
    _inFlight = future;
    _inFlightGeneration = generation;
    unawaited(
      future.whenComplete(() {
        if (identical(_inFlight, future) &&
            _inFlightGeneration == generation &&
            _sessionGeneration == generation) {
          _inFlight = null;
          _inFlightGeneration = null;
        }
      }),
    );
    return future;
  }

  Future<void> _warmUp(AuthSession session, int generation) async {
    StartupDiagnostics.mark('post-login warmup scheduled');
    final steps = <Future<void> Function()>[
      () => _runIfSessionCurrent(session, generation, () {
        return _guarded('local notifications init', () {
          return _initializeLocalNotifications();
        });
      }),
      () => _guarded(
        'check-ins',
        () => _runIfSessionCurrent(
          session,
          generation,
          () => _ref.read(checkInControllerProvider.future),
        ),
      ),
      () => _guarded(
        'current trail',
        () => _runIfSessionCurrent(
          session,
          generation,
          () => _ref.read(currentJourneyTrailProvider.future),
        ),
      ),
    ];
    await Future.wait([for (final step in steps) step()]);
    if (_sessionGeneration == generation && _isCurrentSession(session)) {
      _completedGeneration = generation;
    }
    StartupDiagnostics.mark('post-login warmup completed');
  }

  Future<void> _guarded<T>(String name, Future<T> Function() operation) async {
    try {
      await StartupDiagnostics.measure(name, operation);
    } catch (_) {
      return;
    }
  }

  Future<T?> _runIfSessionCurrent<T>(
    AuthSession session,
    int generation,
    Future<T> Function() operation,
  ) async {
    if (_sessionGeneration != generation || !_isCurrentSession(session)) {
      return null;
    }
    final result = await operation();
    if (_sessionGeneration != generation || !_isCurrentSession(session)) {
      return null;
    }
    return result;
  }

  bool _isCurrentSession(AuthSession session) {
    return _ref.read(authControllerProvider).asData?.value?.userId ==
        session.userId;
  }
}
