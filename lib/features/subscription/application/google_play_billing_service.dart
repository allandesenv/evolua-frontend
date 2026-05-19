import 'dart:async';

import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

final googlePlayBillingServiceProvider = Provider<GooglePlayBillingService>(
  (ref) => GooglePlayBillingService(InAppPurchase.instance),
);

class GooglePlayBillingService {
  GooglePlayBillingService(this._iap);

  static const packageName = 'br.com.zenithit.evolua';

  final InAppPurchase _iap;

  Future<CheckoutSession> buyPremium({
    required PlanView plan,
    required SubscriptionRepository repository,
  }) async {
    final productId = plan.providerProductId;
    if (productId == null || productId.isEmpty) {
      throw StateError('Produto Google Play não configurado para este plano.');
    }
    final available = await _iap.isAvailable();
    if (!available) {
      throw StateError('Google Play Billing não está disponível neste aparelho.');
    }
    final products = await _iap.queryProductDetails({productId});
    if (products.error != null) {
      throw StateError(products.error!.message);
    }
    if (products.productDetails.isEmpty) {
      throw StateError('Produto $productId não encontrado no Google Play.');
    }

    final purchase = _waitForPurchase(productId);
    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: products.productDetails.first),
    );
    if (!started) {
      throw StateError('Não foi possível iniciar o checkout do Google Play.');
    }
    final details = await purchase;
    if (details.status == PurchaseStatus.error) {
      throw StateError(details.error?.message ?? 'Compra não concluída.');
    }
    if (details.status == PurchaseStatus.canceled) {
      throw StateError('Compra cancelada.');
    }
    final checkout = await repository.verifyGooglePlayPurchase(
      productId: productId,
      purchaseToken: details.verificationData.serverVerificationData,
      packageName: packageName,
      planCode: plan.planCode,
    );
    if (details.pendingCompletePurchase) {
      await _iap.completePurchase(details);
    }
    return checkout;
  }

  Future<PurchaseDetails> _waitForPurchase(String productId) {
    late StreamSubscription<List<PurchaseDetails>> subscription;
    final completer = Completer<PurchaseDetails>();
    subscription = _iap.purchaseStream.listen((items) {
      for (final item in items) {
        if (item.productID == productId &&
            (item.status == PurchaseStatus.purchased ||
                item.status == PurchaseStatus.restored ||
                item.status == PurchaseStatus.error ||
                item.status == PurchaseStatus.canceled)) {
          if (!completer.isCompleted) {
            completer.complete(item);
          }
        }
      }
    });
    return completer.future
        .timeout(const Duration(minutes: 5))
        .whenComplete(subscription.cancel);
  }
}
