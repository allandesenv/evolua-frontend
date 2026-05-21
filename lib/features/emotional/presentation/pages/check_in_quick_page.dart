import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/ads/application/monetization_access_controller.dart';
import 'package:evolua_frontend/features/ads/presentation/widgets/monetization_prompt.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CheckInQuickView extends ConsumerStatefulWidget {
  const CheckInQuickView({super.key, this.onCompleted, this.onCancel});

  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;

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

  @override
  void initState() {
    super.initState();
    ref.listenManual(checkInControllerProvider, (previous, next) {
      if (!next.hasError || !mounted) {
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
    _reflectionController.dispose();
    _otherMoodController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(checkInControllerProvider.notifier)
          .create(
            mood: _submissionMood,
            reflection: _reflectionController.text.trim().isEmpty
                ? null
                : _reflectionController.text.trim(),
            energyLevel: _energyLevel.round(),
          );

      if (!mounted) {
        return;
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
        await _showDeepReadingUnlockSheet();
        return;
      }
      AppSnackBar.show(
        context,
        message: context.l10n.checkInSavedSnack,
        icon: Icons.check_circle_outline_rounded,
      );
      widget.onCompleted?.call();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

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
            final unlocked = await ref
                .read(monetizationAccessControllerProvider.notifier)
                .unlockWithRewardedAd(resource: 'DEEP_EMOTIONAL_READING');
            if (unlocked) {
              await ref
                  .read(checkInControllerProvider.notifier)
                  .generateDeepReadingForLatest();
            }
            if (!mounted || !sheetContext.mounted) {
              return;
            }
            setState(() => _isRewardLoading = false);
            Navigator.of(sheetContext).pop();
            AppSnackBar.show(
              context,
              message: unlocked
                  ? context.l10n.checkInDeepReadingUnlocked
                  : context.l10n.checkInRewardAdNotConfirmed,
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
    final recentItems = history?.result.items ?? const <CheckIn>[];
    final latestInsight =
        history?.latestCreatedCheckIn?.aiInsight ??
        recentItems
            .where((item) => item.aiInsight != null)
            .map((item) => item.aiInsight!)
            .firstOrNull;

    return _CheckInBriefingCard(
      selectedMoodValue: _selectedMoodValue,
      selectedMoodLabel: selectedMoodLabel,
      energyLevel: _energyLevel,
      reflectionController: _reflectionController,
      otherMoodController: _otherMoodController,
      quickMoodOptions: quickMoodOptions,
      isLoading:
          _isSubmitting || (checkInState.isLoading && !checkInState.hasValue),
      onMoodSelected: (mood) => setState(() {
        _selectedMoodValue = mood.value;
        _selectedMoodLabel = mood.label;
        if (mood.value != _otherMoodValue) {
          _otherMoodController.clear();
        }
      }),
      onOpenMoodPicker: () => _openMoodPicker(recentItems, latestInsight),
      onEnergyChanged: (value) => setState(() => _energyLevel = value),
      onSubmit: _submit,
      onCancel: widget.onCancel ?? () => Navigator.of(context).maybePop(),
      l10n: l10n,
    );
  }

  String get _submissionMood {
    if (_selectedMoodValue != _otherMoodValue) {
      return _selectedMoodValue;
    }

    final customMood = _normalizeMoodValue(_otherMoodController.text);
    return customMood.isEmpty ? _otherMoodValue : customMood;
  }

  String _errorMessage(Object? error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final details = data['details'];
        if (details is List && details.isNotEmpty) {
          return details.join(', ');
        }
      }
      return error.message ?? context.l10n.checkInSaveError;
    }

    return context.l10n.checkInSaveError;
  }
}

class _CheckInBriefingCard extends StatelessWidget {
  const _CheckInBriefingCard({
    required this.selectedMoodValue,
    required this.selectedMoodLabel,
    required this.energyLevel,
    required this.reflectionController,
    required this.otherMoodController,
    required this.quickMoodOptions,
    required this.isLoading,
    required this.onMoodSelected,
    required this.onOpenMoodPicker,
    required this.onEnergyChanged,
    required this.onSubmit,
    required this.onCancel,
    required this.l10n,
  });

  final String selectedMoodValue;
  final String selectedMoodLabel;
  final double energyLevel;
  final TextEditingController reflectionController;
  final TextEditingController otherMoodController;
  final List<_MoodOption> quickMoodOptions;
  final bool isLoading;
  final ValueChanged<_MoodOption> onMoodSelected;
  final VoidCallback onOpenMoodPicker;
  final ValueChanged<double> onEnergyChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
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
                  onSelected: (_) => onMoodSelected(mood),
                ),
              ),
              if (shouldShowSelectedMoodChip)
                ChoiceChip(
                  label: Text(selectedMoodLabel),
                  selected: true,
                  onSelected: (_) {},
                ),
              ActionChip(
                tooltip: l10n.checkInMoreStatesTooltip,
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.checkInMoreStates),
                onPressed: onOpenMoodPicker,
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
            onChanged: onEnergyChanged,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: reflectionController,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.checkInReflectionLabel,
              hintText: l10n.checkInReflectionHint,
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.edit_note_rounded),
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
                label: Text(l10n.checkInSubmit),
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
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                Row(
                  children: [
                    IconButton(
                      tooltip: widget.l10n.commonBack,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      iconSize: 18,
                    ),
                    const Spacer(),
                    const _BottomSheetHandle(),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                Text(
                  widget.l10n.checkInChooseStateTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: widget.l10n.checkInSearchState,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                if (recentMoods.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _MoodGroup(
                    title: widget.l10n.checkInRecentStates,
                    moods: _filterMoods(recentMoods),
                    selectedMoodValue: widget.selectedMoodValue,
                    onSelected: widget.onSelected,
                  ),
                ],
                if (suggestedMoods.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _MoodGroup(
                    title: widget.l10n.checkInAiSuggestedStates,
                    moods: _filterMoods(suggestedMoods),
                    selectedMoodValue: widget.selectedMoodValue,
                    onSelected: widget.onSelected,
                  ),
                ],
                ...groups.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(top: 18),
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: moods
              .map(
                (mood) => ChoiceChip(
                  label: Text(mood.label),
                  selected: selectedMoodValue == mood.value,
                  onSelected: (_) => onSelected(mood),
                ),
              )
              .toList(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
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
        margin: const EdgeInsets.only(bottom: 18),
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
