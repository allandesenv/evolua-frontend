import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/subscription/application/google_play_billing_service.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:evolua_frontend/features/subscription/presentation/widgets/subscription_module_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'keeps existing plans and shows prices without raw technical labels',
    (tester) async {
      await _setDesktopSurface(tester);
      await tester.pumpWidget(
        _testApp(
          repository: _FakeSubscriptionRepository(
            plans: _plans(),
            currentSubscription: const CurrentSubscription(
              planCode: 'essential-free',
              status: 'NONE',
              billingCycle: 'MONTHLY',
              premium: false,
              adsEnabled: true,
              aiQuotaRemainingToday: 1,
              mentorPremiumPassActive: false,
              mentorRewardedAdAvailable: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Essencial'), findsWidgets);
      expect(find.text('Premium Mensal'), findsOneWidget);
      expect(find.text('Premium Anual'), findsOneWidget);
      expect(find.text('Fundador Evolua'), findsOneWidget);
      expect(find.text('Apoio inicial'), findsOneWidget);
      expect(find.text('R\$ 24,90/mês'), findsOneWidget);
      expect(find.text('R\$ 24,90/mes'), findsNothing);
      expect(find.textContaining('NONE'), findsNothing);
      expect(find.textContaining('Status:'), findsNothing);
      expect(find.text('Apoiar como fundador'), findsOneWidget);
    },
  );

  testWidgets('does not render monetization principle badges', (tester) async {
    await _setDesktopSurface(tester);
    await tester.pumpWidget(
      _testApp(repository: _FakeSubscriptionRepository(plans: _plans())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Free útil, sem pressão'), findsNothing);
    expect(find.text('Premium sem anúncios'), findsNothing);
    expect(find.text('Anúncios só em áreas neutras'), findsNothing);
  });

  testWidgets(
    'does not render founder card when feature flag hides it in catalog',
    (tester) async {
      await _setDesktopSurface(tester);
      await tester.pumpWidget(
        _testApp(
          repository: _FakeSubscriptionRepository(
            plans: _plans().where((plan) => !plan.isFounder).toList(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Premium Mensal'), findsOneWidget);
      expect(find.text('Premium Anual'), findsOneWidget);
      expect(find.text('Fundador Evolua'), findsNothing);
    },
  );

  testWidgets(
    'shows founder as current active premium plan without raw status',
    (tester) async {
      await _setDesktopSurface(tester);
      await tester.pumpWidget(
        _testApp(
          repository: _FakeSubscriptionRepository(
            plans: _plans(),
            currentSubscription: const CurrentSubscription(
              planCode: 'evolua_founder_monthly',
              status: 'ACTIVE',
              billingCycle: 'MONTHLY',
              premium: true,
              adsEnabled: false,
              aiQuotaRemainingToday: 10,
              mentorPremiumPassActive: false,
              mentorRewardedAdAvailable: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fundador Evolua'), findsWidgets);
      expect(find.text('Plano ativo'), findsOneWidget);
      expect(
        find.textContaining('Seu Fundador Evolua está ativo'),
        findsOneWidget,
      );
      expect(find.textContaining('ACTIVE'), findsNothing);
    },
  );

  testWidgets('starts Google Play checkout on Android premium tap', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _setDesktopSurface(tester);

    final repository = _FakeSubscriptionRepository(plans: _plans());
    final googlePlay = _FakeGooglePlayBillingGateway();
    await tester.pumpWidget(
      _testApp(repository: repository, googlePlayBilling: googlePlay),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aprofundar jornada'));
    await tester.pumpAndSettle();

    expect(googlePlay.startedProductIds, ['premium_mensal']);
    expect(repository.verifiedProductIds, ['premium_mensal']);
    expect(find.text('Pagamento confirmado e plano liberado.'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    're-enables premium button and shows feedback on Google Play error',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _setDesktopSurface(tester);

      await tester.pumpWidget(
        _testApp(
          repository: _FakeSubscriptionRepository(plans: _plans()),
          googlePlayBilling: _FakeGooglePlayBillingGateway(
            error: StateError(
              'Produto Google Play não configurado para este plano.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aprofundar jornada'));
      await tester.pumpAndSettle();

      expect(
        find.text('Produto Google Play não configurado para este plano.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).at(1)).enabled,
        isTrue,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );
}

Widget _testApp({
  required SubscriptionRepository repository,
  GooglePlayBillingGateway? googlePlayBilling,
}) {
  return ProviderScope(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(repository),
      if (googlePlayBilling != null)
        googlePlayBillingServiceProvider.overrideWithValue(googlePlayBilling),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(accessibleFont: true),
      home: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: SubscriptionModuleView(),
        ),
      ),
    ),
  );
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1200));
  tester.view.physicalSize = const Size(1280, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

List<PlanView> _plans() {
  return const [
    PlanView(
      planCode: 'essential-free',
      title: 'Essencial',
      subtitle: 'Base gratuita do app.',
      billingCycle: 'MONTHLY',
      premium: false,
      price: 0,
      currency: 'BRL',
      benefits: ['Base gratuita'],
      active: true,
      planFamily: 'ESSENTIAL',
      sortOrder: 0,
    ),
    PlanView(
      planCode: 'premium-monthly',
      title: 'Premium Mensal',
      subtitle: 'Mais contexto emocional.',
      billingCycle: 'MONTHLY',
      premium: true,
      price: 14.9,
      currency: 'BRL',
      benefits: ['Experiência sem anúncios'],
      active: true,
      planFamily: 'PREMIUM',
      providerProductId: 'premium_mensal',
      sortOrder: 10,
    ),
    PlanView(
      planCode: 'premium-yearly',
      title: 'Premium Anual',
      subtitle: 'Continuidade por um ano.',
      billingCycle: 'YEARLY',
      premium: true,
      price: 119.9,
      currency: 'BRL',
      benefits: ['Valor reduzido no plano anual'],
      active: true,
      planFamily: 'PREMIUM',
      badge: 'Economize 33%',
      providerProductId: 'premium_anual',
      sortOrder: 20,
    ),
    PlanView(
      planCode: 'evolua_founder_monthly',
      title: 'Fundador Evolua',
      subtitle:
          'Apoie o Evolua nesta fase inicial e tenha acesso premium enquanto ajuda o projeto a crescer com sustentabilidade.',
      billingCycle: 'MONTHLY',
      premium: true,
      price: 24.9,
      currency: 'BRL',
      benefits: [
        'Tudo do Premium',
        'Experiência sem anúncios',
        'Acesso antecipado a novidades',
        'Participação em enquetes e decisões do produto',
        'Nome opcional como apoiador fundador',
        'Apoio direto à evolução do app',
      ],
      active: true,
      planFamily: 'FOUNDER',
      badge: 'Apoio inicial',
      highlighted: true,
      availabilityNote:
          'Plano especial da fase inicial do Evolua. Ele pode ser alterado ou encerrado para novos assinantes no futuro, sempre com transparência para apoiadores atuais.',
      providerProductId: 'evolua_founder',
      sortOrder: 30,
    ),
  ];
}

class _FakeGooglePlayBillingGateway implements GooglePlayBillingGateway {
  _FakeGooglePlayBillingGateway({this.error});

  final Object? error;
  final List<String> startedProductIds = [];

  @override
  Future<CheckoutSession> buyPremium({
    required PlanView plan,
    required SubscriptionRepository repository,
  }) async {
    if (error case final error?) {
      throw error;
    }
    startedProductIds.add(plan.providerProductId ?? '');
    return repository.verifyGooglePlayPurchase(
      productId: plan.providerProductId ?? '',
      purchaseToken: 'purchase-token',
      packageName: GooglePlayBillingService.packageName,
      planCode: plan.planCode,
    );
  }
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({
    required this.plans,
    this.currentSubscription = const CurrentSubscription(
      planCode: 'essential-free',
      status: 'ACTIVE',
      billingCycle: 'MONTHLY',
      premium: false,
      adsEnabled: true,
      aiQuotaRemainingToday: 1,
      mentorPremiumPassActive: false,
      mentorRewardedAdAvailable: false,
    ),
  });

  final List<PlanView> plans;
  final CurrentSubscription? currentSubscription;
  final List<String> verifiedProductIds = [];

  @override
  Future<List<PlanView>> listPlans() async => plans;

  @override
  Future<CurrentSubscription?> current() async => currentSubscription;

  @override
  Future<CurrentSubscription?> cancel() async => currentSubscription;

  @override
  Future<CheckoutSession> checkoutStatus(String checkoutId) {
    throw UnimplementedError();
  }

  @override
  Future<CheckoutSession> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    required String packageName,
    required String planCode,
  }) async {
    verifiedProductIds.add(productId);
    return CheckoutSession(
      id: 'google-play-$productId',
      planCode: planCode,
      billingCycle: planCode == 'premium-yearly' ? 'YEARLY' : 'MONTHLY',
      status: 'APPROVED',
      premium: true,
    );
  }

  @override
  Future<AdRewardSession> createRewardSession({
    required String rewardType,
    String? contextId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> grantTestReward(String sessionId) {
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
}
