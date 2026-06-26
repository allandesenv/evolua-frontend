import 'dart:async';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/subscription/application/google_play_billing_service.dart';
import 'package:evolua_frontend/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final dio = ref.watch(
    authenticatedDioProvider(AppConfig.subscriptionBaseUrl),
  );
  return SubscriptionRepositoryImpl(dio);
});

final planCatalogClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final currentSubscriptionProvider =
    AsyncNotifierProvider<CurrentSubscriptionController, CurrentSubscription?>(
      CurrentSubscriptionController.new,
    );

final planCatalogProvider =
    AsyncNotifierProvider<PlanCatalogController, List<PlanView>>(
      PlanCatalogController.new,
    );

final subscriptionControllerProvider =
    AsyncNotifierProvider.autoDispose<
      SubscriptionController,
      SubscriptionScreenState
    >(SubscriptionController.new);

final checkoutPollingDelaysProvider = Provider<List<Duration>>((ref) {
  return const [
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
  ];
});

final checkoutPollingTimeoutProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 30);
});

final checkoutPollingLifecycleProvider = Provider<CheckoutPollingLifecycle>((
  ref,
) {
  final lifecycle = AppCheckoutPollingLifecycle();
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});

abstract class CheckoutPollingLifecycle {
  bool get isResumed;

  Future<void> waitUntilResumed();
}

class AppCheckoutPollingLifecycle
    with WidgetsBindingObserver
    implements CheckoutPollingLifecycle {
  AppCheckoutPollingLifecycle() {
    _state = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  AppLifecycleState? _state;
  Completer<void>? _resumeCompleter;

  @override
  bool get isResumed => _state == null || _state == AppLifecycleState.resumed;

  @override
  Future<void> waitUntilResumed() {
    if (isResumed) {
      return Future<void>.value();
    }
    return (_resumeCompleter ??= Completer<void>()).future;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
    if (isResumed) {
      final completer = _resumeCompleter;
      _resumeCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final completer = _resumeCompleter;
    _resumeCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}

class SubscriptionSessionContext {
  const SubscriptionSessionContext({
    required this.userId,
    required this.generation,
  });

  final String userId;
  final int generation;
}

class CurrentSubscriptionController
    extends AsyncNotifier<CurrentSubscription?> {
  Future<CurrentSubscription?>? _refreshInFlight;
  String? _stateUserId;
  int? _stateGeneration;

  @override
  Future<CurrentSubscription?> build() async {
    final context = await sessionContext();
    if (context == null) {
      _stateUserId = null;
      _stateGeneration = null;
      return null;
    }
    final current = await ref.read(subscriptionRepositoryProvider).current();
    if (!_matches(context)) {
      return null;
    }
    _stateUserId = context.userId;
    _stateGeneration = context.generation;
    return current;
  }

  Future<SubscriptionSessionContext?> sessionContext() async {
    final session = await ref.read(authControllerProvider.future);
    if (session == null) {
      return null;
    }
    return SubscriptionSessionContext(
      userId: session.userId,
      generation: ref.read(authSessionGenerationProvider),
    );
  }

  Future<CurrentSubscription?> refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _refresh();
    _refreshInFlight = future;
    unawaited(
      future
          .whenComplete(() {
            if (identical(_refreshInFlight, future)) {
              _refreshInFlight = null;
            }
          })
          .catchError((_) => null),
    );
    return future;
  }

  Future<CurrentSubscription?> _refresh() async {
    final previous = state.asData?.value;
    final context = await sessionContext();
    if (context == null) {
      _stateUserId = null;
      _stateGeneration = null;
      state = const AsyncData(null);
      return null;
    }
    try {
      final current = await ref.read(subscriptionRepositoryProvider).current();
      publishForSession(
        expectedUserId: context.userId,
        expectedGeneration: context.generation,
        current: current,
      );
      return current;
    } catch (error, stackTrace) {
      if (previous == null && !state.hasValue) {
        state = AsyncError(error, stackTrace);
      } else if (previous != null) {
        state = AsyncData(previous);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void publishForSession({
    required String expectedUserId,
    required int expectedGeneration,
    required CurrentSubscription? current,
  }) {
    if (!ref.mounted) {
      return;
    }
    final session = ref.read(authControllerProvider).asData?.value;
    final generation = ref.read(authSessionGenerationProvider);
    if (session == null ||
        session.userId != expectedUserId ||
        generation != expectedGeneration) {
      return;
    }
    _stateUserId = expectedUserId;
    _stateGeneration = expectedGeneration;
    state = AsyncData(current);
  }

  bool _matches(SubscriptionSessionContext context) {
    if (!ref.mounted) {
      return false;
    }
    final session = ref.read(authControllerProvider).asData?.value;
    return session?.userId == context.userId &&
        ref.read(authSessionGenerationProvider) == context.generation;
  }

  bool ownsCurrentSession() {
    final session = ref.read(authControllerProvider).asData?.value;
    final generation = ref.read(authSessionGenerationProvider);
    return session != null &&
        _stateUserId == session.userId &&
        _stateGeneration == generation;
  }
}

class PlanCatalogController extends AsyncNotifier<List<PlanView>> {
  static const ttl = Duration(hours: 12);

  List<PlanView>? _items;
  DateTime? _loadedAt;
  Future<List<PlanView>>? _inFlight;

  @override
  Future<List<PlanView>> build() {
    return load();
  }

  Future<List<PlanView>> load({bool force = false}) {
    final now = ref.read(planCatalogClockProvider)();
    final cached = _items;
    final loadedAt = _loadedAt;
    if (!force &&
        cached != null &&
        loadedAt != null &&
        now.difference(loadedAt) < ttl) {
      return Future.value(cached);
    }
    final inFlight = _inFlight;
    if (!force && inFlight != null) {
      return inFlight;
    }
    final future = _fetch();
    _inFlight = future;
    unawaited(
      future
          .whenComplete(() {
            if (identical(_inFlight, future)) {
              _inFlight = null;
            }
          })
          .catchError((_) => const <PlanView>[]),
    );
    return future;
  }

  Future<List<PlanView>> _fetch() async {
    final plans = await ref.read(subscriptionRepositoryProvider).listPlans();
    _items = plans;
    _loadedAt = ref.read(planCatalogClockProvider)();
    if (ref.mounted) {
      state = AsyncData(plans);
    }
    return plans;
  }

  DateTime? get loadedAtForTesting => _loadedAt;
}

class SubscriptionController extends AsyncNotifier<SubscriptionScreenState> {
  final _trackCheckoutInFlight = <String, Future<void>>{};

  @override
  Future<SubscriptionScreenState> build() async {
    final currentFuture = ref.read(currentSubscriptionProvider.future);
    final plansFuture = ref.read(planCatalogProvider.notifier).load();
    final results = await Future.wait<Object?>([plansFuture, currentFuture]);
    return SubscriptionScreenState(
      plans: results[0] as List<PlanView>,
      current: results[1] as CurrentSubscription?,
    );
  }

  Future<void> refresh({bool forceCatalog = false}) async {
    final currentState = state.asData?.value;
    state = AsyncData(
      (currentState ?? const SubscriptionScreenState(plans: [], current: null))
          .copyWith(isBusy: true, clearMessage: true),
    );
    state = await AsyncValue.guard(() async {
      final currentFuture = ref
          .read(currentSubscriptionProvider.notifier)
          .refresh();
      final plansFuture = ref
          .read(planCatalogProvider.notifier)
          .load(force: forceCatalog);
      final results = await Future.wait<Object?>([plansFuture, currentFuture]);
      return SubscriptionScreenState(
        plans: results[0] as List<PlanView>,
        current: results[1] as CurrentSubscription?,
        pendingCheckout: currentState?.pendingCheckout,
      );
    });
  }

  Future<CheckoutSession> startCheckout(String planCode) async {
    final keepAlive = ref.keepAlive();
    try {
      final context = await _captureSessionContext();
      final repository = ref.read(subscriptionRepositoryProvider);
      final currentState = _currentState();
      _publishIfSession(
        context,
        currentState.copyWith(
          isBusy: true,
          busyPlanCode: planCode,
          clearMessage: true,
        ),
      );
      try {
        final checkout = await repository.startCheckout(
          planCode: planCode,
          frontendBaseUrl: kIsWeb
              ? Uri.parse(Uri.base.origin).resolve('/home').toString()
              : '${AppConfig.appDeepLinkBaseUrl}/billing/return',
        );
        if (!_isCurrentSession(context)) {
          return checkout;
        }
        final refreshedCurrent = await repository.current();
        _publishCurrent(context, refreshedCurrent);
        _publishIfSession(
          context,
          _currentState().copyWith(
            current: refreshedCurrent,
            pendingCheckout: checkout,
            isBusy: false,
            clearBusyPlanCode: true,
            message: checkout.isApproved
                ? 'Plano atualizado com sucesso.'
                : 'Checkout iniciado. Estamos aguardando a confirmaÃ§Ã£o do pagamento.',
          ),
        );
        return checkout;
      } catch (error) {
        final message = _friendlyCheckoutError(error);
        _publishIfSession(
          context,
          currentState.copyWith(
            isBusy: false,
            clearBusyPlanCode: true,
            message: message,
          ),
        );
        throw SubscriptionCheckoutException(message);
      }
    } finally {
      keepAlive.close();
    }
  }

  Future<CheckoutSession> startPremiumCheckout(PlanView plan) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _startGooglePlayCheckout(plan);
    }
    return startCheckout(plan.planCode);
  }

  Future<CheckoutSession> _startGooglePlayCheckout(PlanView plan) async {
    final keepAlive = ref.keepAlive();
    try {
      final context = await _captureSessionContext();
      final repository = ref.read(subscriptionRepositoryProvider);
      final currentState = _currentState();
      _publishIfSession(
        context,
        currentState.copyWith(
          isBusy: true,
          busyPlanCode: plan.planCode,
          clearMessage: true,
        ),
      );
      try {
        final checkout = await ref
            .read(googlePlayBillingServiceProvider)
            .buyPremium(plan: plan, repository: repository);
        if (!_isCurrentSession(context)) {
          return checkout;
        }
        final current = await repository.current();
        _publishCurrent(context, current);
        _publishIfSession(
          context,
          _currentState().copyWith(
            current: current,
            pendingCheckout: checkout,
            isBusy: false,
            clearBusyPlanCode: true,
            message: checkout.isApproved
                ? 'Pagamento confirmado e plano liberado.'
                : 'Compra recebida, mas ainda nÃ£o confirmada.',
          ),
        );
        return checkout;
      } catch (error) {
        final message = _friendlyCheckoutError(error);
        _publishIfSession(
          context,
          currentState.copyWith(
            isBusy: false,
            clearBusyPlanCode: true,
            message: message,
          ),
        );
        throw SubscriptionCheckoutException(message);
      }
    } finally {
      keepAlive.close();
    }
  }

  Future<void> trackCheckout(String checkoutId) async {
    final inFlight = _trackCheckoutInFlight[checkoutId];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _trackCheckout(checkoutId);
    _trackCheckoutInFlight[checkoutId] = future;
    unawaited(
      future
          .whenComplete(() {
            if (identical(_trackCheckoutInFlight[checkoutId], future)) {
              _trackCheckoutInFlight.remove(checkoutId);
            }
          })
          .catchError((_) => null),
    );
    return future;
  }

  Future<void> _trackCheckout(String checkoutId) async {
    final keepAlive = ref.keepAlive();
    try {
      final context = await _captureSessionContext();
      final repository = ref.read(subscriptionRepositoryProvider);
      final startedAt = DateTime.now();
      final timeout = ref.read(checkoutPollingTimeoutProvider);
      _publishIfSession(
        context,
        _currentState().copyWith(isBusy: true, clearMessage: true),
      );

      CheckoutSession checkout = await repository.checkoutStatus(checkoutId);
      _publishPendingCheckout(context, checkout);

      var attempt = 0;
      while (checkout.isPending && _isCurrentSession(context)) {
        final elapsed = DateTime.now().difference(startedAt);
        if (elapsed >= timeout) {
          break;
        }
        await _waitForNextCheckoutPoll(attempt, timeout - elapsed);
        if (!_isCurrentSession(context)) {
          return;
        }
        if (DateTime.now().difference(startedAt) >= timeout) {
          break;
        }
        checkout = await repository.checkoutStatus(checkoutId);
        _publishPendingCheckout(context, checkout);
        attempt++;
      }

      if (!_isCurrentSession(context)) {
        return;
      }
      final current = await repository.current();
      if (!_isCurrentSession(context)) {
        return;
      }
      _publishCurrent(context, current);
      _publishIfSession(
        context,
        _currentState().copyWith(
          current: current,
          pendingCheckout: checkout,
          isBusy: false,
          clearBusyPlanCode: true,
          message: checkout.isApproved
              ? 'Pagamento confirmado e plano liberado.'
              : checkout.failureReason == null
              ? 'Ainda estamos confirmando o pagamento.'
              : 'Pagamento nÃ£o confirmado: ${checkout.failureReason}.',
        ),
      );
    } finally {
      keepAlive.close();
    }
  }

  Future<void> _waitForNextCheckoutPoll(
    int attempt,
    Duration remainingTimeout,
  ) async {
    final delays = ref.read(checkoutPollingDelaysProvider);
    final fallbackDelay = delays.isEmpty ? Duration.zero : delays.last;
    final configuredDelay = attempt < delays.length
        ? delays[attempt]
        : fallbackDelay;
    final delay = configuredDelay <= remainingTimeout
        ? configuredDelay
        : remainingTimeout;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (!ref.mounted) {
      return;
    }
    final lifecycle = ref.read(checkoutPollingLifecycleProvider);
    if (!lifecycle.isResumed) {
      await lifecycle.waitUntilResumed();
    }
  }

  Future<void> cancelPremium() async {
    final keepAlive = ref.keepAlive();
    try {
      final context = await _captureSessionContext();
      final repository = ref.read(subscriptionRepositoryProvider);
      final currentState = _currentState();
      _publishIfSession(
        context,
        currentState.copyWith(isBusy: true, clearMessage: true),
      );
      final current = await repository.cancel();
      _publishCurrent(context, current);
      _publishIfSession(
        context,
        _currentState().copyWith(
          current: current,
          clearCurrent: current == null,
          clearPendingCheckout: true,
          isBusy: false,
          clearBusyPlanCode: true,
          message:
              'Assinatura premium cancelada. O plano essencial segue ativo.',
        ),
      );
    } finally {
      keepAlive.close();
    }
  }

  void clearMessage() {
    final currentState = state.asData?.value;
    if (currentState == null) {
      return;
    }
    state = AsyncData(currentState.copyWith(clearMessage: true));
  }

  SubscriptionScreenState _currentState() {
    return state.asData?.value ??
        const SubscriptionScreenState(plans: [], current: null);
  }

  Future<SubscriptionSessionContext> _captureSessionContext() async {
    final context = await ref
        .read(currentSubscriptionProvider.notifier)
        .sessionContext();
    if (context == null) {
      throw const SubscriptionCheckoutException('Sessao invalida.');
    }
    return context;
  }

  bool _isCurrentSession(SubscriptionSessionContext context) {
    if (!ref.mounted) {
      return false;
    }
    final session = ref.read(authControllerProvider).asData?.value;
    return session?.userId == context.userId &&
        ref.read(authSessionGenerationProvider) == context.generation;
  }

  void _publishCurrent(
    SubscriptionSessionContext context,
    CurrentSubscription? current,
  ) {
    ref
        .read(currentSubscriptionProvider.notifier)
        .publishForSession(
          expectedUserId: context.userId,
          expectedGeneration: context.generation,
          current: current,
        );
  }

  void _publishIfSession(
    SubscriptionSessionContext context,
    SubscriptionScreenState next,
  ) {
    if (_isCurrentSession(context)) {
      state = AsyncData(next);
    }
  }

  void _publishPendingCheckout(
    SubscriptionSessionContext context,
    CheckoutSession checkout,
  ) {
    if (!checkout.isPending) {
      return;
    }
    _publishIfSession(
      context,
      _currentState().copyWith(pendingCheckout: checkout, isBusy: true),
    );
  }

  String _friendlyCheckoutError(Object error) {
    final raw = error is StateError ? error.message : error.toString();
    final message = raw
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '')
        .trim();
    if (message.isEmpty ||
        message.contains('DioException') ||
        message.contains('StackTrace')) {
      return 'NÃ£o foi possÃ­vel processar a assinatura agora. Tente novamente em instantes.';
    }
    return message;
  }
}

class SubscriptionCheckoutException implements Exception {
  const SubscriptionCheckoutException(this.message);

  final String message;

  @override
  String toString() => message;
}
