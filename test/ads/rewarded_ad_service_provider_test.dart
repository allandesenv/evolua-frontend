import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _subscriptionRepositoryOverrideProvider =
    NotifierProvider<_SubscriptionRepositoryOverride, SubscriptionRepository>(
      _SubscriptionRepositoryOverride.new,
    );

void main() {
  test('rebuilds rewarded service when subscription repository changes', () {
    final repositoryA = _FakeSubscriptionRepository('A');
    final repositoryB = _FakeSubscriptionRepository('B');
    final container = ProviderContainer(
      overrides: [
        subscriptionRepositoryProvider.overrideWith(
          (ref) => ref.watch(_subscriptionRepositoryOverrideProvider),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(_subscriptionRepositoryOverrideProvider.notifier)
        .set(repositoryA);
    final firstService = container.read(rewardedAdServiceProvider);
    container
        .read(_subscriptionRepositoryOverrideProvider.notifier)
        .set(repositoryB);
    final secondService = container.read(rewardedAdServiceProvider);

    expect(identical(firstService, secondService), isFalse);
  });

  test('rebuilds rewarded service when auth session generation changes', () {
    final repository = _FakeSubscriptionRepository('current');
    final container = ProviderContainer(
      overrides: [subscriptionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final firstService = container.read(rewardedAdServiceProvider);
    container.read(authSessionGenerationProvider.notifier).bump();
    final secondService = container.read(rewardedAdServiceProvider);

    expect(identical(firstService, secondService), isFalse);
  });
}

class _SubscriptionRepositoryOverride extends Notifier<SubscriptionRepository> {
  @override
  SubscriptionRepository build() {
    return const _FakeSubscriptionRepository('initial');
  }

  void set(SubscriptionRepository repository) {
    state = repository;
  }
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  const _FakeSubscriptionRepository(this.name);

  final String name;

  @override
  Future<CurrentSubscription?> cancel() {
    throw UnimplementedError();
  }

  @override
  Future<CheckoutSession> checkoutStatus(String checkoutId) {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> createRewardSession({
    required String rewardType,
    String? contextId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CurrentSubscription?> current() {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> grantClientOpenedReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> grantTestReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<PlanView>> listPlans() {
    throw UnimplementedError();
  }

  @override
  Future<MonetizationAccessStatus> monetizationAccess({
    required String resource,
    String? contextId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CheckoutSession> startCheckout({
    required String planCode,
    required String frontendBaseUrl,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CheckoutSession> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    required String packageName,
    required String planCode,
  }) {
    throw UnimplementedError();
  }
}
