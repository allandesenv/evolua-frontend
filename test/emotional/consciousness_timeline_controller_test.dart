import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service_base.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/emotional/application/consciousness_timeline_controller.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test(
    'rewarded unlock uses full history resource and reloads timeline',
    () async {
      final adapter = _TimelineAdapter(fullAccessAfterFirstRequest: true);
      final rewarded = _FakeRewardedAdService(
        result: RewardedAdResult.rewarded,
      );
      final repository = _FakeSubscriptionRepository(
        accessStatuses: [_access(allowed: true, entitlement: true)],
      );
      final container = _container(
        adapter: adapter,
        rewarded: rewarded,
        repository: repository,
      );
      addTearDown(container.dispose);

      await container.read(consciousnessTimelineProvider.future);

      final unlocked = await container
          .read(consciousnessTimelineProvider.notifier)
          .unlockFullWithReward();

      expect(unlocked, isTrue);
      expect(rewarded.calls, 1);
      expect(rewarded.rewardTypes, [RewardResources.checkInHistoryFull]);
      expect(repository.accessResources, [RewardResources.checkInHistoryFull]);
      expect(adapter.timelineRequests, 2);
      expect(
        container.read(consciousnessTimelineProvider).value?.fullAccess,
        isTrue,
      );
    },
  );

  test(
    'timeout rechecks entitlement without firing another rewarded ad',
    () async {
      final adapter = _TimelineAdapter(fullAccessAfterFirstRequest: true);
      final rewarded = _FakeRewardedAdService(result: RewardedAdResult.timeout);
      final repository = _FakeSubscriptionRepository(
        accessStatuses: [_access(allowed: true, entitlement: true)],
      );
      final container = _container(
        adapter: adapter,
        rewarded: rewarded,
        repository: repository,
      );
      addTearDown(container.dispose);

      await container.read(consciousnessTimelineProvider.future);

      final unlocked = await container
          .read(consciousnessTimelineProvider.notifier)
          .unlockFullWithReward();

      expect(unlocked, isTrue);
      expect(rewarded.calls, 1);
      expect(repository.accessResources, [RewardResources.checkInHistoryFull]);
      expect(adapter.timelineRequests, 2);
    },
  );

  test(
    'reward confirmation pending rechecks entitlement without quota credits',
    () async {
      final adapter = _TimelineAdapter(fullAccessAfterFirstRequest: true);
      final rewarded = _FakeRewardedAdService(
        result: RewardedAdResult.rewardConfirmedButAccessDenied,
      );
      final repository = _FakeSubscriptionRepository(
        accessStatuses: [
          _access(
            allowed: false,
            entitlement: true,
            rewardedCreditsGrantedToday: 0,
            rewardedCreditsUsedToday: 0,
          ),
        ],
      );
      final container = _container(
        adapter: adapter,
        rewarded: rewarded,
        repository: repository,
      );
      addTearDown(container.dispose);

      await container.read(consciousnessTimelineProvider.future);

      final unlocked = await container
          .read(consciousnessTimelineProvider.notifier)
          .unlockFullWithReward();

      expect(unlocked, isTrue);
      expect(rewarded.calls, 1);
      expect(repository.accessResources, [RewardResources.checkInHistoryFull]);
      expect(adapter.timelineRequests, 2);
    },
  );

  test('load failure keeps preview locked', () async {
    final adapter = _TimelineAdapter(fullAccessAfterFirstRequest: true);
    final rewarded = _FakeRewardedAdService(
      result: RewardedAdResult.loadFailed,
    );
    final repository = _FakeSubscriptionRepository();
    final container = _container(
      adapter: adapter,
      rewarded: rewarded,
      repository: repository,
    );
    addTearDown(container.dispose);

    await container.read(consciousnessTimelineProvider.future);

    final unlocked = await container
        .read(consciousnessTimelineProvider.notifier)
        .unlockFullWithReward();

    expect(unlocked, isFalse);
    expect(rewarded.calls, 1);
    expect(repository.accessResources, isEmpty);
    expect(adapter.timelineRequests, 1);
  });
}

ProviderContainer _container({
  required _TimelineAdapter adapter,
  required _FakeRewardedAdService rewarded,
  required _FakeSubscriptionRepository repository,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ProviderContainer(
    overrides: [
      authenticatedDioProvider(
        AppConfig.emotionalBaseUrl,
      ).overrideWithValue(dio),
      rewardedAdServiceProvider.overrideWithValue(rewarded),
      subscriptionRepositoryProvider.overrideWithValue(repository),
      interstitialAdServiceProvider.overrideWithValue(
        _FakeInterstitialAdService(),
      ),
    ],
  );
}

MonetizationAccessStatus _access({
  required bool allowed,
  bool entitlement = false,
  int rewardedCreditsGrantedToday = 0,
  int rewardedCreditsUsedToday = 0,
}) {
  return MonetizationAccessStatus(
    resource: RewardResources.checkInHistoryFull,
    allowed: allowed,
    premium: false,
    rewardedAdAvailable: !allowed,
    upgradeRecommended: !allowed,
    entitlementExpiresAt: entitlement
        ? DateTime.now().add(const Duration(hours: 2))
        : null,
    rewardedCreditsGrantedToday: rewardedCreditsGrantedToday,
    rewardedCreditsUsedToday: rewardedCreditsUsedToday,
  );
}

Map<String, Object?> _item() {
  return {
    'checkInId': 1,
    'mood': 'calma',
    'energyLevel': 8,
    'title': 'Leitura',
    'insight': 'Insight',
    'identifiedState': 'presença',
    'revealingQuestion': 'Pergunta',
    'possibleNewState': 'Estado possível',
    'microAction': 'Ação',
    'reflection': 'Reflexão',
    'savedReading': false,
    'createdAt': DateTime(2026, 6, 8, 9, 30).toIso8601String(),
  };
}

class _TimelineAdapter implements HttpClientAdapter {
  _TimelineAdapter({required this.fullAccessAfterFirstRequest});

  final bool fullAccessAfterFirstRequest;
  int timelineRequests = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    timelineRequests += 1;
    final fullAccess = fullAccessAfterFirstRequest && timelineRequests > 1;
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'items': [_item()],
          'page': 0,
          'size': 20,
          'totalItems': 1,
          'totalPages': 1,
          'hasNext': false,
          'fullAccess': fullAccess,
          'premium': fullAccess,
          'rewardedAdAvailable': !fullAccess,
          'limitMessage': fullAccess ? null : 'Preview',
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _FakeRewardedAdService implements RewardedAdService {
  _FakeRewardedAdService({required this.result});

  final RewardedAdResult result;
  final List<String> rewardTypes = [];

  int get calls => rewardTypes.length;

  @override
  Future<RewardedAdResult> showRewardedAd({
    required String rewardType,
    String? contextId,
    void Function()? onAdClosed,
  }) async {
    rewardTypes.add(rewardType);
    return result;
  }
}

class _FakeInterstitialAdService implements InterstitialAdService {
  @override
  void dispose() {}

  @override
  Future<bool> maybeShow({
    required InterstitialTrigger trigger,
    required AuthSession? session,
  }) async {
    return false;
  }

  @override
  Future<void> preload() async {}

  @override
  Future<void> recordRewardedAdShown({AuthSession? session}) async {}
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({List<MonetizationAccessStatus>? accessStatuses})
    : _accessStatuses = List<MonetizationAccessStatus>.from(
        accessStatuses ?? const [],
      );

  final List<MonetizationAccessStatus> _accessStatuses;
  final List<String> accessResources = [];

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
  Future<AdRewardSession> grantClientOpenedReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> grantTestReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<PlanView>> listPlans() async => const [];

  @override
  Future<MonetizationAccessStatus> monetizationAccess({
    required String resource,
    String? contextId,
  }) async {
    accessResources.add(resource);
    if (_accessStatuses.isEmpty) {
      return _access(allowed: false);
    }
    return _accessStatuses.removeAt(0);
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
