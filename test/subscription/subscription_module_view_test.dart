import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:evolua_frontend/features/subscription/presentation/widgets/subscription_module_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'keeps existing plans and shows founder when catalog includes it',
    (tester) async {
      await _setDesktopSurface(tester);
      await tester.pumpWidget(
        _testApp(repository: _FakeSubscriptionRepository(plans: _plans())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Essencial'), findsWidgets);
      expect(find.text('Premium Mensal'), findsOneWidget);
      expect(find.text('Premium Anual'), findsOneWidget);
      expect(find.text('Fundador Evolua'), findsOneWidget);
      expect(find.text('Apoio inicial'), findsOneWidget);
      expect(find.text('R\$ 24,90/mes'), findsOneWidget);
      expect(find.text('Apoiar como fundador'), findsOneWidget);
    },
  );

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

  testWidgets('shows founder as current active premium plan without ads', (
    tester,
  ) async {
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
  });
}

Widget _testApp({required SubscriptionRepository repository}) {
  return ProviderScope(
    overrides: [subscriptionRepositoryProvider.overrideWithValue(repository)],
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
      benefits: ['Experiencia sem anuncios'],
      active: true,
      planFamily: 'PREMIUM',
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
        'Experiencia sem anuncios',
        'Acesso antecipado a novidades',
        'Participacao em enquetes e decisoes do produto',
        'Nome opcional como apoiador fundador',
        'Apoio direto a evolucao do app',
      ],
      active: true,
      planFamily: 'FOUNDER',
      badge: 'Apoio inicial',
      highlighted: true,
      availabilityNote:
          'Plano especial da fase inicial do Evolua. Ele pode ser alterado ou encerrado para novos assinantes no futuro, sempre com transparencia para apoiadores atuais.',
      providerProductId: 'evolua_founder',
      sortOrder: 30,
    ),
  ];
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  const _FakeSubscriptionRepository({
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
  Future<AdRewardSession> createRewardSession({
    required String rewardType,
    String? contextId,
  }) {
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
