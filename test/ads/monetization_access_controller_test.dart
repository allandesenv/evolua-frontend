import 'package:evolua_frontend/features/ads/application/monetization_access_controller.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not grant access when rewarded ad is not confirmed', () async {
    final repository = _FakeSubscriptionRepository(accessAllowed: true);
    final container = ProviderContainer(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(repository),
        rewardedAdServiceProvider.overrideWithValue(
          _FakeRewardedAdService(result: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final unlocked = await container
        .read(monetizationAccessControllerProvider.notifier)
        .unlockWithRewardedAd(resource: 'ADVANCED_MIRROR');

    expect(unlocked, isFalse);
    expect(repository.accessCalls, 0);
  });

  test('grants access after rewarded ad and refreshed entitlement', () async {
    final repository = _FakeSubscriptionRepository(accessAllowed: true);
    final rewarded = _FakeRewardedAdService(result: true);
    final container = ProviderContainer(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(repository),
        rewardedAdServiceProvider.overrideWithValue(rewarded),
      ],
    );
    addTearDown(container.dispose);

    final unlocked = await container
        .read(monetizationAccessControllerProvider.notifier)
        .unlockWithRewardedAd(resource: 'ADVANCED_MIRROR');

    expect(unlocked, isTrue);
    expect(rewarded.rewardType, 'ADVANCED_MIRROR');
    expect(repository.accessCalls, 1);
  });
}

class _FakeRewardedAdService implements RewardedAdService {
  _FakeRewardedAdService({required this.result});

  final bool result;
  String? rewardType;

  @override
  Future<bool> showRewardedAd({
    required String rewardType,
    String? contextId,
    bool allowClientOpenedFallback = false,
    void Function()? onAdClosed,
  }) async {
    this.rewardType = rewardType;
    return result;
  }
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({required this.accessAllowed});

  final bool accessAllowed;
  int accessCalls = 0;

  @override
  Future<CurrentSubscription?> cancel() async => null;

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
  Future<CurrentSubscription?> current() async => null;

  @override
  Future<AdRewardSession> grantTestReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> grantClientOpenedReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<PlanView>> listPlans() async => const [];

  @override
  Future<MonetizationAccessStatus> monetizationAccess({
    required String resource,
    String? contextId,
  }) async {
    accessCalls++;
    return MonetizationAccessStatus(
      resource: resource,
      contextId: contextId,
      allowed: accessAllowed,
      premium: false,
      rewardedAdAvailable: !accessAllowed,
      upgradeRecommended: !accessAllowed,
      entitlementExpiresAt: accessAllowed
          ? DateTime.now().add(const Duration(hours: 2))
          : null,
    );
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
