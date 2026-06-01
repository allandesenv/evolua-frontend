import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_controller.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:evolua_frontend/features/future_message/domain/repositories/future_message_repository.dart';
import 'package:evolua_frontend/features/future_message/presentation/pages/future_messages_page.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('future message free text fields capitalize sentences', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          futureMessageRepositoryProvider.overrideWithValue(
            _FakeFutureMessageRepository(),
          ),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
        ],
        child: const MaterialApp(home: FutureMessagesPage()),
      ),
    );
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField));

    expect(fields, hasLength(4));
    expect(
      fields.map((field) => field.textCapitalization),
      everyElement(TextCapitalization.sentences),
    );
  });
}

class _FakeFutureMessageRepository implements FutureMessageRepository {
  @override
  Future<PaginatedResponse<FutureMessage>> delivered({
    required int page,
    required int size,
  }) async {
    return PaginatedResponse.empty(page: page, size: size);
  }

  @override
  Future<PaginatedResponse<FutureMessage>> list({
    required int page,
    required int size,
    List<String>? statuses,
  }) async {
    return PaginatedResponse.empty(page: page, size: size);
  }

  @override
  Future<void> heartbeat() async {}

  @override
  Future<FutureMessage> create(FutureMessageDraft draft) async {
    return FutureMessage(
      id: 1,
      title: draft.title,
      body: draft.body,
      bodyPreview: draft.body,
      triggerType: draft.triggerType,
      triggerConfig: draft.triggerConfig,
      triggerLabel: 'Em 30 dias',
      status: 'SCHEDULED',
      createdContext: const {},
      deliveredContext: const {},
      createdAt: DateTime(2026, 6, 1),
    );
  }

  @override
  Future<FutureMessage> get(int id) {
    throw UnimplementedError();
  }

  @override
  Future<FutureMessage> markRead(int id) {
    throw UnimplementedError();
  }

  @override
  Future<FutureMessage> react(int id, String reaction) {
    throw UnimplementedError();
  }
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  @override
  Future<List<PlanView>> listPlans() async => const [];

  @override
  Future<CurrentSubscription?> current() async => null;

  @override
  Future<CheckoutSession> startCheckout({
    required String planCode,
    required String frontendBaseUrl,
  }) {
    throw UnimplementedError();
  }

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CurrentSubscription?> cancel() {
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
}
