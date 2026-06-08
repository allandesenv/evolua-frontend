import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/emotional/presentation/pages/consciousness_timeline_page.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows free preview and opens item detail', (tester) async {
    final adapter = _TimelineAdapter(
      fullAccess: false,
      rewardedAdAvailable: true,
      pages: [
        [_item(title: 'Quando o corpo pede pausa')],
      ],
    );

    await tester.pumpWidget(_app(adapter: adapter));
    await tester.pumpAndSettle();

    expect(find.text('Linha do Tempo da Consciência'), findsOneWidget);
    expect(find.text('Ver histórico completo'), findsOneWidget);
    expect(find.text('Quando o corpo pede pausa'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -280));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quando o corpo pede pausa'));
    await tester.pumpAndSettle();

    expect(find.text('Detalhes da leitura'), findsOneWidget);
    expect(find.text('O que você registrou'), findsOneWidget);
    expect(find.text('Leitura do seu momento'), findsOneWidget);
    expect(
      find.text('Parece haver um movimento de cuidado com você.'),
      findsOneWidget,
    );
  });

  testWidgets('applies filters and loads next page for premium history', (
    tester,
  ) async {
    final adapter = _TimelineAdapter(
      fullAccess: true,
      premium: true,
      pages: [
        [_item(title: 'Primeira leitura')],
        [_item(checkInId: 2, title: 'Segunda leitura')],
      ],
    );

    await tester.pumpWidget(_app(adapter: adapter));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'calma');
    await tester.tap(find.text('Alta'));
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();

    expect(adapter.lastQuery['mood'], 'calma');
    expect(adapter.lastQuery['energyRange'], 'HIGH');

    expect(find.text('Primeira leitura'), findsOneWidget);
    expect(find.text('Carregar mais'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();

    expect(find.text('Segunda leitura'), findsOneWidget);
    expect(adapter.pagesRequested, containsAll([0, 1]));
  });

  testWidgets('reward failure keeps preview and shows friendly message', (
    tester,
  ) async {
    final adapter = _TimelineAdapter(
      fullAccess: false,
      rewardedAdAvailable: true,
      pages: [
        [_item(title: 'Preview livre')],
      ],
    );

    await tester.pumpWidget(
      _app(
        adapter: adapter,
        rewardedAdResult: false,
        accessAllowedAfterReward: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -280));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistir anúncio'));
    await tester.pumpAndSettle();

    expect(find.text('Preview livre'), findsOneWidget);
    expect(
      find.text(
        'Não conseguimos carregar o anúncio agora. Você ainda pode ver seus últimos registros ou tentar novamente em instantes.',
      ),
      findsOneWidget,
    );
  });
}

Widget _app({
  required _TimelineAdapter adapter,
  bool rewardedAdResult = true,
  bool accessAllowedAfterReward = false,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ProviderScope(
    overrides: [
      authenticatedDioProvider(
        AppConfig.emotionalBaseUrl,
      ).overrideWithValue(dio),
      rewardedAdServiceProvider.overrideWithValue(
        _FakeRewardedAdService(result: rewardedAdResult),
      ),
      subscriptionRepositoryProvider.overrideWithValue(
        _FakeSubscriptionRepository(accessAllowed: accessAllowedAfterReward),
      ),
    ],
    child: const MaterialApp(home: ConsciousnessTimelinePage()),
  );
}

Map<String, Object?> _item({int checkInId = 1, required String title}) {
  return {
    'checkInId': checkInId,
    'mood': 'calma',
    'energyLevel': 8,
    'title': title,
    'insight': 'Parece haver um movimento de cuidado com você.',
    'identifiedState': 'presença',
    'revealingQuestion': 'O que você pode escutar com mais calma hoje?',
    'possibleNewState': 'Eu posso me perceber com mais gentileza.',
    'microAction': 'Respirar por dois minutos antes da próxima decisão.',
    'reflection': 'Hoje percebi que precisava desacelerar.',
    'savedReading': false,
    'createdAt': DateTime(2026, 6, 8, 9, 30).toIso8601String(),
  };
}

class _TimelineAdapter implements HttpClientAdapter {
  _TimelineAdapter({
    required this.pages,
    required this.fullAccess,
    this.premium = false,
    this.rewardedAdAvailable = false,
  });

  final List<List<Map<String, Object?>>> pages;
  final bool fullAccess;
  final bool premium;
  final bool rewardedAdAvailable;
  final List<int> pagesRequested = [];
  Map<String, dynamic> lastQuery = const {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastQuery = Map<String, dynamic>.from(options.queryParameters);
    final page = int.tryParse(options.queryParameters['page'].toString()) ?? 0;
    pagesRequested.add(page);
    final items = page >= 0 && page < pages.length
        ? pages[page]
        : const <Map<String, Object?>>[];
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'items': items,
          'page': page,
          'size': 20,
          'totalItems': pages.fold<int>(
            0,
            (total, pageItems) => total + pageItems.length,
          ),
          'totalPages': pages.length,
          'hasNext': page < pages.length - 1,
          'fullAccess': fullAccess,
          'premium': premium,
          'rewardedAdAvailable': rewardedAdAvailable,
          'limitMessage': fullAccess
              ? null
              : 'Você está vendo seus registros mais recentes.',
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
  const _FakeRewardedAdService({required this.result});

  final bool result;

  @override
  Future<bool> showRewardedAd({
    required String rewardType,
    String? contextId,
    bool allowClientOpenedFallback = false,
    void Function()? onAdClosed,
  }) async {
    return result;
  }
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  const _FakeSubscriptionRepository({required this.accessAllowed});

  final bool accessAllowed;

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
    return MonetizationAccessStatus(
      resource: resource,
      contextId: contextId,
      allowed: accessAllowed,
      premium: accessAllowed,
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
