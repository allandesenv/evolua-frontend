import 'dart:async';

import 'package:evolua_frontend/features/subscription/application/google_play_billing_service.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  const plan = PlanView(
    planCode: 'premium-monthly',
    title: 'Premium',
    subtitle: '',
    billingCycle: 'MONTHLY',
    premium: true,
    price: 1,
    currency: 'BRL',
    benefits: [],
    active: true,
    providerProductId: 'premium_mensal',
  );
  late _Store store;
  late _Repository repository;
  late GooglePlayBillingService service;

  setUp(() {
    store = _Store();
    repository = _Repository(store.events);
    service = GooglePlayBillingService(store);
  });
  tearDown(() => store.stream.close());

  for (final status in [PurchaseStatus.purchased, PurchaseStatus.restored]) {
    test(
      '$status verifies with backend before completing transaction',
      () async {
        store.status = status;
        final checkout = await service.buyPremium(
          plan: plan,
          repository: repository,
        );
        expect(checkout.isApproved, isTrue);
        expect(store.events, ['launch', 'verify', 'complete']);
        expect(repository.requests, 1);
        expect(repository.arguments, {
          'productId': 'premium_mensal',
          'purchaseToken': 'test-token',
          'packageName': 'br.com.zenithit.evolua',
          'planCode': 'premium-monthly',
        });
      },
    );
  }

  for (final status in [
    PurchaseStatus.canceled,
    PurchaseStatus.pending,
    PurchaseStatus.error,
  ]) {
    test('$status does not verify or complete transaction', () async {
      store.status = status;
      await expectLater(
        service.buyPremium(plan: plan, repository: repository),
        throwsStateError,
      );
      expect(repository.requests, 0);
      expect(store.events, ['launch']);
    });
  }

  test('backend failure leaves transaction unfinished', () async {
    repository.fail = true;
    await expectLater(
      service.buyPremium(plan: plan, repository: repository),
      throwsStateError,
    );
    expect(store.events, ['launch', 'verify']);
  });

  test(
    'already completed transaction is verified without another completion',
    () async {
      store.needsCompletion = false;
      await service.buyPremium(plan: plan, repository: repository);
      expect(store.events, ['launch', 'verify']);
    },
  );

  test('store unavailable does not launch checkout', () async {
    store.available = false;
    await expectLater(
      service.buyPremium(plan: plan, repository: repository),
      throwsStateError,
    );
    expect(store.events, isEmpty);
  });
}

class _Store implements InAppPurchase {
  final stream = StreamController<List<PurchaseDetails>>.broadcast();
  final events = <String>[];
  PurchaseStatus status = PurchaseStatus.purchased;
  bool needsCompletion = true;
  bool available = true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => stream.stream;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [
      ProductDetails(
        id: identifiers.single,
        title: 'Premium',
        description: '',
        price: 'R\$1',
        rawPrice: 1,
        currencyCode: 'BRL',
      ),
    ],
    notFoundIDs: [],
  );
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    events.add('launch');
    final purchase = PurchaseDetails(
      productID: purchaseParam.productDetails.id,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: 'test-token',
        source: 'google_play',
      ),
      transactionDate: null,
      status: status,
    )..pendingCompletePurchase = needsCompletion;
    stream.add([purchase]);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async =>
      events.add('complete');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements SubscriptionRepository {
  _Repository(this.events);
  final List<String> events;
  int requests = 0;
  bool fail = false;
  Map<String, String>? arguments;
  @override
  Future<CheckoutSession> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    required String packageName,
    required String planCode,
  }) async {
    requests++;
    events.add('verify');
    arguments = {
      'productId': productId,
      'purchaseToken': purchaseToken,
      'packageName': packageName,
      'planCode': planCode,
    };
    if (fail) throw StateError('Verification failed');
    return CheckoutSession(
      id: 'test',
      planCode: planCode,
      billingCycle: 'MONTHLY',
      status: 'APPROVED',
      premium: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
