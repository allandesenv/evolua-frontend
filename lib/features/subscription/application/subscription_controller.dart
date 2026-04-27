import 'dart:async';

import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final dio = ref.watch(authenticatedDioProvider(AppConfig.subscriptionBaseUrl));
  return SubscriptionRepositoryImpl(dio);
});

final subscriptionControllerProvider =
    AsyncNotifierProvider<SubscriptionController, SubscriptionScreenState>(
      SubscriptionController.new,
    );

class SubscriptionController extends AsyncNotifier<SubscriptionScreenState> {
  @override
  Future<SubscriptionScreenState> build() async {
    final repository = ref.watch(subscriptionRepositoryProvider);
    final plans = await repository.listPlans();
    final current = await repository.current();
    return SubscriptionScreenState(plans: plans, current: current);
  }

  Future<void> refresh() async {
    final currentState = state.asData?.value;
    state = AsyncData(
      (currentState ?? const SubscriptionScreenState(plans: [], current: null))
          .copyWith(isBusy: true, clearMessage: true),
    );
    state = await AsyncValue.guard(() async {
      final repository = ref.read(subscriptionRepositoryProvider);
      final plans = await repository.listPlans();
      final current = await repository.current();
      return SubscriptionScreenState(
        plans: plans,
        current: current,
        pendingCheckout: currentState?.pendingCheckout,
      );
    });
  }

  Future<CheckoutSession> startCheckout(String planCode) async {
    final repository = ref.read(subscriptionRepositoryProvider);
    final currentState =
        state.asData?.value ?? const SubscriptionScreenState(plans: [], current: null);
    state = AsyncData(currentState.copyWith(isBusy: true, clearMessage: true));
    final checkout = await repository.startCheckout(
      planCode: planCode,
      frontendBaseUrl: Uri.base.origin,
    );
    final refreshedCurrent = await repository.current();
    state = AsyncData(
      currentState.copyWith(
        current: refreshedCurrent,
        pendingCheckout: checkout,
        isBusy: false,
        message: checkout.isApproved
            ? 'Plano atualizado com sucesso.'
            : 'Checkout iniciado. Estamos aguardando a confirmacao do pagamento.',
      ),
    );
    return checkout;
  }

  Future<void> trackCheckout(String checkoutId) async {
    final repository = ref.read(subscriptionRepositoryProvider);
    var latestState =
        state.asData?.value ?? const SubscriptionScreenState(plans: [], current: null);
    state = AsyncData(latestState.copyWith(isBusy: true, clearMessage: true));

    CheckoutSession checkout = await repository.checkoutStatus(checkoutId);
    CurrentSubscription? current = await repository.current();

    var attempts = 0;
    while (checkout.isPending && attempts < 8) {
      await Future<void>.delayed(const Duration(seconds: 2));
      checkout = await repository.checkoutStatus(checkoutId);
      current = await repository.current();
      attempts++;
    }

    latestState = state.asData?.value ?? latestState;
    state = AsyncData(
      latestState.copyWith(
        current: current,
        pendingCheckout: checkout,
        isBusy: false,
        message: checkout.isApproved
            ? 'Pagamento confirmado e plano liberado.'
            : checkout.failureReason == null
            ? 'Ainda estamos confirmando o pagamento.'
            : 'Pagamento nao confirmado: ${checkout.failureReason}.',
      ),
    );
  }

  Future<void> cancelPremium() async {
    final repository = ref.read(subscriptionRepositoryProvider);
    final currentState =
        state.asData?.value ?? const SubscriptionScreenState(plans: [], current: null);
    state = AsyncData(currentState.copyWith(isBusy: true, clearMessage: true));
    final current = await repository.cancel();
    state = AsyncData(
      currentState.copyWith(
        current: current,
        clearPendingCheckout: true,
        isBusy: false,
        message: 'Assinatura premium cancelada. O plano essencial segue ativo.',
      ),
    );
  }

  void clearMessage() {
    final currentState = state.asData?.value;
    if (currentState == null) {
      return;
    }
    state = AsyncData(currentState.copyWith(clearMessage: true));
  }
}
