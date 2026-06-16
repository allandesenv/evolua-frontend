import 'dart:async';
import 'dart:convert';

import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service_base.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_progress.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_response.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/repositories/daily_ritual_repository.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_controller.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:evolua_frontend/features/future_message/domain/repositories/future_message_repository.dart';
import 'package:evolua_frontend/features/home/presentation/pages/home_page.dart';
import 'package:evolua_frontend/features/home/presentation/widgets/home_hub_view.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeHubView briefing', () {
    testWidgets('renders the briefing flow in the intended order', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(now: DateTime(2026, 5, 7, 8)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Leo'), findsOneWidget);
      expect(find.text('O que isso significa?'), findsOneWidget);
      expect(find.text('O que faço agora?'), findsOneWidget);
      expect(find.text('Como anda meu ritmo?'), findsOneWidget);

      final insightTop = tester
          .getTopLeft(find.text('O que isso significa?'))
          .dy;
      final nextStepTop = tester.getTopLeft(find.text('O que faço agora?')).dy;
      final rhythmTop = tester.getTopLeft(find.text('Como anda meu ritmo?')).dy;

      expect(insightTop, lessThan(nextStepTop));
      expect(nextStepTop, lessThan(rhythmTop));
    });

    testWidgets(
      'shows daytime check-in action when user has no check-in today',
      (tester) async {
        var openedCheckIn = false;
        String? openedType;
        final yesterday = DateTime.now().subtract(const Duration(days: 1));

        await tester.pumpWidget(
          _testApp(
            onOpenCheckIn: () => openedCheckIn = true,
            onOpenDailyRitual: (type) => openedType = type,
            now: DateTime(2026, 5, 7, 13),
            checkInRepository: _FakeCheckInRepository(
              items: [
                CheckIn(
                  id: 20,
                  userId: 'user-123',
                  mood: 'calmo',
                  reflection: 'ontem foi melhor',
                  energyLevel: 7,
                  recommendedPractice: 'Pausa curta',
                  aiInsight: null,
                  createdAt: yesterday,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Iniciar Ritual do Dia'), findsOneWidget);
        expect(find.text('Como está seu dia até aqui?'), findsNothing);
        expect(find.text('Fazer check-in'), findsOneWidget);

        await tester.tap(find.text('Iniciar Ritual do Dia'));
        await tester.pumpAndSettle();

        expect(openedType, DailyRitualType.morning);
        expect(openedCheckIn, isFalse);
      },
    );

    testWidgets('free user with today check-in sees unlock gate first', (
      tester,
    ) async {
      var openedCheckIn = false;
      final rewarded = _FakeRewardedAdService();

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 13),
          checkInRepository: _FakeCheckInRepository(
            items: [_testCheckIn(id: 91, createdAt: DateTime(2026, 5, 7, 9))],
          ),
          rewardedAdService: rewarded,
          onOpenCheckIn: () => openedCheckIn = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Novo check-in'), findsOneWidget);
      await tester.tap(find.text('Novo check-in'));
      await tester.pumpAndSettle();

      expect(openedCheckIn, isFalse);
      expect(find.text('Liberar novo check-in'), findsOneWidget);
      expect(
        find.text(
          'Você já fez seu check-in gratuito de hoje. Para registrar outro agora, você pode assistir a um anúncio, ver o Premium ou voltar amanhã.',
        ),
        findsOneWidget,
      );
      expect(rewarded.showCalls, 0);
    });

    testWidgets('rewarded extra check-in opens writing only when confirmed', (
      tester,
    ) async {
      var openedCheckIn = false;
      final rewarded = _FakeRewardedAdService(
        result: RewardedAdResult.rewarded,
      );
      final subscriptions = _FakeSubscriptionRepository(
        accessStatuses: [
          _accessStatus(),
          _accessStatus(),
          _accessStatus(
            rewardedCreditsGrantedToday: 1,
            rewardedCreditsUsedToday: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 13),
          checkInRepository: _FakeCheckInRepository(
            items: [_testCheckIn(id: 92, createdAt: DateTime(2026, 5, 7, 9))],
          ),
          subscriptionRepository: subscriptions,
          rewardedAdService: rewarded,
          onOpenCheckIn: () => openedCheckIn = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Novo check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assistir anúncio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(rewarded.rewardType, 'EXTRA_CHECK_IN');
      expect(rewarded.showCalls, 1);
      expect(subscriptions.accessCalls, 3);
      expect(openedCheckIn, isTrue);
      expect(find.text('Liberar novo check-in'), findsNothing);
    });

    testWidgets(
      'extra check-in gate opens without rewarded when credit is already pending',
      (tester) async {
        var openedCheckIn = false;
        final rewarded = _FakeRewardedAdService();
        final subscriptions = _FakeSubscriptionRepository(
          accessStatuses: [
            _accessStatus(
              rewardedCreditsGrantedToday: 1,
              rewardedCreditsUsedToday: 0,
            ),
          ],
        );

        await tester.pumpWidget(
          _testApp(
            now: DateTime(2026, 5, 7, 13),
            checkInRepository: _FakeCheckInRepository(
              items: [
                _testCheckIn(id: 191, createdAt: DateTime(2026, 5, 7, 9)),
              ],
            ),
            subscriptionRepository: subscriptions,
            rewardedAdService: rewarded,
            onOpenCheckIn: () => openedCheckIn = true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Novo check-in'));
        await tester.pumpAndSettle();

        expect(openedCheckIn, isTrue);
        expect(rewarded.showCalls, 0);
        expect(subscriptions.accessCalls, 1);
      },
    );

    testWidgets('extra check-in gate shows daily reward exhausted state', (
      tester,
    ) async {
      var openedCheckIn = false;
      var openedPremium = false;
      final rewarded = _FakeRewardedAdService();
      final subscriptions = _FakeSubscriptionRepository(
        rewardedCreditsGrantedToday: 1,
        rewardedCreditsUsedToday: 1,
      );

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 13),
          checkInRepository: _FakeCheckInRepository(
            items: [_testCheckIn(id: 196, createdAt: DateTime(2026, 5, 7, 9))],
          ),
          subscriptionRepository: subscriptions,
          rewardedAdService: rewarded,
          onOpenCheckIn: () => openedCheckIn = true,
          onOpenPremium: () => openedPremium = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Novo check-in'));
      await tester.pumpAndSettle();

      expect(openedCheckIn, isFalse);
      expect(rewarded.showCalls, 0);
      expect(subscriptions.accessCalls, 1);
      expect(find.text('Check-in extra já usado hoje'), findsOneWidget);
      expect(find.text('Assistir anúncio'), findsNothing);

      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();
      expect(find.text('Check-in extra já usado hoje'), findsNothing);
      expect(openedPremium, isFalse);

      await tester.tap(find.text('Novo check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver Premium'));
      await tester.pumpAndSettle();
      expect(openedPremium, isTrue);
    });

    testWidgets(
      'extra check-in gate opens when pending confirmation has reward credit',
      (tester) async {
        var openedCheckIn = false;
        final rewarded = _FakeRewardedAdService(
          result: RewardedAdResult.rewardConfirmedButAccessDenied,
        );
        final subscriptions = _FakeSubscriptionRepository(
          accessStatuses: [
            _accessStatus(),
            _accessStatus(),
            _accessStatus(
              rewardedCreditsGrantedToday: 1,
              rewardedCreditsUsedToday: 0,
            ),
          ],
        );

        await tester.pumpWidget(
          _testApp(
            now: DateTime(2026, 5, 7, 13),
            checkInRepository: _FakeCheckInRepository(
              items: [
                _testCheckIn(id: 192, createdAt: DateTime(2026, 5, 7, 9)),
              ],
            ),
            subscriptionRepository: subscriptions,
            rewardedAdService: rewarded,
            onOpenCheckIn: () => openedCheckIn = true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Novo check-in'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Assistir anúncio'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(openedCheckIn, isTrue);
        expect(rewarded.showCalls, 1);
        expect(subscriptions.accessCalls, 3);
        expect(find.text('Não foi possível liberar agora'), findsNothing);
      },
    );

    testWidgets('extra check-in gate opens when timeout recheck finds credit', (
      tester,
    ) async {
      var openedCheckIn = false;
      final rewarded = _FakeRewardedAdService(result: RewardedAdResult.timeout);
      final subscriptions = _FakeSubscriptionRepository(
        accessStatuses: [
          _accessStatus(),
          _accessStatus(),
          _accessStatus(
            rewardedCreditsGrantedToday: 1,
            rewardedCreditsUsedToday: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 13),
          checkInRepository: _FakeCheckInRepository(
            items: [_testCheckIn(id: 193, createdAt: DateTime(2026, 5, 7, 9))],
          ),
          subscriptionRepository: subscriptions,
          rewardedAdService: rewarded,
          onOpenCheckIn: () => openedCheckIn = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Novo check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assistir anúncio'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(openedCheckIn, isTrue);
      expect(rewarded.showCalls, 1);
      expect(subscriptions.accessCalls, 3);
      expect(find.text('Não foi possível liberar agora'), findsNothing);
    });

    testWidgets(
      'extra check-in gate opens when rewarded setup fails but credit is pending',
      (tester) async {
        var openedCheckIn = false;
        final rewarded = _FakeRewardedAdService(error: Exception('HTTP 400'));
        final subscriptions = _FakeSubscriptionRepository(
          accessStatuses: [
            _accessStatus(),
            _accessStatus(),
            _accessStatus(
              rewardedCreditsGrantedToday: 1,
              rewardedCreditsUsedToday: 0,
            ),
          ],
        );

        await tester.pumpWidget(
          _testApp(
            now: DateTime(2026, 5, 7, 13),
            checkInRepository: _FakeCheckInRepository(
              items: [
                _testCheckIn(id: 194, createdAt: DateTime(2026, 5, 7, 9)),
              ],
            ),
            subscriptionRepository: subscriptions,
            rewardedAdService: rewarded,
            onOpenCheckIn: () => openedCheckIn = true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Novo check-in'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Assistir anúncio'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(openedCheckIn, isTrue);
        expect(rewarded.showCalls, 1);
        expect(subscriptions.accessCalls, 3);
        expect(
          find.text('NÃ£o conseguimos carregar o anÃºncio agora'),
          findsNothing,
        );
      },
    );

    testWidgets('extra check-in gate blocks double rewarded taps', (
      tester,
    ) async {
      var openedCheckIn = false;
      final adGate = Completer<RewardedAdResult>();
      final rewarded = _FakeRewardedAdService(resultGate: adGate);
      final subscriptions = _FakeSubscriptionRepository(
        accessStatuses: [
          _accessStatus(),
          _accessStatus(),
          _accessStatus(
            rewardedCreditsGrantedToday: 1,
            rewardedCreditsUsedToday: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 13),
          checkInRepository: _FakeCheckInRepository(
            items: [_testCheckIn(id: 93, createdAt: DateTime(2026, 5, 7, 9))],
          ),
          subscriptionRepository: subscriptions,
          rewardedAdService: rewarded,
          onOpenCheckIn: () => openedCheckIn = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Novo check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assistir anúncio'));
      await tester.pump();
      await tester.tap(find.text('Carregando anúncio'), warnIfMissed: false);
      await tester.pump();

      expect(rewarded.showCalls, 1);

      adGate.complete(RewardedAdResult.rewarded);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(openedCheckIn, isTrue);
      expect(rewarded.showCalls, 1);
      expect(subscriptions.accessCalls, 3);
    });

    testWidgets(
      'extra check-in gate keeps user out on failed or pending rewards',
      (tester) async {
        for (final result in [
          RewardedAdResult.noFill,
          RewardedAdResult.loadFailed,
          RewardedAdResult.showFailed,
          RewardedAdResult.timeout,
          RewardedAdResult.dismissedWithoutReward,
          RewardedAdResult.rewardConfirmedButAccessDenied,
        ]) {
          var openedCheckIn = false;
          final rewarded = _FakeRewardedAdService(result: result);
          final subscriptions = _FakeSubscriptionRepository(
            rewardedCreditsGrantedToday: 0,
            rewardedCreditsUsedToday: 0,
          );

          await tester.pumpWidget(
            _testApp(
              now: DateTime(2026, 5, 7, 13),
              checkInRepository: _FakeCheckInRepository(
                items: [
                  _testCheckIn(id: 94, createdAt: DateTime(2026, 5, 7, 9)),
                ],
              ),
              subscriptionRepository: subscriptions,
              rewardedAdService: rewarded,
              onOpenCheckIn: () => openedCheckIn = true,
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Novo check-in'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Assistir anúncio'));
          await tester.pump();
          if (result == RewardedAdResult.timeout ||
              result == RewardedAdResult.rewardConfirmedButAccessDenied) {
            await tester.pump(const Duration(seconds: 4));
          } else {
            await tester.pump(const Duration(milliseconds: 350));
          }

          expect(openedCheckIn, isFalse);
          expect(rewarded.showCalls, 1);
          expect(find.text('Liberar novo check-in'), findsNothing);
          if (result == RewardedAdResult.rewardConfirmedButAccessDenied) {
            expect(find.text('Confirmação em andamento'), findsOneWidget);
            expect(find.text('Não foi possível liberar agora'), findsNothing);
            expect(subscriptions.accessCalls, 5);
          } else if (result == RewardedAdResult.timeout) {
            expect(find.text('Confirmação em andamento'), findsOneWidget);
            expect(find.text('Não foi possível liberar agora'), findsNothing);
            expect(subscriptions.accessCalls, 5);
          } else if (result == RewardedAdResult.dismissedWithoutReward) {
            expect(find.text('Anúncio não concluído'), findsOneWidget);
            expect(subscriptions.accessCalls, 2);
          } else if (result == RewardedAdResult.noFill) {
            expect(
              find.text('Nenhum anúncio disponível agora'),
              findsOneWidget,
            );
            expect(subscriptions.accessCalls, 2);
          } else if (result == RewardedAdResult.loadFailed) {
            expect(
              find.text('Não conseguimos carregar o anúncio agora'),
              findsOneWidget,
            );
            expect(find.text('Nenhum anúncio disponível agora'), findsNothing);
            expect(subscriptions.accessCalls, 4);
          } else if (result == RewardedAdResult.showFailed) {
            expect(
              find.text('Não conseguimos abrir o anúncio agora'),
              findsOneWidget,
            );
            expect(subscriptions.accessCalls, 2);
          } else {
            expect(find.text('Não foi possível liberar agora'), findsOneWidget);
            expect(subscriptions.accessCalls, 2);
          }
          await tester.tap(find.text('Agora não'));
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets('extra check-in gate premium and now close without errors', (
      tester,
    ) async {
      var openedPremium = false;
      var openedCheckIn = false;

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 13),
          checkInRepository: _FakeCheckInRepository(
            items: [_testCheckIn(id: 95, createdAt: DateTime(2026, 5, 7, 9))],
          ),
          onOpenCheckIn: () => openedCheckIn = true,
          onOpenPremium: () => openedPremium = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Novo check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver Premium'));
      await tester.pumpAndSettle();

      expect(openedPremium, isTrue);
      expect(openedCheckIn, isFalse);

      await tester.tap(find.text('Novo check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();

      expect(find.text('Liberar novo check-in'), findsNothing);
      expect(openedCheckIn, isFalse);
    });

    testWidgets('premium bypasses extra check-in gate', (tester) async {
      var openedCheckIn = 0;

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 13),
          authSession: _authSession(
            userId: 'user-123',
            email: 'premium@evolua.test',
            roles: const ['ROLE_PREMIUM'],
          ),
          checkInRepository: _FakeCheckInRepository(
            items: [_testCheckIn(id: 96, createdAt: DateTime(2026, 5, 7, 9))],
          ),
          subscriptionRepository: _FakeSubscriptionRepository(premium: true),
          dailyRitualRepository: _FakeDailyRitualRepository(
            morning: _testRitual(DailyRitualType.morning),
          ),
          onOpenCheckIn: () => openedCheckIn++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fazer check-in'), findsOneWidget);
      await tester.tap(find.text('Fazer check-in'));
      expect(openedCheckIn, 1);
      expect(find.text('Liberar novo check-in'), findsNothing);
    });

    testWidgets('loading subscription does not apply extra check-in gate', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 13),
          subscriptionRepository: _PendingSubscriptionRepository(),
          checkInRepository: _FakeCheckInRepository(
            items: [_testCheckIn(id: 97, createdAt: DateTime(2026, 5, 7, 9))],
          ),
          dailyRitualRepository: _FakeDailyRitualRepository(
            morning: _testRitual(DailyRitualType.morning),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Novo check-in'), findsNothing);
      expect(find.text('Liberar novo check-in'), findsNothing);
    });

    testWidgets('shows persisted intelligent reading from history', (
      tester,
    ) async {
      const persistedInsight =
          'Leitura recuperada do historico salvo no servidor.';
      await tester.pumpWidget(
        _testApp(
          checkInRepository: _FakeCheckInRepository(
            items: [
              CheckIn(
                id: 30,
                userId: 'user-123',
                mood: 'calmo',
                reflection: 'voltei para ver minha leitura',
                energyLevel: 7,
                recommendedPractice: 'Respirar por dois minutos.',
                aiInsight: _insight(insight: persistedInsight),
                createdAt: DateTime(2026, 5, 7, 9),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining(
          'Leitura recuperada do historico salvo no servidor',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Depois do'), findsNothing);
    });

    testWidgets(
      'shows mirror reward actions after today check-in with insight',
      (tester) async {
        var openedTrails = false;
        var openedMirror = false;

        await tester.pumpWidget(
          _testApp(
            now: DateTime(2026, 5, 7, 13),
            onOpenTrails: () => openedTrails = true,
            onOpenEvolutionMirror: () => openedMirror = true,
            checkInRepository: _FakeCheckInRepository(
              items: [
                CheckIn(
                  id: 31,
                  userId: 'user-123',
                  mood: 'calmo',
                  reflection: 'consegui observar melhor',
                  energyLevel: 7,
                  recommendedPractice: 'Respirar por dois minutos.',
                  aiInsight: _insight(insight: 'Sua leitura esta pronta.'),
                  createdAt: DateTime(2026, 5, 7, 9),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Seu check-in já conta para o seu Espelho'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Quanto mais você registra, mais seu Espelho revela padrões.',
          ),
          findsOneWidget,
        );
        expect(find.text('Ver análise'), findsOneWidget);
        expect(find.text('Continuar trilha'), findsAtLeastNWidgets(1));
        expect(find.text('Ver meu Espelho'), findsOneWidget);

        await tester.ensureVisible(find.text('Ver análise'));
        await tester.tap(find.text('Ver análise'));
        await tester.pumpAndSettle();
        expect(find.text('Análise completa'), findsOneWidget);

        await tester.tap(find.byTooltip('Voltar'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Continuar trilha').first);
        await tester.tap(find.text('Continuar trilha').first);
        expect(openedTrails, isTrue);

        await tester.ensureVisible(find.text('Ver meu Espelho'));
        await tester.tap(find.text('Ver meu Espelho'));
        expect(openedMirror, isTrue);
      },
    );

    testWidgets('keeps mirror reward visible while reading is pending', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 13),
          checkInRepository: _FakeCheckInRepository(
            items: [
              CheckIn(
                id: 32,
                userId: 'user-123',
                mood: 'calmo',
                reflection: 'registro rapido',
                energyLevel: 7,
                recommendedPractice: 'Respirar por dois minutos.',
                aiInsight: null,
                createdAt: DateTime(2026, 5, 7, 9),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Seu check-in já conta para o seu Espelho'),
        findsOneWidget,
      );
      expect(find.text('Ver análise'), findsNothing);
      expect(find.text('Ver meu Espelho'), findsOneWidget);
    });

    testWidgets('does not show mirror reward without today check-in', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 13),
          checkInRepository: _FakeCheckInRepository(
            items: [
              CheckIn(
                id: 33,
                userId: 'user-123',
                mood: 'calmo',
                reflection: 'ontem',
                energyLevel: 7,
                recommendedPractice: 'Respirar por dois minutos.',
                aiInsight: _insight(),
                createdAt: DateTime(2026, 5, 6, 9),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Seu check-in já conta para o seu Espelho'),
        findsNothing,
      );
    });

    testWidgets('does not render stale intelligent reading from another user', (
      tester,
    ) async {
      final staleState = CheckInHistoryState(
        ownerUserId: 'user-a',
        result: PaginatedResponse(
          items: [
            CheckIn(
              id: 301,
              userId: 'user-a',
              mood: 'calma',
              reflection: '',
              energyLevel: 7,
              recommendedPractice: 'Respirar por dois minutos.',
              aiInsight: _insight(insight: 'Leitura sensível do usuário A'),
              createdAt: DateTime(2026, 5, 7, 9),
            ),
          ],
          page: 0,
          size: 6,
          totalItems: 1,
          totalPages: 1,
          hasNext: false,
          hasPrevious: false,
          sortBy: 'createdAt',
          sortDir: 'desc',
          filters: const {},
        ),
        selectedGrouping: 'monthly',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionStorageProvider.overrideWithValue(
              _MemoryAuthSessionStorage(
                _authSession(userId: 'user-b', email: 'b@evolua.test'),
              ),
            ),
            checkInControllerProvider.overrideWith(
              () => _StaticCheckInController(staleState),
            ),
          ],
          child: MaterialApp(theme: AppTheme.dark(), home: const HomePage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Leitura sensível do usuário A'),
        findsNothing,
      );
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('shows compact intelligent reading bullets on Home', (
      tester,
    ) async {
      const longInsight =
          'Seu momento atual pede reducao de carga e foco em uma unica acao simples. Este segundo bloco fica guardado para a analise completa.';
      await tester.pumpWidget(
        _testApp(
          checkInRepository: _FakeCheckInRepository(
            items: [
              CheckIn(
                id: 31,
                userId: 'user-123',
                mood: 'tensao relevante',
                reflection: 'muitas frentes abertas',
                energyLevel: 7,
                recommendedPractice: 'Desacelerar por dois minutos.',
                aiInsight: _insight(insight: longInsight),
                createdAt: DateTime(2026, 5, 7, 9),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(longInsight), findsNothing);
      expect(
        find.textContaining('Energia: 7/10', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Estado: Tensao relevante', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Melhor resposta agora:', findRichText: true),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Ver análise completa'));
      await tester.tap(find.text('Ver análise completa'));
      await tester.pumpAndSettle();

      expect(find.text(longInsight), findsOneWidget);
    });

    testWidgets('updates intelligent reading after check-in creation', (
      tester,
    ) async {
      final repository = _MutableCheckInRepository(
        initialItems: const <CheckIn>[],
        created: CheckIn(
          id: 77,
          userId: 'user-123',
          mood: 'ansioso',
          reflection: '',
          energyLevel: 6,
          recommendedPractice: '',
          aiInsight: null,
          createdAt: DateTime(2026, 5, 7, 9),
        ),
        listedAfterCreate: [
          CheckIn(
            id: 77,
            userId: 'user-123',
            mood: 'ansioso',
            reflection: '',
            energyLevel: 6,
            recommendedPractice: 'Desacelerar',
            aiInsight: _insight(
              insight: 'Seu momento atual pede reducao de carga.',
            ),
            createdAt: DateTime(2026, 5, 7, 9),
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(checkInRepository: repository, now: DateTime(2026, 5, 7, 13)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Depois do'), findsOneWidget);

      final context = tester.element(find.byType(HomeHubView));
      final container = ProviderScope.containerOf(context);
      await container
          .read(checkInControllerProvider.notifier)
          .create(mood: 'ansioso', reflection: null, energyLevel: 6);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Seu momento atual pede reducao de carga'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Energia: 6/10', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Estado: Ansioso', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('keeps reading pending and updates when insight arrives later', (
      tester,
    ) async {
      final repository = _EventuallyConsistentCheckInRepository(
        created: CheckIn(
          id: 88,
          userId: 'user-123',
          mood: 'energizado',
          reflection: '',
          energyLevel: 7,
          recommendedPractice: '',
          aiInsight: null,
          createdAt: DateTime(2026, 5, 7, 9),
        ),
        lists: [
          const <CheckIn>[],
          const <CheckIn>[],
          [
            CheckIn(
              id: 88,
              userId: 'user-123',
              mood: 'energizado',
              reflection: '',
              energyLevel: 7,
              recommendedPractice: 'Continue com constancia',
              aiInsight: _insight(
                insight:
                    'Seu check-in indica uma base favoravel para clareza e continuidade.',
                fallbackUsed: false,
              ),
              createdAt: DateTime(2026, 5, 7, 9),
            ),
          ],
        ],
      );

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          pollingConfig: const CheckInInsightPollingConfig(
            attempts: 2,
            delay: Duration(milliseconds: 50),
          ),
          now: DateTime(2026, 5, 7, 13),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Depois do'), findsOneWidget);

      final context = tester.element(find.byType(HomeHubView));
      final container = ProviderScope.containerOf(context);
      await container
          .read(checkInControllerProvider.notifier)
          .create(mood: 'energizado', reflection: null, energyLevel: 7);
      await tester.pump();

      expect(find.textContaining('Depois do'), findsNothing);
      expect(find.text('Gerando leitura...'), findsOneWidget);
      expect(find.textContaining('Você já pode continuar'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Seu check-in indica uma base favoravel'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Energia: 7/10', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Estado: Energizado', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Ver análise completa'), findsOneWidget);
    });

    testWidgets('shows unavailable reading state after polling is exhausted', (
      tester,
    ) async {
      final pending = CheckIn(
        id: 89,
        userId: 'user-123',
        mood: 'calmo',
        reflection: '',
        energyLevel: 6,
        recommendedPractice: '',
        aiInsight: null,
        createdAt: DateTime(2026, 5, 7, 9),
      );
      final repository = _EventuallyConsistentCheckInRepository(
        created: pending,
        lists: [
          const <CheckIn>[],
          [pending],
          [pending],
        ],
      );

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          pollingConfig: const CheckInInsightPollingConfig(
            attempts: 1,
            delay: Duration(milliseconds: 20),
          ),
          now: DateTime(2026, 5, 7, 13),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomeHubView));
      final container = ProviderScope.containerOf(context);
      await container
          .read(checkInControllerProvider.notifier)
          .create(mood: 'calmo', reflection: null, energyLevel: 6);
      await tester.pump();

      expect(find.text('Gerando leitura...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();

      expect(find.text('Leitura indisponível agora'), findsOneWidget);
      expect(find.textContaining('check-in foi salvo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Ver análise'), findsNothing);
      expect(find.text('Ver análise completa'), findsNothing);
    });

    testWidgets('shows contextual mini cards and opens direct actions', (
      tester,
    ) async {
      var openedFutureMessages = false;
      var openedReflections = false;
      var openedMirror = false;
      var openedCare = false;

      await tester.pumpWidget(
        _testApp(
          onOpenFutureMessages: () => openedFutureMessages = true,
          onOpenFeed: () => openedReflections = true,
          onOpenEvolutionMirror: () => openedMirror = true,
          onOpenCareShare: () => openedCare = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Carta para o futuro'), findsOneWidget);
      expect(find.text('Evolua Care'), findsOneWidget);
      expect(find.text('Reflexão recente'), findsOneWidget);
      expect(find.text('Insight rápido'), findsOneWidget);
      expect(find.text('Marco de evolução'), findsOneWidget);

      await tester.tap(find.text('Carta para o futuro'));
      await tester.ensureVisible(find.text('Reflexão recente'));
      await tester.tap(find.text('Reflexão recente'));
      await tester.ensureVisible(find.text('Marco de evolução'));
      await tester.tap(find.text('Marco de evolução'));
      await tester.pumpAndSettle();

      expect(openedFutureMessages, isTrue);
      expect(openedReflections, isTrue);
      expect(openedMirror, isTrue);
      expect(openedCare, isFalse);
    });

    testWidgets('shows Evolua Care mini card and opens share flow', (
      tester,
    ) async {
      var openedCare = false;

      await tester.pumpWidget(
        _testApp(onOpenCareShare: () => openedCare = true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Evolua Care'), findsOneWidget);
      expect(find.text('Compartilhe com seu terapeuta.'), findsOneWidget);

      await tester.ensureVisible(find.text('Evolua Care'));
      await tester.tap(find.text('Evolua Care'));
      await tester.pumpAndSettle();

      expect(openedCare, isTrue);
    });

    testWidgets('insight mini card opens analysis when insight exists', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insight rápido'));
      await tester.pumpAndSettle();
      expect(find.text('Análise completa'), findsOneWidget);
    });

    testWidgets('insight mini card opens check-in when insight is missing', (
      tester,
    ) async {
      var openedCheckIn = false;
      await tester.pumpWidget(
        _testApp(
          checkInRepository: _FakeCheckInRepository(
            items: [
              CheckIn(
                id: 32,
                userId: 'user-123',
                mood: 'calmo',
                reflection: 'sem insight ainda',
                energyLevel: 7,
                recommendedPractice: 'Respirar.',
                aiInsight: null,
                createdAt: DateTime(2026, 5, 7, 9),
              ),
            ],
          ),
          onOpenCheckIn: () => openedCheckIn = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insight rápido'));
      await tester.pumpAndSettle();
      expect(openedCheckIn, isTrue);
    });

    testWidgets('shows morning ritual entry point first', (tester) async {
      String? openedType;

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 8),
          onOpenDailyRitual: (type) => openedType = type,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bom dia, Leo'), findsOneWidget);
      expect(find.text('Iniciar Ritual do Dia'), findsOneWidget);
      expect(find.text('Fazer check-in'), findsOneWidget);

      await tester.tap(find.text('Iniciar Ritual do Dia'));
      await tester.pumpAndSettle();

      expect(openedType, DailyRitualType.morning);
    });

    testWidgets('keeps morning ritual entry point during afternoon', (
      tester,
    ) async {
      String? openedType;

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 15),
          onOpenDailyRitual: (type) => openedType = type,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Iniciar Ritual do Dia'), findsOneWidget);
      expect(find.text('Fazer check-in'), findsOneWidget);
      expect(find.text('Ver próximo passo'), findsNothing);

      await tester.tap(find.text('Iniciar Ritual do Dia'));
      await tester.pumpAndSettle();

      expect(openedType, DailyRitualType.morning);
    });

    testWidgets('offers ritual generation after today check-in without ritual', (
      tester,
    ) async {
      String? openedType;

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 15),
          checkInRepository: _FakeCheckInRepository(
            items: [_testCheckIn(id: 41, createdAt: DateTime(2026, 5, 7, 9))],
          ),
          onOpenDailyRitual: (type) => openedType = type,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Criar ritual do dia'), findsOneWidget);
      expect(
        find.text(
          'Você já fez seu check-in de hoje. Agora pode transformar esse momento em um cuidado simples para o seu dia.',
        ),
        findsOneWidget,
      );
      expect(find.text('Gerar com meu check-in'), findsOneWidget);
      expect(find.text('Novo check-in'), findsOneWidget);

      await tester.tap(find.text('Novo check-in'));
      await tester.pumpAndSettle();

      expect(openedType, isNull);
      expect(find.text('Liberar novo check-in'), findsOneWidget);
    });

    testWidgets('generates morning ritual from latest today check-in', (
      tester,
    ) async {
      final dailyRituals = _FakeDailyRitualRepository();
      late final _FakeCheckInRepository checkIns;
      checkIns = _FakeCheckInRepository(
        items: [
          _testCheckIn(id: 41, createdAt: DateTime(2026, 5, 7, 9)),
          _testCheckIn(id: 40, createdAt: DateTime(2026, 5, 6, 9)),
        ],
        onCreateRitual: (checkInId, localDate, type) {
          dailyRituals.morning = _testRitual(type);
        },
      );

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 15),
          checkInRepository: checkIns,
          dailyRitualRepository: dailyRituals,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gerar com meu check-in'));
      await tester.pumpAndSettle();

      expect(checkIns.ritualTypes, [DailyRitualType.morning]);
      expect(checkIns.ritualDates.single, DateTime(2026, 5, 7));
      expect(find.textContaining('Ritual do Dia criado'), findsOneWidget);
      expect(find.text('Ritual do Dia concluído'), findsOneWidget);
      expect(find.text('Intencao de hoje: agir com calma'), findsOneWidget);
    });

    testWidgets('shows evening closing entry point', (tester) async {
      String? openedType;
      var openedReflections = false;

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 20),
          onOpenDailyRitual: (type) => openedType = type,
          onOpenFeed: () => openedReflections = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vamos fechar o dia?'), findsOneWidget);
      expect(find.text('Fazer Fechamento do Dia'), findsOneWidget);
      expect(find.text('Escrever reflexão'), findsOneWidget);

      await tester.tap(find.text('Fazer Fechamento do Dia'));
      await tester.pumpAndSettle();
      expect(openedType, DailyRitualType.evening);

      await tester.tap(find.text('Escrever reflexão'));
      await tester.pumpAndSettle();
      expect(openedReflections, isTrue);
    });

    testWidgets('opens manual evening closing after today check-in after 18h', (
      tester,
    ) async {
      final dailyRituals = _FakeDailyRitualRepository();
      final checkIns = _FakeCheckInRepository(
        items: [_testCheckIn(id: 42, createdAt: DateTime(2026, 5, 7, 18, 30))],
      );
      String? openedType;

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 20),
          checkInRepository: checkIns,
          dailyRitualRepository: dailyRituals,
          onOpenDailyRitual: (type) => openedType = type,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Criar fechamento do dia'), findsOneWidget);
      expect(find.text('Gerar com meu check-in'), findsNothing);
      expect(find.text('Fazer Fechamento do Dia'), findsOneWidget);

      await tester.tap(find.text('Fazer Fechamento do Dia'));
      await tester.pumpAndSettle();

      expect(openedType, DailyRitualType.evening);
      expect(checkIns.ritualTypes, isEmpty);
    });

    testWidgets('starts evening closing entry point at 18h', (tester) async {
      String? openedType;

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 18),
          onOpenDailyRitual: (type) => openedType = type,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fazer Fechamento do Dia'), findsOneWidget);
      expect(find.text('Iniciar Ritual do Dia'), findsNothing);

      await tester.tap(find.text('Fazer Fechamento do Dia'));
      await tester.pumpAndSettle();

      expect(openedType, DailyRitualType.evening);
    });

    testWidgets('shows completed morning ritual until evening', (tester) async {
      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 14),
          dailyRitualRepository: _FakeDailyRitualRepository(
            morning: _testRitual(DailyRitualType.morning),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ritual do Dia concluído'), findsOneWidget);
      expect(find.text('Intencao de hoje: agir com calma'), findsOneWidget);
      expect(
        find.text('Pequeno passo: pausar antes de reagir'),
        findsOneWidget,
      );
      expect(find.text('Ver meu ritual'), findsOneWidget);
    });

    testWidgets('does not duplicate when ritual appears before generation tap', (
      tester,
    ) async {
      final checkIns = _FakeCheckInRepository(
        items: [_testCheckIn(id: 43, createdAt: DateTime(2026, 5, 7, 10))],
      );
      final dailyRituals = _FakeDailyRitualRepository();

      await tester.pumpWidget(
        _testApp(
          now: DateTime(2026, 5, 7, 15),
          checkInRepository: checkIns,
          dailyRitualRepository: dailyRituals,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gerar com meu check-in'), findsOneWidget);
      dailyRituals.morning = _testRitual(DailyRitualType.morning);
      await tester.tap(find.text('Gerar com meu check-in'));
      await tester.pumpAndSettle();

      expect(checkIns.ritualTypes, isEmpty);
      expect(
        find.text(
          'Você já possui um ritual criado para hoje. Edite o ritual atual ou remova-o antes de gerar outro.',
        ),
        findsOneWidget,
      );
      expect(find.text('Abrir ritual'), findsOneWidget);
    });

    testWidgets('shows friendly error when check-in ritual generation fails', (
      tester,
    ) async {
      final checkIns = _FakeCheckInRepository(
        items: [_testCheckIn(id: 44, createdAt: DateTime(2026, 5, 7, 10))],
        failCreateRitual: true,
      );

      await tester.pumpWidget(
        _testApp(now: DateTime(2026, 5, 7, 15), checkInRepository: checkIns),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gerar com meu check-in'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Não conseguimos gerar seu ritual agora'),
        findsOneWidget,
      );
      expect(find.text('Gerar com meu check-in'), findsOneWidget);
    });

    testWidgets('opens full intelligent analysis from summarized card', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Ver análise completa'), findsOneWidget);
      await tester.ensureVisible(find.text('Ver análise completa'));
      await tester.tap(find.text('Ver análise completa'));
      await tester.pumpAndSettle();

      expect(find.text('Análise completa'), findsOneWidget);
      expect(find.text('Risco low'), findsAtLeastNWidgets(1));
      expect(find.text('Abrir trilha sugerida'), findsOneWidget);
    });

    testWidgets('creates day ritual from full analysis before evening', (
      tester,
    ) async {
      final checkIns = _FakeCheckInRepository();

      await tester.pumpWidget(
        _testApp(checkInRepository: checkIns, now: DateTime(2026, 5, 7, 10)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insight rápido'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Criar ritual do dia'));
      await tester.tap(find.text('Criar ritual do dia'));
      await tester.pumpAndSettle();

      expect(checkIns.ritualTypes, [DailyRitualType.morning]);
      expect(checkIns.ritualDates.single, DateTime(2026, 5, 7));
      expect(
        find.textContaining('Ritual do Dia criado e concluido'),
        findsOneWidget,
      );
    });

    testWidgets('opens manual evening closing from full analysis at night', (
      tester,
    ) async {
      final checkIns = _FakeCheckInRepository();
      String? openedType;

      await tester.pumpWidget(
        _testApp(
          checkInRepository: checkIns,
          now: DateTime(2026, 5, 7, 19),
          onOpenDailyRitual: (type) => openedType = type,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insight rápido'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fazer fechamento do dia'));
      await tester.tap(find.text('Fazer fechamento do dia'));
      await tester.pumpAndSettle();

      expect(openedType, DailyRitualType.evening);
      expect(checkIns.ritualTypes, isEmpty);
    });

    testWidgets('does not create duplicate ritual for current period', (
      tester,
    ) async {
      final checkIns = _FakeCheckInRepository();
      final existing = _testRitual(DailyRitualType.morning);

      await tester.pumpWidget(
        _testApp(
          checkInRepository: checkIns,
          dailyRitualRepository: _FakeDailyRitualRepository(morning: existing),
          now: DateTime(2026, 5, 7, 10),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insight rápido'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Criar ritual do dia'));
      await tester.tap(find.text('Criar ritual do dia'));
      await tester.pumpAndSettle();

      expect(checkIns.ritualTypes, isEmpty);
      expect(
        find.text(
          'Você já possui um ritual criado para hoje. Edite o ritual atual ou remova-o antes de gerar outro.',
        ),
        findsOneWidget,
      );
      expect(find.text('Abrir ritual'), findsOneWidget);
    });

    testWidgets(
      'opens manual evening closing instead of duplicate generation',
      (tester) async {
        final checkIns = _FakeCheckInRepository();
        final existing = _testRitual(DailyRitualType.evening);
        String? openedType;

        await tester.pumpWidget(
          _testApp(
            checkInRepository: checkIns,
            dailyRitualRepository: _FakeDailyRitualRepository(
              evening: existing,
            ),
            now: DateTime(2026, 5, 7, 19),
            onOpenDailyRitual: (type) => openedType = type,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Insight rápido'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Fazer fechamento do dia'));
        await tester.tap(find.text('Fazer fechamento do dia'));
        await tester.pumpAndSettle();

        expect(openedType, DailyRitualType.evening);
        expect(checkIns.ritualTypes, isEmpty);
      },
    );

    testWidgets(
      'full analysis sheet closes with header back and Android back',
      (tester) async {
        await tester.pumpWidget(_testApp());
        await tester.pumpAndSettle();

        final analysisTitle = find.byWidgetPredicate((widget) {
          return widget is Text &&
              (widget.data ?? '').startsWith('An') &&
              (widget.data ?? '').contains('completa');
        });

        Finder fullAnalysisButton() => find.text('Ver análise completa').first;

        await tester.ensureVisible(fullAnalysisButton());
        await tester.tap(fullAnalysisButton());
        await tester.pumpAndSettle();

        expect(analysisTitle, findsOneWidget);
        expect(find.byTooltip('Voltar'), findsOneWidget);

        await tester.tap(find.byTooltip('Voltar'));
        await tester.pumpAndSettle();

        expect(analysisTitle, findsNothing);

        await tester.ensureVisible(fullAnalysisButton());
        await tester.tap(fullAnalysisButton());
        await tester.pumpAndSettle();

        expect(analysisTitle, findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(analysisTitle, findsNothing);
      },
    );

    testWidgets(
      'suggested trail action closes full analysis before opening trails',
      (tester) async {
        int? openedSuggestedTrailId;
        await tester.pumpWidget(
          _testApp(
            onOpenSuggestedTrail: (trailId) => openedSuggestedTrailId = trailId,
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Ver análise completa'));
        await tester.tap(find.text('Ver análise completa'));
        await tester.pumpAndSettle();

        expect(find.text('Análise completa'), findsOneWidget);

        await tester.tap(find.text('Abrir trilha sugerida'));
        await tester.pumpAndSettle();

        expect(openedSuggestedTrailId, 1);
        expect(find.text('Análise completa'), findsNothing);
      },
    );

    testWidgets('shows next-step metadata as auxiliary context', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('8 min'), findsOneWidget);
      expect(find.text('mantém constância'), findsOneWidget);
      expect(find.text('trilha ativa'), findsOneWidget);
      expect(find.text('Continuar trilha'), findsAtLeastNWidgets(1));
      expect(find.text('Espaços'), findsOneWidget);

      expect(find.widgetWithText(OutlinedButton, 'Espaços'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '8 min'), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'mantém constância'),
        findsNothing,
      );
    });

    testWidgets('does not render journey progress inside next-step card', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Sua trilha em movimento'), findsNothing);
      expect(find.text('50%'), findsNothing);
      expect(find.text('50% da trilha'), findsNothing);
      expect(find.text('1/2 etapas'), findsNothing);
      expect(find.text('Proxima etapa: Escolher'), findsNothing);
    });

    testWidgets('renders safe-mode analysis text in full analysis', (
      tester,
    ) async {
      const safeInsightText =
          'Seu check-in mostra um momento de avanco e capacidade de fechamento.';
      await tester.pumpWidget(
        _testApp(
          checkInRepository: _FakeCheckInRepository(
            items: [
              CheckIn(
                id: 10,
                userId: 'user-123',
                mood: 'produtivo',
                reflection: 'tarefas concluidas',
                energyLevel: 7,
                recommendedPractice: 'Organize a proxima prioridade.',
                aiInsight: _insight(
                  insight: safeInsightText,
                  fallbackUsed: true,
                ),
                createdAt: DateTime.now(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver análise completa'));
      await tester.tap(find.text('Ver análise completa'));
      await tester.pumpAndSettle();

      expect(find.text('Modo seguro'), findsAtLeastNWidgets(1));
      expect(find.text(safeInsightText), findsAtLeastNWidgets(1));
    });

    testWidgets('opens evolution mirror directly from rhythm card', (
      tester,
    ) async {
      var openedMirror = false;
      await tester.pumpWidget(
        _testApp(onOpenEvolutionMirror: () => openedMirror = true),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver Espelho da Evolução'));
      await tester.tap(find.text('Ver Espelho da Evolução'));
      await tester.pumpAndSettle();

      expect(openedMirror, isTrue);
      expect(find.text('Seu ritmo hoje'), findsNothing);
    });

    testWidgets('opens rhythm details from recent check-ins action', (
      tester,
    ) async {
      var openedMirror = false;
      await tester.pumpWidget(
        _testApp(onOpenEvolutionMirror: () => openedMirror = true),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver últimos check-ins'));
      await tester.tap(find.text('Ver últimos check-ins'));
      await tester.pumpAndSettle();

      expect(find.text('Seu ritmo hoje'), findsOneWidget);
      expect(find.text('Energia média'), findsOneWidget);
      expect(find.text('Estado dominante'), findsOneWidget);
      expect(find.text('Check-ins na semana'), findsOneWidget);
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('Consistência da semana'), findsOneWidget);
      expect(find.text('Últimos check-ins'), findsOneWidget);
      expect(find.text('Abrir Espelho da Evolução'), findsOneWidget);

      await tester.ensureVisible(find.text('Abrir Espelho da Evolução'));
      await tester.tap(find.text('Abrir Espelho da Evolução'));
      await tester.pumpAndSettle();

      expect(openedMirror, isTrue);
      expect(find.text('Seu ritmo hoje'), findsNothing);
    });

    testWidgets('keeps the briefing usable on mobile width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Olhar do Evolua'), findsOneWidget);
      expect(find.text('Próximo passo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses light surfaces and readable text in light theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(theme: AppTheme.light(accessibleFont: true)),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('O que isso significa?'));
      final colors = context.evoluaColors;
      final panel = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = panel.decoration! as BoxDecoration;

      expect(Theme.of(context).brightness, Brightness.light);
      expect(decoration.color, colors.surface.withValues(alpha: 0.94));
      expect(
        decoration.color,
        isNot(AppColors.surface.withValues(alpha: 0.94)),
      );
      expect(
        Theme.of(context).textTheme.headlineSmall?.color,
        isNot(AppColors.textPrimary),
      );
    });
  });
}

Widget _testApp({
  CheckInRepository? checkInRepository,
  CheckInInsightPollingConfig pollingConfig = const CheckInInsightPollingConfig(
    attempts: 0,
    delay: Duration.zero,
  ),
  TrailRepository? trailRepository,
  DailyRitualRepository? dailyRitualRepository,
  SubscriptionRepository? subscriptionRepository,
  RewardedAdService? rewardedAdService,
  AuthSession? authSession,
  ThemeData? theme,
  DateTime? now,
  VoidCallback? onOpenTrails,
  ValueChanged<int>? onOpenSuggestedTrail,
  VoidCallback? onOpenFeed,
  VoidCallback? onOpenCommunity,
  VoidCallback? onOpenEvolutionMirror,
  VoidCallback? onOpenFutureMessages,
  VoidCallback? onOpenCareShare,
  ValueChanged<String>? onOpenDailyRitual,
  VoidCallback? onOpenCheckIn,
  VoidCallback? onOpenPremium,
}) {
  return ProviderScope(
    overrides: [
      authSessionStorageProvider.overrideWithValue(
        _MemoryAuthSessionStorage(
          authSession ??
              _authSession(userId: 'user-123', email: 'user@evolua.test'),
        ),
      ),
      checkInRepositoryProvider.overrideWithValue(
        checkInRepository ?? _FakeCheckInRepository(),
      ),
      checkInInsightPollingConfigProvider.overrideWithValue(pollingConfig),
      trailRepositoryProvider.overrideWithValue(
        trailRepository ?? _FakeTrailRepository(currentJourney: _testTrail()),
      ),
      futureMessageRepositoryProvider.overrideWithValue(
        _FakeFutureMessageRepository(),
      ),
      dailyRitualRepositoryProvider.overrideWithValue(
        dailyRitualRepository ?? _FakeDailyRitualRepository(),
      ),
      subscriptionRepositoryProvider.overrideWithValue(
        subscriptionRepository ?? _FakeSubscriptionRepository(),
      ),
      interstitialAdServiceProvider.overrideWithValue(
        _FakeInterstitialAdService(),
      ),
      if (rewardedAdService != null)
        rewardedAdServiceProvider.overrideWithValue(rewardedAdService),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeHubView(
            profilesCount: 1,
            trailsCount: 1,
            checkInsCount: 4,
            postsCount: 2,
            communitiesCount: 1,
            displayName: 'Leo Respiro',
            mentorPremiumPassActive: false,
            now: now,
            onOpenTrails: onOpenTrails ?? () {},
            onOpenSuggestedTrail: onOpenSuggestedTrail ?? (_) {},
            onOpenFeed: onOpenFeed ?? () {},
            onOpenCommunity: onOpenCommunity ?? () {},
            onOpenProfile: () {},
            onOpenEvolutionMirror: onOpenEvolutionMirror ?? () {},
            onOpenFutureMessages: onOpenFutureMessages ?? () {},
            onOpenFutureMessage: (_) {},
            onOpenCareShare: onOpenCareShare ?? () {},
            onOpenDailyRitual: onOpenDailyRitual ?? (_) {},
            onOpenCheckIn: onOpenCheckIn ?? () {},
            onOpenPremium: onOpenPremium,
          ),
        ),
      ),
    ),
  );
}

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository({
    List<CheckIn>? items,
    this.onCreateRitual,
    this.failCreateRitual = false,
  }) : items = items ?? _checkIns();

  final List<CheckIn> items;
  final void Function(int checkInId, DateTime localDate, String type)?
  onCreateRitual;
  final bool failCreateRitual;
  final List<DateTime> ritualDates = [];
  final List<String> ritualTypes = [];

  @override
  Future<PaginatedResponse<CheckIn>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? mood,
    String? energyRange,
    DateTime? from,
    DateTime? to,
  }) async {
    return PaginatedResponse(
      items: items,
      page: page,
      size: size,
      totalItems: items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<CheckIn> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) async {
    return CheckIn(
      id: 99,
      userId: 'user-123',
      mood: mood,
      reflection: reflection ?? '',
      energyLevel: energyLevel,
      recommendedPractice: 'Respire por dois minutos.',
      aiInsight: _insight(),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<CheckIn> generateDeepReading(
    int checkInId, {
    String style = 'deep',
  }) async {
    return items.firstWhere(
      (item) => item.id == checkInId,
      orElse: () => CheckIn(
        id: checkInId,
        userId: 'user-123',
        mood: 'calmo',
        reflection: '',
        energyLevel: 7,
        recommendedPractice: 'Respire por dois minutos.',
        aiInsight: _insight(),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<CheckIn> saveReading(int checkInId) async {
    return generateDeepReading(checkInId);
  }

  @override
  Future<void> createRitualFromReading(
    int checkInId, {
    required DateTime localDate,
    required String type,
  }) async {
    if (failCreateRitual) {
      throw Exception('ritual unavailable');
    }
    ritualDates.add(localDate);
    ritualTypes.add(type);
    onCreateRitual?.call(checkInId, localDate, type);
  }
}

class _MutableCheckInRepository implements CheckInRepository {
  _MutableCheckInRepository({
    required List<CheckIn> initialItems,
    required this.created,
    required this.listedAfterCreate,
  }) : _items = initialItems;

  List<CheckIn> _items;
  final CheckIn created;
  final List<CheckIn> listedAfterCreate;

  @override
  Future<PaginatedResponse<CheckIn>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? mood,
    String? energyRange,
    DateTime? from,
    DateTime? to,
  }) async {
    return PaginatedResponse(
      items: _items,
      page: page,
      size: size,
      totalItems: _items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<CheckIn> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) async {
    _items = listedAfterCreate;
    return created;
  }

  @override
  Future<CheckIn> generateDeepReading(
    int checkInId, {
    String style = 'deep',
  }) async {
    final refreshed = listedAfterCreate.firstWhere(
      (item) => item.id == checkInId,
      orElse: () => created,
    );
    _items = [refreshed, ..._items.where((item) => item.id != refreshed.id)];
    return refreshed;
  }

  @override
  Future<CheckIn> saveReading(int checkInId) async {
    return generateDeepReading(checkInId);
  }

  @override
  Future<void> createRitualFromReading(
    int checkInId, {
    required DateTime localDate,
    required String type,
  }) async {}
}

class _EventuallyConsistentCheckInRepository implements CheckInRepository {
  _EventuallyConsistentCheckInRepository({
    required this.created,
    required List<List<CheckIn>> lists,
  }) : _lists = List<List<CheckIn>>.from(lists);

  final CheckIn created;
  final List<List<CheckIn>> _lists;

  @override
  Future<PaginatedResponse<CheckIn>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? mood,
    String? energyRange,
    DateTime? from,
    DateTime? to,
  }) async {
    final items = _lists.isEmpty ? const <CheckIn>[] : _lists.removeAt(0);
    return PaginatedResponse(
      items: items,
      page: page,
      size: size,
      totalItems: items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<CheckIn> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) async {
    return created;
  }

  @override
  Future<CheckIn> generateDeepReading(
    int checkInId, {
    String style = 'deep',
  }) async {
    return created;
  }

  @override
  Future<CheckIn> saveReading(int checkInId) async {
    return created;
  }

  @override
  Future<void> createRitualFromReading(
    int checkInId, {
    required DateTime localDate,
    required String type,
  }) async {}
}

class _FakeTrailRepository implements TrailRepository {
  const _FakeTrailRepository({Trail? currentJourney})
    : _currentJourney = currentJourney;

  final Trail? _currentJourney;

  @override
  Future<Trail?> currentJourney() async => _currentJourney;

  @override
  Future<List<TrailJourney>> listInProgressJourneys() async => const [];

  @override
  Future<PaginatedResponse<Trail>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? category,
    bool? premium,
  }) async {
    final items = _currentJourney == null
        ? const <Trail>[]
        : <Trail>[_currentJourney];
    return PaginatedResponse(
      items: items,
      page: page,
      size: size,
      totalItems: items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<Trail> create({
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(int id) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> journey(int trailId) async {
    final trail = _currentJourney;
    if (trail == null) {
      throw StateError('Sem trilha ativa.');
    }
    final steps = [
      const TrailJourneyStep(
        index: 0,
        title: 'Respirar',
        summary: 'Dois minutos de presenca.',
        content: 'Respire por quatro ciclos.',
        type: 'EXERCISE',
        status: 'completed',
        estimatedMinutes: 2,
        mediaLinks: [],
      ),
      const TrailJourneyStep(
        index: 1,
        title: 'Escolher',
        summary: 'Uma proxima acao simples.',
        content: 'Escolha uma acao pequena.',
        type: 'REFLECTION',
        status: 'current',
        estimatedMinutes: 4,
        mediaLinks: [],
      ),
    ];
    return TrailJourney(
      trail: trail,
      steps: steps,
      progress: TrailProgress(
        currentStepIndex: 1,
        completedStepIndexes: const [0],
        startedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        completedAt: null,
      ),
      progressPercent: 50,
      nextStep: steps.last,
    );
  }

  @override
  Future<TrailJourney> startJourney(int trailId) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> completeStep(int trailId, int stepIndex) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> updateVideoProgress({
    required int trailId,
    required int stepIndex,
    required int watchedSeconds,
    required int durationSeconds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TrailStepResponse?> stepResponse({
    required int trailId,
    required int stepIndex,
  }) async {
    return null;
  }

  @override
  Future<TrailStepResponse> saveStepResponse({
    required int trailId,
    required int stepIndex,
    required String responseText,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<TrailStepResponse>> listStepResponses({int limit = 20}) async {
    return const [];
  }

  @override
  Future<Trail> update({
    required int id,
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  }) {
    throw UnimplementedError();
  }
}

class _FakeFutureMessageRepository implements FutureMessageRepository {
  @override
  Future<PaginatedResponse<FutureMessage>> list({
    required int page,
    required int size,
    List<String>? statuses,
  }) async {
    return PaginatedResponse<FutureMessage>.empty(page: page, size: size);
  }

  @override
  Future<PaginatedResponse<FutureMessage>> delivered({
    required int page,
    required int size,
  }) async {
    return PaginatedResponse<FutureMessage>.empty(page: page, size: size);
  }

  @override
  Future<FutureMessage> create(FutureMessageDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<FutureMessage> get(int id) {
    throw UnimplementedError();
  }

  @override
  Future<void> heartbeat() async {}

  @override
  Future<FutureMessage> markRead(int id) {
    throw UnimplementedError();
  }

  @override
  Future<FutureMessage> react(int id, String reaction) {
    throw UnimplementedError();
  }
}

class _FakeDailyRitualRepository implements DailyRitualRepository {
  _FakeDailyRitualRepository({this.morning, this.evening});

  DailyRitual? morning;
  DailyRitual? evening;

  @override
  Future<DailyRitual?> today({
    required String type,
    required DateTime localDate,
  }) async {
    return type == DailyRitualType.evening ? evening : morning;
  }

  @override
  Future<DailyRitual> create(DailyRitualDraft draft) {
    throw UnimplementedError();
  }
}

class _StaticCheckInController extends CheckInController {
  _StaticCheckInController(this.value);

  final CheckInHistoryState value;

  @override
  Future<CheckInHistoryState> build() async => value;
}

class _FakeRewardedAdService implements RewardedAdService {
  _FakeRewardedAdService({
    this.result = RewardedAdResult.rewarded,
    this.resultGate,
    this.error,
  });

  final RewardedAdResult result;
  final Completer<RewardedAdResult>? resultGate;
  final Object? error;
  int showCalls = 0;
  String? rewardType;

  @override
  Future<RewardedAdResult> showRewardedAd({
    required String rewardType,
    String? contextId,
    void Function()? onAdClosed,
  }) async {
    showCalls++;
    this.rewardType = rewardType;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return resultGate == null ? result : resultGate!.future;
  }
}

class _FakeInterstitialAdService implements InterstitialAdService {
  int rewardedShownRecords = 0;

  @override
  Future<void> preload() async {}

  @override
  Future<bool> maybeShow({
    required InterstitialTrigger trigger,
    required AuthSession? session,
  }) async {
    return false;
  }

  @override
  Future<void> recordRewardedAdShown({AuthSession? session}) async {
    rewardedShownRecords++;
  }

  @override
  void dispose() {}
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({
    this.premium = false,
    this.rewardedCreditsGrantedToday = 0,
    this.rewardedCreditsUsedToday = 0,
    List<MonetizationAccessStatus>? accessStatuses,
  }) : _accessStatuses = List<MonetizationAccessStatus>.of(
         accessStatuses ?? const [],
       );

  final bool premium;
  final int rewardedCreditsGrantedToday;
  final int rewardedCreditsUsedToday;
  final List<MonetizationAccessStatus> _accessStatuses;
  int accessCalls = 0;

  @override
  Future<List<PlanView>> listPlans() async => const [];

  @override
  Future<CurrentSubscription?> current() async => CurrentSubscription(
    planCode: premium ? 'premium-monthly' : 'essential-free',
    status: 'ACTIVE',
    billingCycle: 'MONTHLY',
    premium: premium,
    adsEnabled: !premium,
    aiQuotaRemainingToday: premium ? 999 : 0,
    mentorPremiumPassActive: false,
    mentorRewardedAdAvailable: false,
  );

  @override
  Future<CurrentSubscription?> cancel() async => current();

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
  Future<AdRewardSession> grantClientOpenedReward(String sessionId) {
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
  }) async {
    accessCalls++;
    if (_accessStatuses.isNotEmpty) {
      return _accessStatuses.removeAt(0);
    }
    return _accessStatus(
      resource: resource,
      contextId: contextId,
      allowed: premium,
      premium: premium,
      rewardedAdAvailable: !premium,
      upgradeRecommended: !premium,
      rewardedCreditsGrantedToday: rewardedCreditsGrantedToday,
      rewardedCreditsUsedToday: rewardedCreditsUsedToday,
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

class _PendingSubscriptionRepository extends _FakeSubscriptionRepository {
  @override
  Future<CurrentSubscription?> current() =>
      Completer<CurrentSubscription?>().future;
}

MonetizationAccessStatus _accessStatus({
  String resource = RewardResources.extraCheckIn,
  String? contextId,
  bool allowed = false,
  bool premium = false,
  bool rewardedAdAvailable = true,
  bool upgradeRecommended = true,
  DateTime? entitlementExpiresAt,
  int rewardedCreditsGrantedToday = 0,
  int rewardedCreditsUsedToday = 0,
}) {
  return MonetizationAccessStatus(
    resource: resource,
    contextId: contextId,
    allowed: allowed,
    premium: premium,
    rewardedAdAvailable: rewardedAdAvailable,
    upgradeRecommended: upgradeRecommended,
    entitlementExpiresAt: entitlementExpiresAt,
    rewardedCreditsGrantedToday: rewardedCreditsGrantedToday,
    rewardedCreditsUsedToday: rewardedCreditsUsedToday,
  );
}

class _MemoryAuthSessionStorage implements AuthSessionStorage {
  _MemoryAuthSessionStorage(AuthSession session)
    : _value = jsonEncode(session.toJson());

  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async {
    _value = value;
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}

List<CheckIn> _checkIns() {
  final now = DateTime.now();
  return [
    CheckIn(
      id: 1,
      userId: 'user-123',
      mood: 'ansioso',
      reflection: 'manha intensa',
      energyLevel: 6,
      recommendedPractice: 'Respiracao curta',
      aiInsight: _insight(),
      createdAt: now,
    ),
    CheckIn(
      id: 2,
      userId: 'user-123',
      mood: 'calmo',
      reflection: 'andou bem',
      energyLevel: 8,
      recommendedPractice: 'Caminhada curta',
      aiInsight: null,
      createdAt: now.subtract(const Duration(days: 1, hours: 1)),
    ),
    CheckIn(
      id: 3,
      userId: 'user-123',
      mood: 'cansado',
      reflection: 'sono ruim',
      energyLevel: 5,
      recommendedPractice: 'Pausa guiada',
      aiInsight: null,
      createdAt: now.subtract(const Duration(days: 2, hours: 2)),
    ),
  ];
}

AuthSession _authSession({
  required String userId,
  required String email,
  List<String> roles = const ['ROLE_USER'],
}) {
  return AuthSession(
    userId: userId,
    email: email,
    roles: roles,
    accessToken: _jwt(userId: userId, email: email, roles: roles),
    refreshToken: 'refresh-$userId',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
}

String _jwt({
  required String userId,
  required String email,
  List<String> roles = const ['ROLE_USER'],
}) {
  String encode(Map<String, Object> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  final header = encode({'alg': 'none', 'typ': 'JWT'});
  final payload = encode({
    'sub': userId,
    'email': email,
    'roles': roles,
    'exp':
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000,
  });
  return '$header.$payload.signature';
}

CheckInAiInsight _insight({
  String insight =
      'Seu momento aponta para ansiedade leve e pede uma acao simples para recuperar clareza sem abrir muitas frentes agora.',
  bool fallbackUsed = false,
}) {
  return CheckInAiInsight(
    insight: insight,
    suggestedAction:
        'Faca uma respiracao de 4 ciclos e escolha uma tarefa pequena.',
    riskLevel: 'low',
    suggestedTrailId: 1,
    suggestedTrailTitle: 'Clareza em 8 minutos',
    suggestedTrailReason:
        'Ajuda a reduzir sobrecarga e escolher o proximo passo.',
    suggestedSpace: null,
    journeyPlan: null,
    generatedTrailDraft: null,
    fallbackUsed: fallbackUsed,
  );
}

DailyRitual _testRitual(String type) {
  return DailyRitual(
    id: type == DailyRitualType.evening ? 2 : 1,
    localDate: DateTime(2026, 5, 7),
    type: type,
    emotionalState: 'calmo',
    dayNeed: 'clareza',
    intention: 'agir com calma',
    microAction: 'pausar antes de reagir',
    createdAt: DateTime(2026, 5, 7, 8),
  );
}

CheckIn _testCheckIn({
  required int id,
  required DateTime createdAt,
  String mood = 'calmo',
  String reflection = 'check-in do dia',
  int energyLevel = 7,
}) {
  return CheckIn(
    id: id,
    userId: 'user-123',
    mood: mood,
    reflection: reflection,
    energyLevel: energyLevel,
    recommendedPractice: 'Respire por dois minutos.',
    aiInsight: _insight(),
    createdAt: createdAt,
  );
}

Trail _testTrail() {
  return Trail(
    id: 1,
    userId: 'user-123',
    title: 'Clareza em 8 minutos',
    summary: 'Uma trilha curta para organizar o momento sem pressa.',
    content: 'Respire, nomeie e escolha.',
    category: 'clareza',
    premium: false,
    privateTrail: false,
    activeJourney: true,
    generatedByAi: true,
    journeyKey: 'clareza',
    sourceStyle: 'briefing',
    accessible: true,
    mediaLinks: const [],
    steps: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}
