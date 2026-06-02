import 'dart:async';

import 'package:evolua_frontend/app/startup/startup_diagnostics.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/notification/application/local_check_in_reminder_controller.dart';
import 'package:evolua_frontend/features/notification/application/notification_controller.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appStartupControllerProvider = Provider<AppStartupController>((ref) {
  return AppStartupController(ref);
});

class AppStartupController {
  AppStartupController(this._ref);

  final Ref _ref;
  String? _warmingUserId;
  Future<void>? _inFlight;

  void warmUpAfterFirstFrame(AuthSession? session) {
    if (session == null) {
      return;
    }
    if (_isWidgetTestBinding) {
      return;
    }
    final inFlight = _inFlight;
    if (_warmingUserId == session.userId && inFlight != null) {
      return;
    }

    _warmingUserId = session.userId;
    final future = _warmUp(session);
    _inFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_inFlight, future)) {
          _inFlight = null;
        }
      }),
    );
  }

  bool get _isWidgetTestBinding {
    return WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }

  Future<void> _warmUp(AuthSession session) async {
    StartupDiagnostics.mark('post-login warmup scheduled:${session.userId}');
    final steps = <Future<void> Function()>[
      () => _guarded('local notifications init', () {
        return LocalCheckInReminderNotifications.initialize();
      }),
      () => _guarded(
        'profile',
        () => _ref.read(profileControllerProvider.future),
      ),
      () => _guarded(
        'check-ins',
        () => _ref.read(checkInControllerProvider.future),
      ),
      () => _guarded('subscription', () {
        return _ref.read(subscriptionControllerProvider.future);
      }),
      () => _guarded(
        'current trail',
        () => _ref.read(currentJourneyTrailProvider.future),
      ),
      () => _guarded('notifications inbox', () {
        return _ref.read(notificationInboxControllerProvider.future);
      }),
      () => _guarded(
        'spaces',
        () => _ref.read(communityControllerProvider.future),
      ),
      () => _guarded(
        'social feed',
        () => _ref.read(socialPostControllerProvider.future),
      ),
    ];
    for (final step in steps) {
      unawaited(step());
    }
    StartupDiagnostics.mark('post-login warmup dispatched:${session.userId}');
  }

  Future<void> _guarded<T>(String name, Future<T> Function() operation) async {
    try {
      await StartupDiagnostics.measure(name, operation);
    } catch (_) {
      return;
    }
  }
}
