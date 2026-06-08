import 'dart:async';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/network/api_error_message.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service_base.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/evolua_async_button.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DailyRitualPage extends StatelessWidget {
  const DailyRitualPage({super.key, required this.type});

  final String type;

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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: DailyRitualView(type: type),
            ),
          ),
        ),
      ),
    );
  }
}

class DailyRitualView extends ConsumerStatefulWidget {
  const DailyRitualView({super.key, required this.type});

  final String type;

  @override
  ConsumerState<DailyRitualView> createState() => _DailyRitualViewState();
}

class _DailyRitualViewState extends ConsumerState<DailyRitualView> {
  final _answers = List.generate(4, (_) => TextEditingController());
  int _step = -1;
  bool _isSubmitting = false;

  bool get _isEvening => widget.type == DailyRitualType.evening;

  @override
  void dispose() {
    for (final controller in _answers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_answers.any((controller) => controller.text.trim().isEmpty)) {
      AppSnackBar.show(
        context,
        message: l10n.dailyRitualAnswerAllSteps,
        icon: Icons.edit_note_rounded,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(dailyRitualControllerProvider.notifier)
          .create(
            DailyRitualDraft(
              localDate: DateTime.now(),
              type: widget.type,
              emotionalState: _answers[0].text.trim(),
              dayNeed: _answers[1].text.trim(),
              intention: _answers[2].text.trim(),
              microAction: _answers[3].text.trim(),
            ),
          );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: _isEvening
            ? l10n.dailyRitualSavedEvening
            : l10n.dailyRitualSavedMorning,
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: _friendlyError(error, l10n),
        icon: Icons.info_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyRitualControllerProvider);
    final l10n = context.l10n;
    final copy = _DailyRitualCopy.forType(widget.type, l10n);

    return state.when(
      data: (data) {
        final existing = data.byType(widget.type);
        if (existing != null) {
          return _DailyRitualResult(copy: copy, ritual: existing);
        }
        if (_step < 0) {
          return _DailyRitualIntro(
            copy: copy,
            l10n: l10n,
            onStart: () => setState(() => _step = 0),
            onSkip: () => context.go('/home'),
          );
        }
        return _DailyRitualFlow(
          copy: copy,
          l10n: l10n,
          step: _step,
          controller: _answers[_step],
          isSubmitting: _isSubmitting,
          onBack: _step == 0 ? null : () => setState(() => _step--),
          onNext: _step == 3 ? _submit : () => setState(() => _step++),
        );
      },
      loading: () => const PrimaryPanel(child: LinearProgressIndicator()),
      error: (error, stackTrace) => PrimaryPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dailyRitualOpenError),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(dailyRitualControllerProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.commonRefresh),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyError(Object error, AppLocalizations l10n) {
    if (error is DioException) {
      return extractApiErrorMessage(error, fallback: l10n.dailyRitualSaveError);
    }
    return l10n.dailyRitualSaveError;
  }
}

class _DailyRitualIntro extends StatelessWidget {
  const _DailyRitualIntro({
    required this.copy,
    required this.l10n,
    required this.onStart,
    required this.onSkip,
  });

  final _DailyRitualCopy copy;
  final AppLocalizations l10n;
  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: copy.title,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(copy.description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.timer_rounded,
                label: l10n.dailyRitualDurationChip,
              ),
              _InfoChip(
                icon: Icons.favorite_rounded,
                label: l10n.dailyRitualNoRightWrongChip,
              ),
              _InfoChip(
                icon: Icons.spa_rounded,
                label: l10n.dailyRitualAtYourPaceChip,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.dailyRitualStartNow),
              ),
              TextButton(onPressed: onSkip, child: Text(l10n.checkInNotNow)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyRitualFlow extends StatelessWidget {
  const _DailyRitualFlow({
    required this.copy,
    required this.l10n,
    required this.step,
    required this.controller,
    required this.isSubmitting,
    required this.onBack,
    required this.onNext,
  });

  final _DailyRitualCopy copy;
  final AppLocalizations l10n;
  final int step;
  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback? onBack;
  final FutureOr<void> Function()? onNext;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${step + 1}/4',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            copy.questions[step],
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l10n.dailyRitualAnswerLabel,
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (onBack != null)
                OutlinedButton.icon(
                  onPressed: isSubmitting ? null : onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(l10n.commonBack),
                ),
              const Spacer(),
              EvoluaAsyncButton.filled(
                onPressed: isSubmitting ? null : onNext,
                isBusy: isSubmitting,
                icon: step == 3
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                label: step == 3
                    ? l10n.dailyRitualFinish
                    : l10n.dailyRitualContinue,
                loadingLabel: l10n.commonSaving,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyRitualResult extends ConsumerWidget {
  const _DailyRitualResult({required this.copy, required this.ritual});

  final _DailyRitualCopy copy;
  final DailyRitual ritual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PrimaryPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.resultTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _RitualIntentionHighlight(
            title: copy.resultCarryTitle,
            intention: ritual.intention,
          ),
          const SizedBox(height: 16),
          _ResultRow(
            label: l10n.dailyRitualEmotionalState,
            value: ritual.emotionalState,
          ),
          _ResultRow(label: l10n.dailyRitualDayNeed, value: ritual.dayNeed),
          _ResultRow(
            label: l10n.dailyRitualChosenIntention,
            value: ritual.intention,
          ),
          _ResultRow(
            label: l10n.dailyRitualChosenMicroAction,
            value: ritual.microAction,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              await ref
                  .read(interstitialAdServiceProvider)
                  .maybeShow(
                    trigger: InterstitialTrigger.ritualCompletedExit,
                    session: ref.read(authControllerProvider).asData?.value,
                  );
              if (context.mounted) {
                context.go('/home');
              }
            },
            icon: const Icon(Icons.home_rounded),
            label: Text(l10n.dailyRitualBackHome),
          ),
        ],
      ),
    );
  }
}

class _RitualIntentionHighlight extends StatelessWidget {
  const _RitualIntentionHighlight({
    required this.title,
    required this.intention,
  });

  final String title;
  final String intention;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.accent.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            intention,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: AppColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _DailyRitualCopy {
  const _DailyRitualCopy({
    required this.title,
    required this.description,
    required this.resultTitle,
    required this.resultCarryTitle,
    required this.questions,
  });

  final String title;
  final String description;
  final String resultTitle;
  final String resultCarryTitle;
  final List<String> questions;

  static _DailyRitualCopy forType(String type, AppLocalizations l10n) {
    if (type == DailyRitualType.evening) {
      return _DailyRitualCopy(
        title: l10n.dailyRitualEveningTitle,
        description: l10n.dailyRitualEveningDescription,
        resultTitle: l10n.dailyRitualEveningResultTitle,
        resultCarryTitle: l10n.dailyRitualCarryEvening,
        questions: [
          l10n.dailyRitualEveningQuestionState,
          l10n.dailyRitualEveningQuestionNeed,
          l10n.dailyRitualEveningQuestionIntention,
          l10n.dailyRitualEveningQuestionAction,
        ],
      );
    }
    return _DailyRitualCopy(
      title: l10n.dailyRitualMorningTitle,
      description: l10n.dailyRitualMorningDescription,
      resultTitle: l10n.dailyRitualMorningResultTitle,
      resultCarryTitle: l10n.dailyRitualCarryMorning,
      questions: [
        l10n.dailyRitualMorningQuestionState,
        l10n.dailyRitualMorningQuestionNeed,
        l10n.dailyRitualMorningQuestionIntention,
        l10n.dailyRitualMorningQuestionAction,
      ],
    );
  }
}
