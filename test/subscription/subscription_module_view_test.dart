import 'dart:async';

import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
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
  group('planCatalogProvider', () {
    test('deduplicates concurrent catalog reads', () async {
      final completer = Completer<List<PlanView>>();
      final repository = _FakeSubscriptionRepository(
        plans: _plans(),
        listPlansCompleter: completer,
      );
      final container = ProviderContainer(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final first = container.read(planCatalogProvider.future);
      final second = container.read(planCatalogProvider.future);

      expect(repository.listPlansCalls, 1);
      completer.complete(_plans());

      await expectLater(first, completion(hasLength(_plans().length)));
      await expectLater(second, completion(hasLength(_plans().length)));
      expect(repository.listPlansCalls, 1);
    });

    test('keeps catalog across users while TTL is valid', () async {
      var now = DateTime(2026, 1, 1, 10);
      final repository = _FakeSubscriptionRepository(plans: _plans());
      final authController = _MutableFakeAuthController(userId: 'user-a');
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => authController),
          subscriptionRepositoryProvider.overrideWithValue(repository),
          planCatalogClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      await container.read(planCatalogProvider.future);
      authController.switchUser('user-b');
      container.read(authSessionGenerationProvider.notifier).bump();
      now = now.add(const Duration(hours: 11, minutes: 59));

      await container.read(planCatalogProvider.notifier).load();

      expect(repository.listPlansCalls, 1);
    });

    test(
      'expires after 12 hours and failed refresh does not renew loadedAt',
      () async {
        var now = DateTime(2026, 1, 1, 10);
        final repository = _FakeSubscriptionRepository(plans: _plans());
        final container = ProviderContainer(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(repository),
            planCatalogClockProvider.overrideWithValue(() => now),
          ],
        );
        addTearDown(container.dispose);

        await container.read(planCatalogProvider.future);
        final firstLoadedAt = container
            .read(planCatalogProvider.notifier)
            .loadedAtForTesting;

        now = now.add(const Duration(hours: 12, seconds: 1));
        repository.listPlansError = StateError('catalog unavailable');

        Object? thrown;
        try {
          await container.read(planCatalogProvider.notifier).load();
        } catch (error) {
          thrown = error;
        }
        expect(thrown, isA<StateError>());

        expect(repository.listPlansCalls, 2);
        expect(
          container.read(planCatalogProvider.notifier).loadedAtForTesting,
          firstLoadedAt,
        );

        repository.listPlansError = null;
        now = now.add(const Duration(minutes: 1));
        await container.read(planCatalogProvider.notifier).load(force: true);

        expect(repository.listPlansCalls, 3);
        expect(
          container.read(planCatalogProvider.notifier).loadedAtForTesting,
          now,
        );
      },
    );

    test(
      'documents catalog is not localized by language in current backend contract',
      () async {
        final repository = _FakeSubscriptionRepository(plans: _plans());
        final container = ProviderContainer(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(planCatalogProvider.future);
        await container.read(planCatalogProvider.notifier).load();

        expect(repository.listPlansCalls, 1);
      },
    );
  });

  group('currentSubscriptionProvider', () {
    test('does not request current subscription without user', () async {
      final repository = _FakeSubscriptionRepository(plans: _plans());
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => _FakeAuthController(null)),
          subscriptionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(currentSubscriptionProvider.future),
        completion(isNull),
      );
      expect(repository.currentCalls, 0);
    });

    test(
      'ignores stale publication after user or generation changes',
      () async {
        final repository = _FakeSubscriptionRepository(
          plans: _plans(),
          currentSubscription: _premiumSubscription,
        );
        final authController = _MutableFakeAuthController(userId: 'user-a');
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(() => authController),
            subscriptionRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(currentSubscriptionProvider.future);
        final oldGeneration = container.read(authSessionGenerationProvider);

        authController.switchUser('user-b');
        container.read(authSessionGenerationProvider.notifier).bump();
        container
            .read(currentSubscriptionProvider.notifier)
            .publishForSession(
              expectedUserId: 'user-a',
              expectedGeneration: oldGeneration,
              current: null,
            );

        expect(
          container.read(currentSubscriptionProvider).asData?.value?.premium,
          isTrue,
        );
      },
    );

    test(
      'refresh preserves last premium value on error and deduplicates calls',
      () async {
        final repository = _FakeSubscriptionRepository(
          plans: _plans(),
          currentSubscription: _premiumSubscription,
        );
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              () => _MutableFakeAuthController(userId: 'user-a'),
            ),
            subscriptionRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(currentSubscriptionProvider.future);
        expect(repository.currentCalls, 1);

        final completer = Completer<CurrentSubscription?>();
        repository.currentCompleter = completer;
        final first = container
            .read(currentSubscriptionProvider.notifier)
            .refresh();
        final second = container
            .read(currentSubscriptionProvider.notifier)
            .refresh();
        await Future<void>.delayed(Duration.zero);
        expect(repository.currentCalls, 2);
        completer.complete(_premiumSubscription);
        await Future.wait([first, second]);
        expect(repository.currentCalls, 2);

        repository.currentCompleter = null;
        repository.currentError = StateError('temporary');
        await expectLater(
          container.read(currentSubscriptionProvider.notifier).refresh(),
          throwsStateError,
        );

        expect(
          container.read(currentSubscriptionProvider).asData?.value?.premium,
          isTrue,
        );
      },
    );

    test(
      'can publish null after successful cancel for the same session',
      () async {
        final repository = _FakeSubscriptionRepository(
          plans: _plans(),
          currentSubscription: _premiumSubscription,
        );
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              () => _MutableFakeAuthController(userId: 'user-a'),
            ),
            subscriptionRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(currentSubscriptionProvider.future);
        final context = await container
            .read(currentSubscriptionProvider.notifier)
            .sessionContext();

        container
            .read(currentSubscriptionProvider.notifier)
            .publishForSession(
              expectedUserId: context!.userId,
              expectedGeneration: context.generation,
              current: null,
            );

        expect(
          container.read(currentSubscriptionProvider).asData?.value,
          isNull,
        );
      },
    );
  });

  test('subscription screen refresh reuses catalog inside TTL', () async {
    final repository = _FakeSubscriptionRepository(plans: _plans());
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _MutableFakeAuthController(userId: 'user-a'),
        ),
        subscriptionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(subscriptionControllerProvider.future);
    repository.resetCounters();

    await container.read(subscriptionControllerProvider.notifier).refresh();

    expect(repository.currentCalls, 1);
    expect(repository.listPlansCalls, 0);
  });

  group('trackCheckout polling', () {
    test('approved on third status calls current only once', () async {
      final repository = _FakeSubscriptionRepository(
        plans: _plans(),
        checkoutStatuses: [
          _checkout('checkout-1', status: 'PENDING_PAYMENT'),
          _checkout('checkout-1', status: 'PENDING_PAYMENT'),
          _checkout('checkout-1', status: 'APPROVED'),
        ],
      );
      final container = _subscriptionContainer(repository);
      addTearDown(container.dispose);
      await container.read(subscriptionControllerProvider.future);
      repository.resetCounters();

      await container
          .read(subscriptionControllerProvider.notifier)
          .trackCheckout('checkout-1');

      expect(repository.checkoutStatusCalls, 3);
      expect(repository.currentCalls, 1);
      final state = container
          .read(subscriptionControllerProvider)
          .asData!
          .value;
      expect(state.pendingCheckout?.isApproved, isTrue);
      expect(state.isBusy, isFalse);
      expect(state.message, 'Pagamento confirmado e plano liberado.');
    });

    test('simultaneous calls for same checkout share polling', () async {
      final firstStatus = Completer<CheckoutSession>();
      final repository = _FakeSubscriptionRepository(
        plans: _plans(),
        checkoutStatusCompleter: firstStatus,
        checkoutStatuses: [_checkout('checkout-1', status: 'APPROVED')],
      );
      final container = _subscriptionContainer(repository);
      addTearDown(container.dispose);
      await container.read(subscriptionControllerProvider.future);
      repository.resetCounters();

      final first = container
          .read(subscriptionControllerProvider.notifier)
          .trackCheckout('checkout-1');
      final second = container
          .read(subscriptionControllerProvider.notifier)
          .trackCheckout('checkout-1');
      await Future<void>.delayed(Duration.zero);

      expect(repository.checkoutStatusCalls, 1);
      firstStatus.complete(_checkout('checkout-1', status: 'PENDING_PAYMENT'));
      await Future.wait([first, second]);

      expect(repository.checkoutStatusCalls, 2);
      expect(repository.currentCalls, 1);
    });

    test(
      'final rejected checkout stops polling and refreshes current once',
      () async {
        final repository = _FakeSubscriptionRepository(
          plans: _plans(),
          checkoutStatuses: [
            _checkout('checkout-1', status: 'PENDING_PAYMENT'),
            _checkout(
              'checkout-1',
              status: 'REJECTED',
              failureReason: 'cartao recusado',
            ),
          ],
        );
        final container = _subscriptionContainer(repository);
        addTearDown(container.dispose);
        await container.read(subscriptionControllerProvider.future);
        repository.resetCounters();

        await container
            .read(subscriptionControllerProvider.notifier)
            .trackCheckout('checkout-1');

        expect(repository.checkoutStatusCalls, 2);
        expect(repository.currentCalls, 1);
        final state = container
            .read(subscriptionControllerProvider)
            .asData!
            .value;
        expect(state.pendingCheckout?.status, 'REJECTED');
        expect(state.message, contains('cartao recusado'));
      },
    );

    test('timeout keeps pending checkout and refreshes current once', () async {
      final repository = _FakeSubscriptionRepository(
        plans: _plans(),
        checkoutStatuses: [_checkout('checkout-1', status: 'PENDING_PAYMENT')],
      );
      final container = _subscriptionContainer(
        repository,
        timeout: Duration.zero,
      );
      addTearDown(container.dispose);
      await container.read(subscriptionControllerProvider.future);
      repository.resetCounters();

      await container
          .read(subscriptionControllerProvider.notifier)
          .trackCheckout('checkout-1');

      expect(repository.checkoutStatusCalls, 1);
      expect(repository.currentCalls, 1);
      final state = container
          .read(subscriptionControllerProvider)
          .asData!
          .value;
      expect(state.pendingCheckout?.isPending, isTrue);
      expect(state.isBusy, isFalse);
      expect(state.message, 'Ainda estamos confirmando o pagamento.');
    });

    test('pending checkout remains visible while polling continues', () async {
      final secondStatus = Completer<CheckoutSession>();
      final repository = _FakeSubscriptionRepository(
        plans: _plans(),
        checkoutStatusResponses: [
          _checkout('checkout-1', status: 'PENDING_PAYMENT'),
          secondStatus.future,
        ],
      );
      final container = _subscriptionContainer(repository);
      addTearDown(container.dispose);
      await container.read(subscriptionControllerProvider.future);
      repository.resetCounters();

      final tracking = container
          .read(subscriptionControllerProvider.notifier)
          .trackCheckout('checkout-1');
      await Future<void>.delayed(Duration.zero);

      final pendingState = container
          .read(subscriptionControllerProvider)
          .asData!
          .value;
      expect(pendingState.pendingCheckout?.isPending, isTrue);
      expect(pendingState.isBusy, isTrue);
      expect(repository.currentCalls, 0);

      secondStatus.complete(_checkout('checkout-1', status: 'APPROVED'));
      await tracking;
    });

    test(
      'disposed controller does not publish after polling resumes',
      () async {
        final secondStatus = Completer<CheckoutSession>();
        final repository = _FakeSubscriptionRepository(
          plans: _plans(),
          checkoutStatusResponses: [
            _checkout('checkout-1', status: 'PENDING_PAYMENT'),
            secondStatus.future,
          ],
        );
        final container = _subscriptionContainer(repository);
        await container.read(subscriptionControllerProvider.future);
        repository.resetCounters();

        final tracking = container
            .read(subscriptionControllerProvider.notifier)
            .trackCheckout('checkout-1');
        await Future<void>.delayed(Duration.zero);
        container.dispose();
        secondStatus.complete(_checkout('checkout-1', status: 'APPROVED'));

        await tracking;
        expect(repository.currentCalls, 0);
      },
    );

    test(
      'background lifecycle pauses status calls and resumes safely',
      () async {
        final lifecycle = _FakeCheckoutPollingLifecycle(resumed: false);
        final repository = _FakeSubscriptionRepository(
          plans: _plans(),
          checkoutStatuses: [
            _checkout('checkout-1', status: 'PENDING_PAYMENT'),
            _checkout('checkout-1', status: 'APPROVED'),
          ],
        );
        final container = _subscriptionContainer(
          repository,
          lifecycle: lifecycle,
        );
        addTearDown(container.dispose);
        await container.read(subscriptionControllerProvider.future);
        repository.resetCounters();

        final tracking = container
            .read(subscriptionControllerProvider.notifier)
            .trackCheckout('checkout-1');
        await Future<void>.delayed(Duration.zero);

        expect(repository.checkoutStatusCalls, 1);
        lifecycle.resume();
        await tracking;

        expect(repository.checkoutStatusCalls, 2);
        expect(repository.currentCalls, 1);
      },
    );
  });

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

  testWidgets('starts Google Play checkout on Android yearly tap', (
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

    await tester.tap(find.text('Evoluir continuamente'));
    await tester.pumpAndSettle();

    expect(googlePlay.startedProductIds, ['premium_anual']);
    expect(repository.verifiedProductIds, ['premium_anual']);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('starts Google Play checkout on Android founder tap', (
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

    await tester.ensureVisible(find.text('Apoiar como fundador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apoiar como fundador'));
    await tester.pumpAndSettle();

    expect(googlePlay.startedProductIds, ['evolua_founder']);
    expect(repository.verifiedProductIds, ['evolua_founder']);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'keeps Android checkout dynamic and fails gracefully without product id',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _setDesktopSurface(tester);

      final plans = _plans()
          .map(
            (plan) => plan.planCode == 'premium-monthly'
                ? const PlanView(
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
                    sortOrder: 10,
                  )
                : plan,
          )
          .toList();
      await tester.pumpWidget(
        _testApp(
          repository: _FakeSubscriptionRepository(plans: plans),
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

  testWidgets('Google Play checkout does not perform extra current sync', (
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

    repository.resetCounters();
    await tester.tap(find.text('Aprofundar jornada'));
    await tester.pumpAndSettle();

    expect(repository.verifiedProductIds, ['premium_mensal']);
    expect(repository.currentCalls, 1);
    debugDefaultTargetPlatformOverride = null;
  });
}

Widget _testApp({
  required SubscriptionRepository repository,
  GooglePlayBillingGateway? googlePlayBilling,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => _MutableFakeAuthController(userId: 'user-123'),
      ),
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

ProviderContainer _subscriptionContainer(
  _FakeSubscriptionRepository repository, {
  Duration timeout = const Duration(seconds: 30),
  CheckoutPollingLifecycle? lifecycle,
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(
        () => _MutableFakeAuthController(userId: 'user-123'),
      ),
      subscriptionRepositoryProvider.overrideWithValue(repository),
      checkoutPollingDelaysProvider.overrideWithValue(const [Duration.zero]),
      checkoutPollingTimeoutProvider.overrideWithValue(timeout),
      checkoutPollingLifecycleProvider.overrideWithValue(
        lifecycle ?? _FakeCheckoutPollingLifecycle(),
      ),
    ],
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

const _freeSubscription = CurrentSubscription(
  planCode: 'essential-free',
  status: 'ACTIVE',
  billingCycle: 'MONTHLY',
  premium: false,
  adsEnabled: true,
  aiQuotaRemainingToday: 1,
  mentorPremiumPassActive: false,
  mentorRewardedAdAvailable: false,
);

const _premiumSubscription = CurrentSubscription(
  planCode: 'premium-monthly',
  status: 'ACTIVE',
  billingCycle: 'MONTHLY',
  premium: true,
  adsEnabled: false,
  aiQuotaRemainingToday: 10,
  mentorPremiumPassActive: false,
  mentorRewardedAdAvailable: false,
);

CheckoutSession _checkout(
  String id, {
  required String status,
  String? failureReason,
}) {
  return CheckoutSession(
    id: id,
    planCode: 'premium-monthly',
    billingCycle: 'MONTHLY',
    status: status,
    premium: true,
    failureReason: failureReason,
  );
}

class _FakeCheckoutPollingLifecycle implements CheckoutPollingLifecycle {
  _FakeCheckoutPollingLifecycle({bool resumed = true}) : _resumed = resumed;

  bool _resumed;
  Completer<void>? _resumeCompleter;

  @override
  bool get isResumed => _resumed;

  @override
  Future<void> waitUntilResumed() {
    if (_resumed) {
      return Future<void>.value();
    }
    return (_resumeCompleter ??= Completer<void>()).future;
  }

  void resume() {
    _resumed = true;
    final completer = _resumeCompleter;
    _resumeCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this.session);

  final AuthSession? session;

  @override
  Future<AuthSession?> build() async => session;
}

class _MutableFakeAuthController extends AuthController {
  _MutableFakeAuthController({required String userId}) : _userId = userId;

  String _userId;

  @override
  Future<AuthSession?> build() async => _session();

  void switchUser(String userId) {
    _userId = userId;
    state = AsyncData(_session());
  }

  AuthSession _session() {
    return AuthSession(
      userId: _userId,
      email: '$_userId@evolua.test',
      roles: const ['ROLE_USER'],
      accessToken: 'test-token',
    );
  }
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
    this.currentSubscription = _freeSubscription,
    this.listPlansCompleter,
    this.checkoutStatusCompleter,
    List<CheckoutSession>? checkoutStatuses,
    List<FutureOr<CheckoutSession>>? checkoutStatusResponses,
  }) : checkoutStatusResponses =
           checkoutStatusResponses ??
           [
             if (checkoutStatusCompleter != null)
               checkoutStatusCompleter.future,
             ...?checkoutStatuses,
           ];

  final List<PlanView> plans;
  final List<FutureOr<CheckoutSession>> checkoutStatusResponses;
  CurrentSubscription? currentSubscription;
  Completer<List<PlanView>>? listPlansCompleter;
  Completer<CurrentSubscription?>? currentCompleter;
  Completer<CheckoutSession>? checkoutStatusCompleter;
  Object? listPlansError;
  Object? currentError;
  int listPlansCalls = 0;
  int currentCalls = 0;
  int cancelCalls = 0;
  int checkoutStatusCalls = 0;
  final List<String> verifiedProductIds = [];

  @override
  Future<List<PlanView>> listPlans() async {
    listPlansCalls++;
    final error = listPlansError;
    if (error != null) {
      throw error;
    }
    final completer = listPlansCompleter;
    if (completer != null) {
      listPlansCompleter = null;
      return completer.future;
    }
    return plans;
  }

  @override
  Future<CurrentSubscription?> current() async {
    currentCalls++;
    final error = currentError;
    if (error != null) {
      throw error;
    }
    final completer = currentCompleter;
    if (completer != null) {
      currentCompleter = null;
      return completer.future;
    }
    return currentSubscription;
  }

  @override
  Future<CurrentSubscription?> cancel() async {
    cancelCalls++;
    return currentSubscription;
  }

  @override
  Future<CheckoutSession> checkoutStatus(String checkoutId) async {
    checkoutStatusCalls++;
    if (checkoutStatusResponses.isNotEmpty) {
      final response = checkoutStatusResponses.removeAt(0);
      if (response is Future<CheckoutSession>) {
        return response;
      }
      return response;
    }
    return _checkout(checkoutId, status: 'PENDING_PAYMENT');
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
  Future<AdRewardSession> grantClientOpenedReward(String sessionId) {
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

  void resetCounters() {
    listPlansCalls = 0;
    currentCalls = 0;
    cancelCalls = 0;
    checkoutStatusCalls = 0;
  }
}
