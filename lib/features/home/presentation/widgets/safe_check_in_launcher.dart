import 'dart:async';

import 'package:evolua_frontend/features/ads/application/monetization_access_controller.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/ads/presentation/widgets/monetization_prompt.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_day.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ExtraCheckInGateAccessDecision {
  openCheckIn,
  exhaustedToday,
  watchRewarded,
}

enum _SafeCheckInInitialDecision { openDirect, showGate, loadFailed }

bool shouldGateExtraCheckIn(WidgetRef ref, {DateTime? now}) {
  return shouldGateExtraCheckInFromState(
    session: ref.read(authControllerProvider).asData?.value,
    subscriptionState: ref.read(subscriptionControllerProvider),
    checkInState: ref.read(checkInControllerProvider),
    now: now,
  );
}

bool shouldGateExtraCheckInFromState({
  required AuthSession? session,
  required AsyncValue<SubscriptionScreenState> subscriptionState,
  required AsyncValue<CheckInHistoryState> checkInState,
  DateTime? now,
}) {
  if (session == null || session.isPremium == true) {
    return false;
  }

  if (!subscriptionState.hasValue) {
    return false;
  }
  final currentSubscription = subscriptionState.asData?.value.current;
  if (currentSubscription?.premium == true) {
    return false;
  }

  if (!checkInState.hasValue) {
    return false;
  }
  final history = checkInState.asData?.value;
  if (history == null || !history.belongsToUser(session.userId)) {
    return false;
  }

  return hasCheckInToday(
    history.result.items,
    latestCreatedCheckIn: history.latestCreatedCheckIn,
    now: now,
  );
}

String checkInEntryLabel(WidgetRef ref, {DateTime? now}) {
  return shouldGateExtraCheckIn(ref, now: now)
      ? 'Novo check-in'
      : 'Fazer check-in';
}

class SafeCheckInLauncher {
  static const _recheckAttempts = 3;
  static const _recheckDelay = Duration(milliseconds: 1500);
  static const _gateStateTimeout = Duration(seconds: 8);

  bool _busy = false;
  int _attemptSequence = 0;

  Future<void> open({
    required BuildContext context,
    required WidgetRef ref,
    required bool Function() isMounted,
    required FutureOr<void> Function() openCheckIn,
    VoidCallback? onOpenPremium,
    VoidCallback? onBlockingUiPresented,
    DateTime? now,
  }) async {
    if (_busy) {
      return;
    }

    _busy = true;
    try {
      var openCheckInAfterGate = false;
      final initialAttemptId = ++_attemptSequence;
      final initialOpenDecision = await _resolveInitialOpenDecision(
        ref: ref,
        attemptId: initialAttemptId,
        now: now,
      );
      if (!isMounted() || !context.mounted) {
        return;
      }
      if (initialOpenDecision == _SafeCheckInInitialDecision.openDirect) {
        _logFinalDecision(attemptId: initialAttemptId, openCheckIn: true);
        onBlockingUiPresented?.call();
        await Future<void>.sync(openCheckIn);
        return;
      }
      if (initialOpenDecision == _SafeCheckInInitialDecision.loadFailed) {
        _logFinalDecision(attemptId: initialAttemptId, openCheckIn: false);
        _showGateStateLoadFailure(context);
        return;
      }

      final initialDecision = await _extraCheckInGateAccessDecision(
        ref: ref,
        attemptId: initialAttemptId,
        source: 'open_gate_access_check',
      );
      if (!isMounted() || !context.mounted) {
        return;
      }
      if (initialDecision == ExtraCheckInGateAccessDecision.openCheckIn) {
        _logFinalDecision(attemptId: initialAttemptId, openCheckIn: true);
        openCheckInAfterGate = true;
      } else {
        RewardedAdResult? rewardFailure;
        var rewardExhaustedToday =
            initialDecision == ExtraCheckInGateAccessDecision.exhaustedToday;
        var isRewardLoading = false;
        onBlockingUiPresented?.call();
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          builder: (sheetContext) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                final currentFailure = rewardFailure;
                final isPendingConfirmation = _isPendingConfirmation(
                  currentFailure,
                );
                final bottomPadding = rewardExhaustedToday ? 24.0 : 16.0;
                return SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      bottomPadding +
                          MediaQuery.of(sheetContext).viewInsets.bottom,
                    ),
                    child: RewardedAdPrompt(
                      title: rewardExhaustedToday
                          ? 'Check-in extra já usado hoje'
                          : _gateTitle(currentFailure),
                      message: rewardExhaustedToday
                          ? 'Você já usou o desbloqueio por anúncio de hoje. Para registrar outro check-in agora, veja o Premium ou volte amanhã.'
                          : _gateMessage(currentFailure),
                      rewardLabel: rewardExhaustedToday
                          ? ''
                          : isPendingConfirmation
                          ? 'Vamos conferir se seu check-in já foi liberado.'
                          : 'Assistir anúncio libera mais um check-in hoje.',
                      rewardedAdAvailable: !rewardExhaustedToday,
                      isRewardLoading: isRewardLoading,
                      watchLabel: isPendingConfirmation
                          ? 'Verificar liberação'
                          : 'Assistir anúncio',
                      loadingLabel: isPendingConfirmation
                          ? 'Verificando'
                          : 'Carregando anúncio',
                      premiumLabel: 'Ver Premium',
                      secondaryLabel: 'Agora não',
                      onWatchRewardedAd: rewardExhaustedToday
                          ? null
                          : () async {
                              if (isRewardLoading) {
                                return;
                              }
                              setSheetState(() {
                                isRewardLoading = true;
                              });
                              final pendingResult =
                                  _isPendingConfirmation(rewardFailure)
                                  ? rewardFailure
                                  : null;
                              setSheetState(() {
                                if (pendingResult == null) {
                                  rewardFailure = null;
                                }
                                rewardExhaustedToday = false;
                              });
                              final attemptId = ++_attemptSequence;
                              debugPrint(
                                'Evolua gate extra check-in attemptId=$attemptId started',
                              );
                              var result =
                                  pendingResult ?? RewardedAdResult.loadFailed;
                              var openCheckIn = false;
                              try {
                                if (pendingResult != null) {
                                  openCheckIn = await _shouldOpenAfterReward(
                                    ref: ref,
                                    isMounted: isMounted,
                                    result: pendingResult,
                                    attemptId: attemptId,
                                  );
                                } else {
                                  final accessDecision =
                                      await _extraCheckInGateAccessDecision(
                                        ref: ref,
                                        attemptId: attemptId,
                                        source: 'pre_reward_access_check',
                                      );
                                  if (accessDecision ==
                                      ExtraCheckInGateAccessDecision
                                          .openCheckIn) {
                                    openCheckIn = true;
                                    _logFinalDecision(
                                      attemptId: attemptId,
                                      openCheckIn: true,
                                    );
                                  } else if (accessDecision ==
                                      ExtraCheckInGateAccessDecision
                                          .exhaustedToday) {
                                    rewardExhaustedToday = true;
                                    _logFinalDecision(
                                      attemptId: attemptId,
                                      openCheckIn: false,
                                    );
                                  } else {
                                    result = await ref
                                        .read(
                                          monetizationAccessControllerProvider
                                              .notifier,
                                        )
                                        .unlockWithRewardedAdResult(
                                          resource:
                                              RewardResources.extraCheckIn,
                                        );
                                    openCheckIn = await _shouldOpenAfterReward(
                                      ref: ref,
                                      isMounted: isMounted,
                                      result: result,
                                      attemptId: attemptId,
                                    );
                                    if (!openCheckIn &&
                                        result == RewardedAdResult.loadFailed) {
                                      rewardExhaustedToday =
                                          await _isRewardExhaustedToday(
                                            ref: ref,
                                            attemptId: attemptId,
                                            source:
                                                'post_reward_gate_state_check',
                                          );
                                    }
                                  }
                                }
                              } catch (error) {
                                debugPrint(
                                  'Evolua gate extra check-in attemptId=$attemptId '
                                  'failed before result error=$error',
                                );
                                result = RewardedAdResult.loadFailed;
                                openCheckIn = false;
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() {
                                    isRewardLoading = false;
                                  });
                                }
                              }
                              if (!isMounted() || !sheetContext.mounted) {
                                return;
                              }
                              if (openCheckIn) {
                                openCheckInAfterGate = true;
                                Navigator.of(sheetContext).pop();
                                return;
                              }
                              setSheetState(() {
                                rewardFailure = result;
                              });
                            },
                      onOpenPremium: onOpenPremium == null
                          ? null
                          : () {
                              Navigator.of(sheetContext).maybePop();
                              onOpenPremium.call();
                            },
                      onSecondary: () => Navigator.of(sheetContext).maybePop(),
                    ),
                  ),
                );
              },
            );
          },
        );
      }

      if (isMounted() && openCheckInAfterGate) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await WidgetsBinding.instance.endOfFrame;
        if (isMounted()) {
          onBlockingUiPresented?.call();
          await Future<void>.sync(openCheckIn);
        }
      }
    } finally {
      _busy = false;
    }
  }

  Future<_SafeCheckInInitialDecision> _resolveInitialOpenDecision({
    required WidgetRef ref,
    required int attemptId,
    DateTime? now,
  }) async {
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) {
      _logInitialState(
        attemptId: attemptId,
        sessionUserId: null,
        subscriptionState: ref.read(subscriptionControllerProvider),
        checkInState: ref.read(checkInControllerProvider),
        historyBelongsToUser: false,
        decision: 'loadFailed',
      );
      return _SafeCheckInInitialDecision.loadFailed;
    }

    if (session.isPremium == true) {
      _logInitialState(
        attemptId: attemptId,
        sessionUserId: session.userId,
        subscriptionState: ref.read(subscriptionControllerProvider),
        checkInState: ref.read(checkInControllerProvider),
        historyBelongsToUser: null,
        decision: 'openDirect',
      );
      return _SafeCheckInInitialDecision.openDirect;
    }

    try {
      final subscription = await _loadSubscriptionState(ref);
      final currentSubscription = subscription.current;
      if (currentSubscription?.premium == true) {
        _logInitialState(
          attemptId: attemptId,
          sessionUserId: session.userId,
          subscriptionState: ref.read(subscriptionControllerProvider),
          checkInState: ref.read(checkInControllerProvider),
          historyBelongsToUser: null,
          decision: 'openDirect',
        );
        return _SafeCheckInInitialDecision.openDirect;
      }

      final history = await _loadCheckInHistoryState(
        ref: ref,
        sessionUserId: session.userId,
        forceRefreshWhenStale: true,
      );
      final belongsToUser = history.belongsToUser(session.userId);
      if (!belongsToUser) {
        _logInitialState(
          attemptId: attemptId,
          sessionUserId: session.userId,
          subscriptionState: ref.read(subscriptionControllerProvider),
          checkInState: ref.read(checkInControllerProvider),
          historyBelongsToUser: false,
          decision: 'loadFailed',
        );
        return _SafeCheckInInitialDecision.loadFailed;
      }

      final hasToday = hasCheckInToday(
        history.result.items,
        latestCreatedCheckIn: history.latestCreatedCheckIn,
        now: now,
      );
      final decision = hasToday
          ? _SafeCheckInInitialDecision.showGate
          : _SafeCheckInInitialDecision.openDirect;
      _logInitialState(
        attemptId: attemptId,
        sessionUserId: session.userId,
        subscriptionState: ref.read(subscriptionControllerProvider),
        checkInState: ref.read(checkInControllerProvider),
        historyBelongsToUser: belongsToUser,
        decision: hasToday ? 'gate' : 'openDirect',
      );
      return decision;
    } catch (error) {
      debugPrint(
        'Evolua gate extra check-in attemptId=$attemptId '
        'initial state failed sessionUserId=${session.userId} error=$error',
      );
      _logInitialState(
        attemptId: attemptId,
        sessionUserId: session.userId,
        subscriptionState: ref.read(subscriptionControllerProvider),
        checkInState: ref.read(checkInControllerProvider),
        historyBelongsToUser: null,
        decision: 'loadFailed',
      );
      return _SafeCheckInInitialDecision.loadFailed;
    }
  }

  Future<SubscriptionScreenState> _loadSubscriptionState(WidgetRef ref) async {
    final state = ref.read(subscriptionControllerProvider);
    if (state.hasValue && state.asData?.value != null) {
      return state.requireValue;
    }
    return ref
        .read(subscriptionControllerProvider.future)
        .timeout(_gateStateTimeout);
  }

  Future<CheckInHistoryState> _loadCheckInHistoryState({
    required WidgetRef ref,
    required String sessionUserId,
    required bool forceRefreshWhenStale,
  }) async {
    final state = ref.read(checkInControllerProvider);
    if (state.hasValue &&
        state.asData?.value != null &&
        state.requireValue.belongsToUser(sessionUserId)) {
      return state.requireValue;
    }

    var history = await ref
        .read(checkInControllerProvider.future)
        .timeout(_gateStateTimeout);
    if (history.belongsToUser(sessionUserId) || !forceRefreshWhenStale) {
      return history;
    }

    ref.invalidate(checkInControllerProvider);
    history = await ref
        .read(checkInControllerProvider.future)
        .timeout(_gateStateTimeout);
    return history;
  }

  Future<bool> _shouldOpenAfterReward({
    required WidgetRef ref,
    required bool Function() isMounted,
    required RewardedAdResult result,
    required int attemptId,
  }) async {
    debugPrint(
      'Evolua gate extra check-in attemptId=$attemptId '
      'reward result=${result.name}',
    );
    if (result == RewardedAdResult.rewarded) {
      _logFinalDecision(attemptId: attemptId, openCheckIn: true);
      return true;
    }

    if (result == RewardedAdResult.loadFailed) {
      final hasAccess = await _hasAccess(
        ref: ref,
        attemptId: attemptId,
        source: 'load_failed_access_recheck',
      );
      _logFinalDecision(attemptId: attemptId, openCheckIn: hasAccess);
      return hasAccess;
    }

    final shouldRecheck =
        result == RewardedAdResult.rewardConfirmedButAccessDenied ||
        result == RewardedAdResult.timeout;
    if (!shouldRecheck) {
      _logFinalDecision(attemptId: attemptId, openCheckIn: false);
      return false;
    }

    for (var attempt = 1; attempt <= _recheckAttempts; attempt++) {
      if (attempt > 1) {
        await Future<void>.delayed(_recheckDelay);
      }
      if (!isMounted()) {
        _logFinalDecision(attemptId: attemptId, openCheckIn: false);
        return false;
      }

      try {
        final access = await ref
            .read(monetizationAccessControllerProvider.notifier)
            .access(resource: RewardResources.extraCheckIn);
        final hasPendingRewardCredit =
            access.rewardedCreditsGrantedToday >
            access.rewardedCreditsUsedToday;
        debugPrint(
          'Evolua gate extra check-in attemptId=$attemptId '
          'recheck attempt number=$attempt '
          'access.allowed=${access.allowed} '
          'rewardedCreditsGrantedToday=${access.rewardedCreditsGrantedToday} '
          'rewardedCreditsUsedToday=${access.rewardedCreditsUsedToday} '
          'hasPendingRewardCredit=$hasPendingRewardCredit',
        );

        if (access.allowed ||
            access.entitlementExpiresAt != null ||
            hasPendingRewardCredit) {
          _logFinalDecision(attemptId: attemptId, openCheckIn: true);
          return true;
        }
      } catch (error) {
        debugPrint(
          'Evolua gate extra check-in attemptId=$attemptId '
          'recheck attempt number=$attempt '
          'failed error=$error',
        );
      }
    }

    _logFinalDecision(attemptId: attemptId, openCheckIn: false);
    return false;
  }

  Future<bool> _hasAccess({
    required WidgetRef ref,
    required int attemptId,
    required String source,
  }) async {
    final decision = await _extraCheckInGateAccessDecision(
      ref: ref,
      attemptId: attemptId,
      source: source,
    );
    return decision == ExtraCheckInGateAccessDecision.openCheckIn;
  }

  Future<bool> _isRewardExhaustedToday({
    required WidgetRef ref,
    required int attemptId,
    required String source,
  }) async {
    final decision = await _extraCheckInGateAccessDecision(
      ref: ref,
      attemptId: attemptId,
      source: source,
    );
    return decision == ExtraCheckInGateAccessDecision.exhaustedToday;
  }

  Future<ExtraCheckInGateAccessDecision> _extraCheckInGateAccessDecision({
    required WidgetRef ref,
    required int attemptId,
    required String source,
  }) async {
    try {
      final access = await ref
          .read(monetizationAccessControllerProvider.notifier)
          .access(resource: RewardResources.extraCheckIn);
      final hasPendingRewardCredit =
          access.rewardedCreditsGrantedToday > access.rewardedCreditsUsedToday;
      final rewardExhaustedToday =
          access.rewardedCreditsGrantedToday > 0 &&
          access.rewardedCreditsGrantedToday <= access.rewardedCreditsUsedToday;
      debugPrint(
        'Evolua gate extra check-in attemptId=$attemptId '
        '$source '
        'access.allowed=${access.allowed} '
        'rewardedCreditsGrantedToday=${access.rewardedCreditsGrantedToday} '
        'rewardedCreditsUsedToday=${access.rewardedCreditsUsedToday} '
        'hasPendingRewardCredit=$hasPendingRewardCredit '
        'rewardExhaustedToday=$rewardExhaustedToday',
      );
      if (access.allowed ||
          access.entitlementExpiresAt != null ||
          hasPendingRewardCredit) {
        return ExtraCheckInGateAccessDecision.openCheckIn;
      }
      if (rewardExhaustedToday) {
        return ExtraCheckInGateAccessDecision.exhaustedToday;
      }
      return ExtraCheckInGateAccessDecision.watchRewarded;
    } catch (error) {
      debugPrint(
        'Evolua gate extra check-in attemptId=$attemptId '
        '$source failed error=$error',
      );
      return ExtraCheckInGateAccessDecision.watchRewarded;
    }
  }

  void _logFinalDecision({required int attemptId, required bool openCheckIn}) {
    debugPrint(
      'Evolua gate extra check-in attemptId=$attemptId '
      'final decision openCheckIn=$openCheckIn',
    );
  }

  void _logInitialState({
    required int attemptId,
    required String? sessionUserId,
    required AsyncValue<SubscriptionScreenState> subscriptionState,
    required AsyncValue<CheckInHistoryState> checkInState,
    required bool? historyBelongsToUser,
    required String decision,
  }) {
    debugPrint(
      'Evolua gate extra check-in attemptId=$attemptId '
      'sessionUserId=${sessionUserId ?? 'none'} '
      'subscriptionState.hasValue=${subscriptionState.hasValue} '
      'checkInState.hasValue=${checkInState.hasValue} '
      'historyBelongsToUser=$historyBelongsToUser '
      'decision=$decision',
    );
  }

  void _showGateStateLoadFailure(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não conseguimos verificar seu limite agora. Tente novamente em instantes.',
        ),
      ),
    );
  }

  bool _isPendingConfirmation(RewardedAdResult? result) {
    return result == RewardedAdResult.timeout ||
        result == RewardedAdResult.rewardConfirmedButAccessDenied;
  }

  String _gateTitle(RewardedAdResult? result) {
    return switch (result) {
      RewardedAdResult.rewardConfirmedButAccessDenied =>
        'Confirmação em andamento',
      RewardedAdResult.dismissedWithoutReward => 'Anúncio não concluído',
      RewardedAdResult.noFill => 'Nenhum anúncio disponível agora',
      RewardedAdResult.loadFailed => 'Não conseguimos carregar o anúncio agora',
      RewardedAdResult.showFailed => 'Não conseguimos abrir o anúncio agora',
      RewardedAdResult.unsupported => 'Anúncio indisponível neste dispositivo',
      RewardedAdResult.timeout => 'Verificando liberação',
      RewardedAdResult.rewarded || null => 'Liberar novo check-in',
    };
  }

  String _gateMessage(RewardedAdResult? result) {
    return switch (result) {
      RewardedAdResult.rewardConfirmedButAccessDenied =>
        'Recebemos a conclusão do anúncio, mas ainda estamos confirmando a liberação. Tente novamente em alguns segundos.',
      RewardedAdResult.dismissedWithoutReward =>
        'Para liberar outro check-in hoje, é preciso concluir o anúncio até receber a recompensa.',
      RewardedAdResult.timeout =>
        'Não conseguimos confirmar a liberação do anúncio a tempo. Tente verificar novamente em alguns instantes, veja o Premium ou volte amanhã.',
      RewardedAdResult.noFill =>
        'Nenhum anúncio disponível agora. Tente novamente em alguns instantes, veja o Premium ou volte amanhã.',
      RewardedAdResult.loadFailed =>
        'Não conseguimos carregar um anúncio neste momento. Tente novamente em alguns instantes, veja o Premium ou volte amanhã.',
      RewardedAdResult.showFailed =>
        'Não conseguimos abrir o anúncio neste momento. Tente novamente em alguns instantes, veja o Premium ou volte amanhã.',
      RewardedAdResult.unsupported =>
        'Anúncios não estão disponíveis neste dispositivo. Você pode ver o Premium ou voltar amanhã.',
      RewardedAdResult.rewarded || null =>
        'Você já fez seu check-in gratuito de hoje. Para registrar outro agora, você pode assistir a um anúncio, ver o Premium ou voltar amanhã.',
    };
  }
}
