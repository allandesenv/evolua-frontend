import 'dart:async';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_error_message.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/ads/application/monetization_access_controller.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/ads/presentation/widgets/monetization_prompt.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_speech_transcription_service.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _extraCheckInRewardResource = RewardResources.extraCheckIn;
const _checkInSubmitTimeout = Duration(seconds: 15);

enum _CheckInSubmitResult {
  success,
  limitReached,
  networkError,
  serverError,
  rewardConfirmedButStillBlocked,
  unknownError,
}

class CheckInQuickPage extends StatelessWidget {
  const CheckInQuickPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      resizeToAvoidBottomInset: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveBreakpoints.pagePadding(context),
          vertical: 16,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: CheckInQuickView(
                onCompleted: () {
                  context.go('/home');
                },
                onCancel: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                onOpenPremium: () {
                  context.go('/home');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CheckInQuickView extends ConsumerStatefulWidget {
  const CheckInQuickView({
    super.key,
    this.onCompleted,
    this.onCancel,
    this.onOpenPremium,
  });

  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;
  final VoidCallback? onOpenPremium;

  @override
  ConsumerState<CheckInQuickView> createState() => _CheckInQuickViewState();
}

class _CheckInQuickViewState extends ConsumerState<CheckInQuickView> {
  final _reflectionController = TextEditingController();
  final _otherMoodController = TextEditingController();
  String _selectedMoodValue = _defaultMoodValue;
  String _selectedMoodLabel = '';
  double _energyLevel = 7;
  bool _isSubmitting = false;
  bool _isRewardLoading = false;
  bool _isListeningReflection = false;
  String _dictationBaseText = '';
  late final CheckInSpeechTranscriptionService _speechService;

  @override
  void initState() {
    super.initState();
    _speechService = ref.read(checkInSpeechTranscriptionServiceProvider);
    ref.listenManual(checkInControllerProvider, (previous, next) {
      if (!next.hasError || !mounted || _isCheckInLimitError(next.error)) {
        return;
      }

      AppSnackBar.show(
        context,
        message: _errorMessage(next.error),
        icon: Icons.favorite_border_rounded,
      );
    });
  }

  @override
  void dispose() {
    _speechService.cancel();
    _reflectionController.dispose();
    _otherMoodController.dispose();
    super.dispose();
  }

  Future<void> _toggleReflectionDictation() async {
    if (_isSubmitting) {
      return;
    }
    if (_isListeningReflection || _speechService.isListening) {
      await _speechService.stop();
      if (mounted) {
        setState(() => _isListeningReflection = false);
      }
      return;
    }

    final localeId = _speechLocaleId(context);
    final available = await _speechService.initialize(
      localeId: localeId,
      onStatus: _handleSpeechStatus,
      onError: _handleSpeechError,
    );
    if (!mounted) {
      return;
    }
    if (!available) {
      AppSnackBar.show(
        context,
        message: context.l10n.checkInMicrophoneUnavailable,
        icon: Icons.mic_off_rounded,
      );
      return;
    }

    _dictationBaseText = _reflectionController.text.trim();
    setState(() => _isListeningReflection = true);
    try {
      await _speechService.listen(
        localeId: localeId,
        onResult: _applySpeechResult,
      );
    } catch (_) {
      _handleSpeechError(_CheckInSpeechStartException());
    }
  }

  void _applySpeechResult(String text) {
    if (!mounted || text.trim().isEmpty) {
      return;
    }
    final transcript = text.trim();
    final nextText = _dictationBaseText.isEmpty
        ? transcript
        : '$_dictationBaseText $transcript';
    _reflectionController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }
    if (status == 'done' || status == 'notListening') {
      setState(() => _isListeningReflection = false);
    }
  }

  void _handleSpeechError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() => _isListeningReflection = false);
    AppSnackBar.show(
      context,
      message: context.l10n.checkInSpeechTranscriptionUnavailable,
      icon: Icons.mic_off_rounded,
    );
  }

  void _showSavingInProgressMessage() {
    if (!mounted) {
      return;
    }
    AppSnackBar.show(
      context,
      message: context.l10n.checkInSavingInProgress,
      icon: Icons.hourglass_top_rounded,
    );
  }

  Future<_CheckInSubmitResult> _submit({
    bool allowLimitUnlock = true,
    bool rewardConfirmed = false,
  }) async {
    if (_isSubmitting) {
      _showSavingInProgressMessage();
      return _CheckInSubmitResult.unknownError;
    }

    setState(() => _isSubmitting = true);
    try {
      try {
        await ref
            .read(checkInControllerProvider.notifier)
            .create(
              mood: _submissionMood,
              reflection: _reflectionController.text.trim().isEmpty
                  ? null
                  : _reflectionController.text.trim(),
              energyLevel: _energyLevel.round(),
            )
            .timeout(_checkInSubmitTimeout);
      } on TimeoutException {
        if (mounted) {
          AppSnackBar.show(
            context,
            message: context.l10n.checkInSaveTimeout,
            icon: Icons.favorite_border_rounded,
          );
        }
        return _CheckInSubmitResult.networkError;
      } catch (error) {
        if (!mounted) {
          return _CheckInSubmitResult.unknownError;
        }
        if (allowLimitUnlock && _isCheckInLimitError(error)) {
          setState(() => _isSubmitting = false);
          await _showExtraCheckInUnlockSheet();
          return _CheckInSubmitResult.limitReached;
        } else if (!allowLimitUnlock && _isCheckInLimitError(error)) {
          return rewardConfirmed
              ? _CheckInSubmitResult.rewardConfirmedButStillBlocked
              : _CheckInSubmitResult.limitReached;
        } else {
          final result = _submitErrorResult(error);
          AppSnackBar.show(
            context,
            message: _submitErrorMessage(
              result,
              context.l10n,
              fallbackError: error,
            ),
            icon: Icons.favorite_border_rounded,
          );
          return result;
        }
      }

      if (!mounted) {
        return _CheckInSubmitResult.unknownError;
      }

      final asyncState = ref.read(checkInControllerProvider);
      if (asyncState.hasError) {
        if (allowLimitUnlock && _isCheckInLimitError(asyncState.error)) {
          setState(() => _isSubmitting = false);
          await _showExtraCheckInUnlockSheet();
          return _CheckInSubmitResult.limitReached;
        }
        if (!allowLimitUnlock && _isCheckInLimitError(asyncState.error)) {
          return rewardConfirmed
              ? _CheckInSubmitResult.rewardConfirmedButStillBlocked
              : _CheckInSubmitResult.limitReached;
        }
        final result = _submitErrorResult(asyncState.error);
        AppSnackBar.show(
          context,
          message: _submitErrorMessage(
            result,
            context.l10n,
            fallbackError: asyncState.error,
          ),
          icon: Icons.favorite_border_rounded,
        );
        return result;
      }

      _reflectionController.clear();
      _otherMoodController.clear();
      final insight = ref
          .read(checkInControllerProvider)
          .asData
          ?.value
          .latestCreatedCheckIn
          ?.aiInsight;
      if (insight?.quotaLimited == true) {
        AppSnackBar.show(
          context,
          message: context.l10n.checkInSavedDeepReadingLater,
          icon: Icons.check_circle_outline_rounded,
        );
        widget.onCompleted?.call();
        return _CheckInSubmitResult.success;
      }
      AppSnackBar.show(
        context,
        message: insight == null
            ? context.l10n.checkInSavedReadingPending
            : context.l10n.checkInSavedSnack,
        icon: Icons.check_circle_outline_rounded,
      );
      widget.onCompleted?.call();
      return _CheckInSubmitResult.success;
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showRewardConfirmationProblemMessage() async {
    debugPrint('Evolua: exibindo falha de confirmação do anúncio.');

    if (!mounted) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    // Aguarda a bottom sheet/animações terminarem antes de abrir o diálogo.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!mounted) {
      return;
    }

    final message = context.l10n.checkInRewardAdNotConfirmed;

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.checkInRewardConfirmTitle),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonUnderstood),
          ),
        ],
      ),
    );
  }

  Future<void> _showExtraCheckInUnlockSheet() async {
    if (!mounted) {
      return;
    }
    var rewardedAdAvailable = false;
    try {
      final access = await ref
          .read(monetizationAccessControllerProvider.notifier)
          .access(resource: _extraCheckInRewardResource);
      rewardedAdAvailable = access.rewardedAdAvailable;
    } catch (_) {
      rewardedAdAvailable = false;
    }
    if (!mounted) {
      return;
    }
    var rewardLoading = false;
    var autoSubmitLoading = false;
    RewardedAdResult? rewardFailure;
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final currentRewardFailure = rewardFailure;
          final sheetMessage = currentRewardFailure == null
              ? (rewardedAdAvailable
                    ? l10n.checkInExtraAvailableMessage
                    : l10n.checkInExtraUnavailableMessage)
              : _rewardFailureMessage(currentRewardFailure, l10n);
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: RewardedAdPrompt(
                    title: _rewardPromptTitle(rewardFailure, l10n),
                    message: sheetMessage,
                    rewardLabel: rewardFailure == null && rewardedAdAvailable
                        ? l10n.checkInExtraRewardLabel
                        : '',
                    rewardedAdAvailable: rewardedAdAvailable,
                    isRewardLoading: rewardLoading || autoSubmitLoading,
                    onWatchRewardedAd: rewardedAdAvailable
                        ? () async {
                            if (rewardLoading || autoSubmitLoading) {
                              return;
                            }
                            if (rewardFailure ==
                                RewardedAdResult
                                    .rewardConfirmedButAccessDenied) {
                              setSheetState(() => autoSubmitLoading = true);
                              final saved = await _submit(
                                allowLimitUnlock: false,
                                rewardConfirmed: true,
                              );
                              if (!mounted ||
                                  saved == _CheckInSubmitResult.success) {
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                if (mounted) {
                                  AppSnackBar.show(
                                    context,
                                    message: l10n.checkInSavedWithCare,
                                    icon: Icons.check_circle_outline_rounded,
                                  );
                                }
                                return;
                              }
                              if (sheetContext.mounted) {
                                setSheetState(() {
                                  autoSubmitLoading = false;
                                  rewardFailure = RewardedAdResult
                                      .rewardConfirmedButAccessDenied;
                                });
                              }
                              return;
                            }
                            setSheetState(() {
                              rewardFailure = null;
                              rewardLoading = true;
                            });
                            var rewardResult = RewardedAdResult.loadFailed;
                            try {
                              rewardResult = await ref
                                  .read(
                                    monetizationAccessControllerProvider
                                        .notifier,
                                  )
                                  .unlockWithRewardedAdResult(
                                    resource: _extraCheckInRewardResource,
                                  );
                            } catch (error) {
                              debugPrint(
                                'Evolua rewarded extra check-in failed: '
                                'reason=AD_LOAD_FAILED error=$error',
                              );
                              rewardResult = RewardedAdResult.loadFailed;
                            } finally {
                              if (sheetContext.mounted) {
                                setSheetState(() => rewardLoading = false);
                              }
                            }
                            if (!mounted) {
                              return;
                            }
                            if (!rewardResult.isRewarded) {
                              debugPrint(
                                'Evolua rewarded extra check-in skipped: '
                                'reason=${_rewardFailureDebugReason(rewardResult)}',
                              );
                              if (sheetContext.mounted) {
                                setSheetState(
                                  () => rewardFailure = rewardResult,
                                );
                              }
                              return;
                            }
                            if (sheetContext.mounted) {
                              setSheetState(() => autoSubmitLoading = true);
                            }
                            final saved = await _submit(
                              allowLimitUnlock: false,
                              rewardConfirmed: true,
                            );
                            if (!mounted ||
                                saved == _CheckInSubmitResult.success) {
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                              if (mounted) {
                                AppSnackBar.show(
                                  context,
                                  message: l10n.checkInSavedWithCare,
                                  icon: Icons.check_circle_outline_rounded,
                                );
                              }
                              return;
                            }
                            if (sheetContext.mounted) {
                              setSheetState(() {
                                autoSubmitLoading = false;
                                rewardFailure = RewardedAdResult
                                    .rewardConfirmedButAccessDenied;
                              });
                            }
                            if (saved ==
                                _CheckInSubmitResult
                                    .rewardConfirmedButStillBlocked) {
                              AppSnackBar.show(
                                context,
                                message: l10n.checkInRewardReceivedButBlocked,
                                icon: Icons.info_outline_rounded,
                              );
                            } else if (saved ==
                                _CheckInSubmitResult.limitReached) {
                              await _showRewardConfirmationProblemMessage();
                            }
                          }
                        : null,
                    watchLabel:
                        rewardFailure ==
                            RewardedAdResult.rewardConfirmedButAccessDenied
                        ? l10n.checkInRewardTrySaveAgain
                        : rewardFailure == null
                        ? l10n.checkInRewardWatchAd
                        : l10n.checkInRewardTryAgain,
                    loadingLabel: autoSubmitLoading
                        ? l10n.checkInRewardConfirming
                        : l10n.checkInRewardOpeningAd,
                    onOpenPremium: () {
                      if (rewardLoading || autoSubmitLoading) {
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      widget.onOpenPremium?.call();
                    },
                    premiumLabel: l10n.checkInRewardPremium,
                    onSecondary: () {
                      if (rewardLoading || autoSubmitLoading) {
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                    },
                    secondaryLabel: l10n.checkInNotNow,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _rewardFailureMessage(RewardedAdResult result, AppLocalizations l10n) {
    return switch (result) {
      RewardedAdResult.noFill ||
      RewardedAdResult.loadFailed ||
      RewardedAdResult.showFailed ||
      RewardedAdResult.unsupported => l10n.checkInRewardLoadUnavailableMessage,
      RewardedAdResult.timeout => l10n.checkInRewardConfirmationPendingMessage,
      RewardedAdResult.dismissedWithoutReward =>
        l10n.checkInRewardDismissedMessage,
      RewardedAdResult.rewardConfirmedButAccessDenied =>
        l10n.checkInRewardConfirmationPendingMessage,
      RewardedAdResult.rewarded => l10n.checkInRewardConfirmedMessage,
    };
  }

  String _rewardPromptTitle(RewardedAdResult? result, AppLocalizations l10n) {
    return switch (result) {
      RewardedAdResult.noFill ||
      RewardedAdResult.loadFailed ||
      RewardedAdResult.showFailed ||
      RewardedAdResult.unsupported => l10n.checkInRewardNoAdAvailableTitle,
      RewardedAdResult.timeout => l10n.checkInRewardConfirmationInProgressTitle,
      RewardedAdResult.dismissedWithoutReward =>
        l10n.checkInRewardAdNotCompletedTitle,
      RewardedAdResult.rewardConfirmedButAccessDenied =>
        l10n.checkInRewardConfirmationInProgressTitle,
      RewardedAdResult.rewarded || null => l10n.checkInRewardUnlockTitle,
    };
  }

  String _rewardFailureDebugReason(RewardedAdResult result) {
    return switch (result) {
      RewardedAdResult.noFill => 'NO_FILL',
      RewardedAdResult.loadFailed => 'AD_LOAD_FAILED',
      RewardedAdResult.showFailed => 'AD_SHOW_FAILED',
      RewardedAdResult.rewardConfirmedButAccessDenied =>
        'REWARD_CONFIRMED_BUT_ACCESS_DENIED',
      RewardedAdResult.timeout => 'AD_TIMEOUT',
      RewardedAdResult.unsupported => 'AD_UNSUPPORTED',
      RewardedAdResult.dismissedWithoutReward => 'DISMISSED_WITHOUT_REWARD',
      RewardedAdResult.rewarded => 'REWARDED',
    };
  }

  // Kept for manual deep-reading unlock flows; do not auto-open after save.
  // ignore: unused_element
  Future<void> _showDeepReadingUnlockSheet() async {
    if (!mounted) {
      return;
    }
    var completed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
        ),
        child: RewardedAdPrompt(
          title: context.l10n.checkInDeepReadingTitle,
          message: context.l10n.checkInDeepReadingMessage,
          rewardLabel: context.l10n.checkInDeepReadingReward,
          rewardedAdAvailable: true,
          isRewardLoading: _isRewardLoading,
          onWatchRewardedAd: () async {
            if (_isRewardLoading) {
              return;
            }
            setState(() => _isRewardLoading = true);
            var unlocked = false;
            var readingFailed = false;
            try {
              unlocked = await ref
                  .read(monetizationAccessControllerProvider.notifier)
                  .unlockWithRewardedAd(resource: 'DEEP_EMOTIONAL_READING');
              if (unlocked) {
                await ref
                    .read(checkInControllerProvider.notifier)
                    .generateDeepReadingForLatest();
              }
            } catch (_) {
              readingFailed = unlocked;
            }
            if (!mounted || !sheetContext.mounted) {
              return;
            }
            setState(() => _isRewardLoading = false);
            Navigator.of(sheetContext).pop();
            AppSnackBar.show(
              context,
              message: readingFailed
                  ? context.l10n.errorSmartReadingUnavailable
                  : unlocked
                  ? context.l10n.checkInDeepReadingUnlocked
                  : context.l10n.errorRewardedAdUnavailable,
              icon: unlocked
                  ? Icons.ondemand_video_rounded
                  : Icons.info_outline_rounded,
            );
            completed = true;
            widget.onCompleted?.call();
          },
          onOpenPremium: () {
            Navigator.of(sheetContext).pop();
            completed = true;
            widget.onCompleted?.call();
          },
          premiumLabel: context.l10n.checkInPremiumAction,
        ),
      ),
    );
    if (mounted && !_isRewardLoading && !completed) {
      widget.onCompleted?.call();
    }
  }

  void _openMoodPicker(List<CheckIn> recentItems, CheckInAiInsight? insight) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _MoodPickerSheet(
        recentItems: recentItems,
        suggestedInsight: insight,
        selectedMoodValue: _selectedMoodValue,
        onSelected: (mood) {
          setState(() {
            _selectedMoodValue = mood.value;
            _selectedMoodLabel = mood.label;
            if (mood.value != _otherMoodValue) {
              _otherMoodController.clear();
            }
          });
          Navigator.of(context).pop();
        },
        l10n: l10n,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final quickMoodOptions = _quickMoodOptions(l10n);
    final selectedMoodLabel = _selectedMoodLabel.isEmpty
        ? _labelForMood(_selectedMoodValue, l10n)
        : _selectedMoodLabel;
    final checkInState = ref.watch(checkInControllerProvider);
    final history = checkInState.asData?.value;
    final isCreatingCheckIn = history?.isCreatingCheckIn ?? false;
    final isSavingCheckIn =
        _isSubmitting ||
        isCreatingCheckIn ||
        (checkInState.isLoading && !checkInState.hasValue);
    final recentItems = history?.result.items ?? const <CheckIn>[];
    final latestInsight =
        history?.latestCreatedCheckIn?.aiInsight ??
        recentItems
            .where((item) => item.aiInsight != null)
            .map((item) => item.aiInsight!)
            .firstOrNull;

    return PopScope<void>(
      canPop: !isSavingCheckIn,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !isSavingCheckIn) {
          return;
        }
        _showSavingInProgressMessage();
      },
      child: _CheckInBriefingCard(
        selectedMoodValue: _selectedMoodValue,
        selectedMoodLabel: selectedMoodLabel,
        energyLevel: _energyLevel,
        reflectionController: _reflectionController,
        otherMoodController: _otherMoodController,
        quickMoodOptions: quickMoodOptions,
        isLoading: isSavingCheckIn,
        isListeningReflection: _isListeningReflection,
        onMoodSelected: (mood) => setState(() {
          _selectedMoodValue = mood.value;
          _selectedMoodLabel = mood.label;
          if (mood.value != _otherMoodValue) {
            _otherMoodController.clear();
          }
        }),
        onOpenMoodPicker: () => _openMoodPicker(recentItems, latestInsight),
        onEnergyChanged: (value) => setState(() => _energyLevel = value),
        onToggleReflectionDictation: _toggleReflectionDictation,
        onSubmit: () {
          if (isSavingCheckIn) {
            _showSavingInProgressMessage();
            return;
          }
          _submit();
        },
        onCancel: () {
          if (isSavingCheckIn) {
            _showSavingInProgressMessage();
            return;
          }
          (widget.onCancel ?? () => Navigator.of(context).maybePop())();
        },
        submitLabel: isSavingCheckIn
            ? l10n.checkInSavingLabel
            : l10n.checkInSubmit,
        l10n: l10n,
      ),
    );
  }

  String _speechLocaleId(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode.isEmpty) {
      return 'pt_BR';
    }
    final countryCode = locale.countryCode;
    if (countryCode == null || countryCode.isEmpty) {
      return locale.languageCode == 'pt' ? 'pt_BR' : locale.languageCode;
    }
    return '${locale.languageCode}_$countryCode';
  }

  String get _submissionMood {
    if (_selectedMoodValue != _otherMoodValue) {
      return _selectedMoodValue;
    }

    final customMood = _normalizeMoodValue(_otherMoodController.text);
    return customMood.isEmpty ? _otherMoodValue : customMood;
  }

  String _errorMessage(Object? error) {
    return friendlyApiErrorMessage(
      error,
      context.l10n,
      fallback: context.l10n.checkInSaveError,
    );
  }

  bool _isCheckInLimitError(Object? error) {
    return error is DioException && error.response?.statusCode == 402;
  }

  _CheckInSubmitResult _submitErrorResult(Object? error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 402) {
        return _CheckInSubmitResult.limitReached;
      }
      if (statusCode != null && statusCode >= 500) {
        return _CheckInSubmitResult.serverError;
      }
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => _CheckInSubmitResult.networkError,
        _ => _CheckInSubmitResult.unknownError,
      };
    }

    if (error is TimeoutException) {
      return _CheckInSubmitResult.networkError;
    }

    return _CheckInSubmitResult.unknownError;
  }

  String _submitErrorMessage(
    _CheckInSubmitResult result,
    AppLocalizations l10n, {
    Object? fallbackError,
  }) {
    return switch (result) {
      _CheckInSubmitResult.networkError => l10n.checkInSaveTimeout,
      _CheckInSubmitResult.serverError => _errorMessage(fallbackError),
      _CheckInSubmitResult.rewardConfirmedButStillBlocked =>
        l10n.checkInRewardReceivedButBlocked,
      _CheckInSubmitResult.success || _CheckInSubmitResult.limitReached => '',
      _CheckInSubmitResult.unknownError => _errorMessage(fallbackError),
    };
  }
}

class _CheckInSpeechStartException implements Exception {}

class _CheckInBriefingCard extends StatelessWidget {
  const _CheckInBriefingCard({
    required this.selectedMoodValue,
    required this.selectedMoodLabel,
    required this.energyLevel,
    required this.reflectionController,
    required this.otherMoodController,
    required this.quickMoodOptions,
    required this.isLoading,
    required this.isListeningReflection,
    required this.onMoodSelected,
    required this.onOpenMoodPicker,
    required this.onEnergyChanged,
    required this.onToggleReflectionDictation,
    required this.onSubmit,
    required this.onCancel,
    required this.submitLabel,
    required this.l10n,
  });

  final String selectedMoodValue;
  final String selectedMoodLabel;
  final double energyLevel;
  final TextEditingController reflectionController;
  final TextEditingController otherMoodController;
  final List<_MoodOption> quickMoodOptions;
  final bool isLoading;
  final bool isListeningReflection;
  final ValueChanged<_MoodOption> onMoodSelected;
  final VoidCallback onOpenMoodPicker;
  final ValueChanged<double> onEnergyChanged;
  final VoidCallback onToggleReflectionDictation;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final String submitLabel;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final hasSelectedQuickMood = quickMoodOptions.any(
      (mood) => mood.value == selectedMoodValue,
    );
    final shouldShowSelectedMoodChip =
        selectedMoodValue == _otherMoodValue || !hasSelectedQuickMood;

    return PrimaryPanel(
      semanticLabel: l10n.checkInSemanticLabel,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            eyebrow: l10n.checkInEyebrow,
            title: l10n.checkInPromptTitle,
            subtitle: l10n.checkInPromptSubtitle,
            accentColor: AppColors.accent,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...quickMoodOptions.map(
                (mood) => ChoiceChip(
                  label: Text(mood.label),
                  selected: selectedMoodValue == mood.value,
                  onSelected: isLoading ? null : (_) => onMoodSelected(mood),
                ),
              ),
              if (shouldShowSelectedMoodChip)
                ChoiceChip(
                  label: Text(selectedMoodLabel),
                  selected: true,
                  onSelected: isLoading ? null : (_) {},
                ),
              ActionChip(
                tooltip: l10n.checkInMoreStatesTooltip,
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.checkInMoreStates),
                onPressed: isLoading ? null : onOpenMoodPicker,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.checkInSelectedState(selectedMoodLabel),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (selectedMoodValue == _otherMoodValue) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: otherMoodController,
              enabled: !isLoading,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: l10n.checkInOtherMoodLabel,
                hintText: l10n.checkInOtherMoodHint,
                prefixIcon: const Icon(Icons.edit_rounded),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            l10n.checkInEnergyLabel(energyLevel.round()),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
          ),
          Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: energyLevel,
            onChanged: isLoading ? null : onEnergyChanged,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: reflectionController,
            enabled: !isLoading,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.checkInReflectionLabel,
              hintText: l10n.checkInReflectionHint,
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.edit_note_rounded),
              suffixIcon: IconButton(
                tooltip: isListeningReflection
                    ? l10n.checkInStopDictationTooltip
                    : l10n.checkInUseMicrophoneTooltip,
                onPressed: isLoading ? null : onToggleReflectionDictation,
                icon: Icon(
                  isListeningReflection
                      ? Icons.stop_rounded
                      : Icons.mic_none_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite_rounded),
                label: Text(submitLabel),
              ),
              OutlinedButton.icon(
                onPressed: isLoading ? null : onCancel,
                icon: const Icon(Icons.close_rounded),
                label: Text(l10n.checkInNotNow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodPickerSheet extends StatefulWidget {
  const _MoodPickerSheet({
    required this.recentItems,
    required this.suggestedInsight,
    required this.selectedMoodValue,
    required this.onSelected,
    required this.l10n,
  });

  final List<CheckIn> recentItems;
  final CheckInAiInsight? suggestedInsight;
  final String selectedMoodValue;
  final ValueChanged<_MoodOption> onSelected;
  final AppLocalizations l10n;

  @override
  State<_MoodPickerSheet> createState() => _MoodPickerSheetState();
}

class _MoodPickerSheetState extends State<_MoodPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentMoods = widget.recentItems
        .map((item) => _optionForMood(item.mood, widget.l10n))
        .whereType<_MoodOption>()
        .fold<Map<String, _MoodOption>>({}, (items, mood) {
          items[mood.value] = mood;
          return items;
        })
        .values
        .take(4)
        .toList();
    final suggestedMoods = _suggestedMoods(widget.suggestedInsight);
    final groups = _moodGroups(widget.l10n);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 14,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const _BottomSheetHandle(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: widget.l10n.commonBack,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.l10n.checkInChooseStateTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: widget.l10n.checkInSearchState,
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                if (recentMoods.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _MoodGroup(
                    title: widget.l10n.checkInRecentStates,
                    moods: _filterMoods(recentMoods),
                    selectedMoodValue: widget.selectedMoodValue,
                    onSelected: widget.onSelected,
                  ),
                ],
                if (suggestedMoods.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _MoodGroup(
                    title: widget.l10n.checkInAiSuggestedStates,
                    moods: _filterMoods(suggestedMoods),
                    selectedMoodValue: widget.selectedMoodValue,
                    onSelected: widget.onSelected,
                  ),
                ],
                ...groups.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _MoodGroup(
                      title: entry.key,
                      moods: _filterMoods(entry.value),
                      selectedMoodValue: widget.selectedMoodValue,
                      onSelected: widget.onSelected,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_MoodOption> _filterMoods(List<_MoodOption> moods) {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return moods;
    }

    return moods
        .where((mood) => mood.label.toLowerCase().contains(normalizedQuery))
        .toList();
  }

  List<_MoodOption> _suggestedMoods(CheckInAiInsight? insight) {
    final source = [
      insight?.insight ?? '',
      insight?.suggestedAction ?? '',
      insight?.suggestedTrailReason ?? '',
    ].join(' ').toLowerCase();

    final matches = <String, _MoodOption>{};
    for (final moods in _moodGroups(widget.l10n).values) {
      for (final mood in moods) {
        if (source.contains(mood.label.toLowerCase()) ||
            source.contains(mood.value.toLowerCase())) {
          matches[mood.value] = mood;
        }
      }
    }

    return matches.values.take(4).toList();
  }
}

class _MoodGroup extends StatelessWidget {
  const _MoodGroup({
    required this.title,
    required this.moods,
    required this.selectedMoodValue,
    required this.onSelected,
  });

  final String title;
  final List<_MoodOption> moods;
  final String selectedMoodValue;
  final ValueChanged<_MoodOption> onSelected;

  @override
  Widget build(BuildContext context) {
    if (moods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: moods.map((mood) {
            final selected = selectedMoodValue == mood.value;
            return ChoiceChip(
              label: Text(mood.label),
              selected: selected,
              showCheckmark: selected,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              labelPadding: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              onSelected: (_) => onSelected(mood),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final safeEyebrow = eyebrow.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (safeEyebrow.isNotEmpty) ...[
          Text(
            safeEyebrow,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _BottomSheetHandle extends StatelessWidget {
  const _BottomSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.outline.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

const _defaultMoodValue = 'calma';
const _otherMoodValue = 'outro';

class _MoodOption {
  const _MoodOption(this.value, this.label);

  final String value;
  final String label;
}

List<_MoodOption> _quickMoodOptions(AppLocalizations l10n) => [
  _MoodOption('calma', l10n.checkInMoodCalm),
  _MoodOption('ansiedade', l10n.checkInMoodAnxiety),
  _MoodOption('cansaco', l10n.checkInMoodTiredness),
  _MoodOption('distracao', l10n.checkInMoodDistraction),
];

Map<String, List<_MoodOption>> _moodGroups(AppLocalizations l10n) => {
  l10n.checkInMoodGroupEmotional: [
    _MoodOption('calma', l10n.checkInMoodCalm),
    _MoodOption('ansiedade', l10n.checkInMoodAnxiety),
    _MoodOption('tristeza', l10n.checkInMoodSadness),
    _MoodOption('animo', l10n.checkInMoodEnthusiasm),
    _MoodOption('irritacao', l10n.checkInMoodIrritation),
    _MoodOption('esperanca', l10n.checkInMoodHope),
    _MoodOption('sobrecarga', l10n.checkInMoodOverload),
  ],
  l10n.checkInMoodGroupMental: [
    _MoodOption('distracao', l10n.checkInMoodDistraction),
    _MoodOption('foco', l10n.checkInMoodFocus),
    _MoodOption('confusao', l10n.checkInMoodConfusion),
    _MoodOption('criatividade', l10n.checkInMoodCreativity),
    _MoodOption('aceleracao', l10n.checkInMoodAcceleration),
    _MoodOption('bloqueio', l10n.checkInMoodBlock),
  ],
  l10n.checkInMoodGroupPhysical: [
    _MoodOption('cansaco', l10n.checkInMoodTiredness),
    _MoodOption('energia', l10n.checkInMoodEnergy),
    _MoodOption('tensao', l10n.checkInMoodTension),
    _MoodOption('leveza', l10n.checkInMoodLightness),
    _MoodOption('sonolencia', l10n.checkInMoodSleepiness),
    _MoodOption('agitacao', l10n.checkInMoodAgitation),
  ],
  l10n.checkInMoodGroupBehavioral: [
    _MoodOption('evitacao', l10n.checkInMoodAvoidance),
    _MoodOption('produtividade', l10n.checkInMoodProductivity),
    _MoodOption('isolamento', l10n.checkInMoodIsolation),
    _MoodOption('conexao', l10n.checkInMoodConnection),
    _MoodOption('procrastinacao', l10n.checkInMoodProcrastination),
    _MoodOption('constancia', l10n.checkInMoodConsistency),
  ],
  l10n.checkInMoodGroupOther: [
    _MoodOption(_otherMoodValue, l10n.checkInMoodOther),
  ],
};

String _labelForMood(String value, AppLocalizations l10n) =>
    _optionForMood(value, l10n)?.label ?? value;

_MoodOption? _optionForMood(String value, AppLocalizations l10n) {
  final normalizedValue = _normalizeMoodValue(value);
  if (normalizedValue.isEmpty) {
    return null;
  }

  final legacyValue = _legacyMoodValues[normalizedValue] ?? normalizedValue;
  for (final option in _moodGroups(l10n).values.expand((items) => items)) {
    if (option.value == legacyValue) {
      return option;
    }
  }

  final label = value.trim();
  return _MoodOption(
    normalizedValue,
    label[0].toUpperCase() + label.substring(1),
  );
}

String _normalizeMoodValue(String value) {
  return value.trim().toLowerCase();
}

const _legacyMoodValues = {
  'calmo': 'calma',
  'ansioso': 'ansiedade',
  'cansado': 'cansaco',
  'distraido': 'distracao',
  'distraído': 'distracao',
  'triste': 'tristeza',
  'animado': 'animo',
  'irritado': 'irritacao',
  'esperancoso': 'esperanca',
  'sobrecarregado': 'sobrecarga',
  'focado': 'foco',
  'confuso': 'confusao',
  'criativo': 'criatividade',
  'acelerado': 'aceleracao',
  'travado': 'bloqueio',
  'energizado': 'energia',
  'tenso': 'tensao',
  'leve': 'leveza',
  'sonolento': 'sonolencia',
  'agitado': 'agitacao',
  'evitando': 'evitacao',
  'produtivo': 'produtividade',
  'isolado': 'isolamento',
  'conectado': 'conexao',
  'procrastinando': 'procrastinacao',
  'constante': 'constancia',
};
