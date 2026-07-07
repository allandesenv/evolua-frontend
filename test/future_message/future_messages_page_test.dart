import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_controller.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message_ready_summary.dart';
import 'package:evolua_frontend/features/future_message/domain/repositories/future_message_repository.dart';
import 'package:evolua_frontend/features/future_message/presentation/future_message_delivery_label.dart';
import 'package:evolua_frontend/features/future_message/presentation/pages/future_messages_page.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'delivery label preserves specific local date and hides internal enums',
    () {
      final label = futureMessageDeliveryLabel(
        FutureMessage(
          id: 1,
          title: 'Carta',
          body: 'Texto',
          bodyPreview: 'Texto',
          triggerType: 'SPECIFIC_DATE',
          triggerConfig: const {'date': '2026-07-07'},
          triggerLabel: 'SPECIFIC_DATE',
          status: 'SCHEDULED',
          createdContext: const {},
          deliveredContext: const {},
          createdAt: DateTime(2026, 6, 1),
          scheduledFor: DateTime.utc(2026, 7, 7),
        ),
      );

      expect(label, 'Entrega em 07/07/2026');
      expect(label, isNot(contains('SPECIFIC_DATE')));
    },
  );

  test(
    'delivery label falls back without exposing unsupported after-days enum',
    () {
      final label = futureMessageDeliveryLabel(
        FutureMessage(
          id: 1,
          title: 'Carta',
          body: 'Texto',
          bodyPreview: 'Texto',
          triggerType: 'AFTER_DAYS',
          triggerConfig: const {'days': 2},
          triggerLabel: 'AFTER_DAYS',
          status: 'SCHEDULED',
          createdContext: const {},
          deliveredContext: const {},
          createdAt: DateTime(2026, 6, 1),
        ),
      );

      expect(label, 'Entrega programada');
      expect(label, isNot(contains('AFTER_DAYS')));
    },
  );

  testWidgets('future message composer keeps only message text field', (
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

    expect(fields, hasLength(1));
    expect(
      fields.map((field) => field.textCapitalization),
      everyElement(TextCapitalization.sentences),
    );
    expect(find.text('Sua mensagem'), findsOneWidget);
    expect(
      find.text('O que voce gostaria de lembrar no futuro?'),
      findsNothing,
    );
    expect(find.text('O que voce esta sentindo agora?'), findsNothing);
    expect(
      find.text('O que voce espera de voce daqui a 30 dias?'),
      findsNothing,
    );
  });

  testWidgets('creating future message sends only body prompt fields null', (
    tester,
  ) async {
    final repository = _FakeFutureMessageRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          futureMessageRepositoryProvider.overrideWithValue(repository),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
        ],
        child: const MaterialApp(home: FutureMessagesPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Uma carta simples.');
    await tester.ensureVisible(find.text('Guardar mensagem'));
    await tester.tap(find.text('Guardar mensagem'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.lastDraft?.body, 'Uma carta simples.');
    expect(repository.lastDraft?.promptRemember, isNull);
    expect(repository.lastDraft?.promptFeeling, isNull);
    expect(repository.lastDraft?.promptHope, isNull);
  });

  testWidgets(
    'scheduled list renders friendly delivery label without extra calls',
    (tester) async {
      final repository = _FakeFutureMessageRepository(
        listItems: [
          FutureMessage(
            id: 7,
            title: 'Carta para mim mesmo',
            body: 'Texto',
            bodyPreview: 'Texto',
            triggerType: 'SPECIFIC_DATE',
            triggerConfig: const {'date': '2026-07-07'},
            triggerLabel: 'SPECIFIC_DATE',
            status: 'SCHEDULED',
            createdContext: const {},
            deliveredContext: const {},
            createdAt: DateTime(2026, 6, 1),
            scheduledFor: DateTime.utc(2026, 7, 7),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            futureMessageRepositoryProvider.overrideWithValue(repository),
            subscriptionRepositoryProvider.overrideWithValue(
              _FakeSubscriptionRepository(),
            ),
          ],
          child: const MaterialApp(home: FutureMessagesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Entrega em 07/07/2026'), findsOneWidget);
      expect(find.text('SPECIFIC_DATE'), findsNothing);
      expect(repository.listCalls, 1);
      expect(repository.deliveredCalls, 1);
      expect(repository.readySummaryCalls, 0);
    },
  );

  testWidgets(
    'premium prompt exposes subscribe action without extra requests',
    (tester) async {
      var openedPremium = false;
      final repository = _FakeFutureMessageRepository(
        listItems: [
          _scheduledMessage(1),
          _scheduledMessage(2),
          _scheduledMessage(3),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            futureMessageRepositoryProvider.overrideWithValue(repository),
            subscriptionRepositoryProvider.overrideWithValue(
              _FakeSubscriptionRepository(),
            ),
          ],
          child: MaterialApp(
            home: FutureMessagesPage(onOpenPremium: () => openedPremium = true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assinar Premium'), findsOneWidget);
      await tester.ensureVisible(find.text('Assinar Premium'));
      await tester.tap(find.text('Assinar Premium'));
      await tester.pump();

      expect(openedPremium, isTrue);
      expect(repository.listCalls, 1);
      expect(repository.deliveredCalls, 1);
      expect(repository.readySummaryCalls, 0);
    },
  );
}

class _FakeFutureMessageRepository implements FutureMessageRepository {
  _FakeFutureMessageRepository({this.listItems = const []});

  final List<FutureMessage> listItems;
  int listCalls = 0;
  int deliveredCalls = 0;
  int readySummaryCalls = 0;
  int createCalls = 0;
  FutureMessageDraft? lastDraft;

  @override
  Future<PaginatedResponse<FutureMessage>> delivered({
    required int page,
    required int size,
  }) async {
    deliveredCalls += 1;
    return PaginatedResponse.empty(page: page, size: size);
  }

  @override
  Future<PaginatedResponse<FutureMessage>> list({
    required int page,
    required int size,
    List<String>? statuses,
  }) async {
    listCalls += 1;
    return PaginatedResponse<FutureMessage>.empty(
      page: page,
      size: size,
    ).copyWith(items: listItems);
  }

  @override
  Future<FutureMessageReadySummary> readySummary() async {
    readySummaryCalls += 1;
    return const FutureMessageReadySummary.empty();
  }

  @override
  Future<void> heartbeat() async {}

  @override
  Future<FutureMessage> create(FutureMessageDraft draft) async {
    createCalls += 1;
    lastDraft = draft;
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
    return Future.value(_scheduledMessage(id));
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

FutureMessage _scheduledMessage(int id) {
  return FutureMessage(
    id: id,
    title: 'Carta $id',
    body: 'Texto',
    bodyPreview: 'Texto',
    triggerType: 'AFTER_DAYS',
    triggerConfig: const {'days': 30},
    triggerLabel: 'AFTER_DAYS',
    status: 'SCHEDULED',
    createdContext: const {},
    deliveredContext: const {},
    createdAt: DateTime(2026, 6, 1),
    scheduledFor: DateTime(2026, 7, 1),
  );
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
