import 'dart:async';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/app/startup/app_startup_controller.dart';
import 'package:evolua_frontend/app/startup/startup_diagnostics.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/ads/application/interstitial_ad_service.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/care/application/care_prescription_handler.dart';
import 'package:evolua_frontend/features/care/application/care_recommendation_handler.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/content_module_view.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/mentor_evolua_module_view.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_day.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/presentation/pages/check_in_quick_page.dart';
import 'package:evolua_frontend/features/home/presentation/widgets/home_hub_view.dart';
import 'package:evolua_frontend/features/home/presentation/widgets/safe_check_in_launcher.dart';
import 'package:evolua_frontend/features/notification/presentation/widgets/notification_module_view.dart';
import 'package:evolua_frontend/features/notification/application/local_check_in_reminder_controller.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_module_view.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/home/presentation/widgets/admin_panel_view.dart';
import 'package:evolua_frontend/features/user/application/accessibility_preferences_controller.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/presentation/widgets/profile_module_view.dart';
import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:evolua_frontend/shared/presentation/widgets/evolua_logo.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key, this.initialProfileSection});

  final ProfileModuleSection? initialProfileSection;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _selectedIndex = 0;
  ContentModuleSection _trailSection = ContentModuleSection.journey;
  int? _suggestedTrailIdToOpen;
  SocialModuleTab _spaceSection = SocialModuleTab.featured;
  final SocialFeedScope _reflectionScope = SocialFeedScope.moment;
  ProfileModuleSection _profileSection = ProfileModuleSection.overview;
  AdminPanelSection _adminSection = AdminPanelSection.overview;
  final List<_DashboardLocation> _history = [];
  bool _handledBillingReturn = false;
  bool _checkInOpening = false;
  bool _initialCheckInPromptOpening = false;
  String? _initialCheckInPromptKey;
  bool _firstExperienceOpening = false;
  String? _firstExperienceKey;
  bool _openingReminderCheckIn = false;
  ProviderSubscription<AsyncValue<String>>? _reminderTapSubscription;
  ProviderSubscription<int>? _carePrescriptionSubscription;
  ProviderSubscription<int>? _careRecommendationSubscription;
  String? _startupWarmupUserId;
  String? _interstitialPreloadUserId;
  VoidCallback? _spacesInternalBackAction;
  bool _resendingEmailVerification = false;
  bool _refreshingEmailVerification = false;
  final SafeCheckInLauncher _safeCheckInLauncher = SafeCheckInLauncher();

  static const _spacesIndex = 2;
  static const _mirrorIndex = 3;
  static const _profileIndex = 4;
  static const _mentorIndex = 5;
  static const _adminIndex = 6;

  @override
  void initState() {
    super.initState();
    final initialProfileSection = widget.initialProfileSection;
    if (initialProfileSection != null) {
      _profileSection = initialProfileSection;
      _selectedIndex =
          initialProfileSection == ProfileModuleSection.evolutionMirror
          ? _mirrorIndex
          : _profileIndex;
    }
    _reminderTapSubscription = ref.listenManual(
      dailyCheckInReminderTapProvider,
      (previous, next) {
        if (next.asData?.value != dailyCheckInReminderPayload) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          unawaited(_openHomeFromReminderNotification());
        });
      },
    );
    _carePrescriptionSubscription = ref.listenManual<int>(
      carePrescriptionAppliedEventProvider,
      (previous, next) {
        if ((previous ?? 0) >= next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Novo ritual recebido do seu terapeuta.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      },
    );
    _careRecommendationSubscription = ref.listenManual<int>(
      careRecommendationReceivedEventProvider,
      (previous, next) {
        if ((previous ?? 0) >= next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nova orientação do seu terapeuta.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _reminderTapSubscription?.close();
    _carePrescriptionSubscription?.close();
    _careRecommendationSubscription?.close();
    super.dispose();
  }

  _DashboardLocation _currentLocation() {
    return _DashboardLocation(
      selectedIndex: _selectedIndex,
      trailSection: _trailSection,
      spaceSection: _spaceSection,
      profileSection: _profileSection,
      adminSection: _adminSection,
    );
  }

  void _pushCurrentLocation() {
    final location = _currentLocation();
    if (_history.isEmpty || _history.last != location) {
      _history.add(location);
    }
  }

  void _restoreLocation(_DashboardLocation location) {
    _selectedIndex = location.selectedIndex;
    _trailSection = location.trailSection;
    _spaceSection = location.spaceSection;
    _profileSection = location.profileSection;
    _adminSection = location.adminSection;
  }

  ContentModuleSection _trailSectionForNavigation() {
    final currentJourney = ref.read(currentJourneyTrailProvider);
    if (currentJourney.hasValue && currentJourney.asData?.value == null) {
      return ContentModuleSection.catalog;
    }
    return _trailSection;
  }

  void _goTo(int index, {bool recordHistory = true}) {
    if (_selectedIndex == index) {
      if (index == 1) {
        final targetTrailSection = _trailSectionForNavigation();
        if (_trailSection != targetTrailSection) {
          setState(() => _trailSection = targetTrailSection);
        }
      }
      return;
    }

    setState(() {
      if (index == 0) {
        _history.clear();
      } else if (recordHistory) {
        _pushCurrentLocation();
      }
      _selectedIndex = index;
      if (index == 1) {
        _trailSection = _trailSectionForNavigation();
      }
      if (index == _mirrorIndex) {
        _profileSection = ProfileModuleSection.evolutionMirror;
      }
    });
  }

  Future<void> _openCheckIn({required bool compact}) async {
    if (_checkInOpening) {
      return;
    }
    _checkInOpening = true;
    try {
      if (!compact) {
        await context.push('/check-in');
        return;
      }
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: CheckInQuickView(
                onCompleted: () {
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                onCancel: () {
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                onOpenPremium: () {
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  _openProfileSection(ProfileModuleSection.plansSubscriptions);
                },
              ),
            ),
          ),
        ),
      );
    } finally {
      _checkInOpening = false;
    }
  }

  Future<void> _openCheckInSafely({required bool compact}) {
    return _safeCheckInLauncher.open(
      context: context,
      ref: ref,
      isMounted: () => mounted,
      openCheckIn: () => _openCheckIn(compact: compact),
      onOpenPremium: () =>
          _openProfileSection(ProfileModuleSection.plansSubscriptions),
    );
  }

  Future<void> _resendEmailVerification() async {
    if (_resendingEmailVerification) {
      return;
    }
    setState(() => _resendingEmailVerification = true);
    try {
      await ref.read(authControllerProvider.notifier).resendEmailVerification();
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: 'Enviamos um novo e-mail de confirmacao.',
        icon: Icons.mark_email_read_rounded,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: _friendlyEmailVerificationError(error),
        icon: Icons.info_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _resendingEmailVerification = false);
      }
    }
  }

  String _friendlyEmailVerificationError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        final message = (data['message'] as String).trim();
        if (message.isNotEmpty) {
          return message;
        }
      }
    }
    return 'Nao conseguimos reenviar agora. Tente novamente em instantes.';
  }

  Future<void> _refreshEmailVerificationStatus() async {
    if (_refreshingEmailVerification) {
      return;
    }
    setState(() => _refreshingEmailVerification = true);
    try {
      final refreshed = await ref
          .read(authControllerProvider.notifier)
          .refreshSession();
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: refreshed?.emailVerified == true
            ? 'E-mail confirmado. Obrigado!'
            : 'Ainda nao identificamos a confirmacao. Confira seu e-mail e tente novamente.',
        icon: refreshed?.emailVerified == true
            ? Icons.verified_rounded
            : Icons.info_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _refreshingEmailVerification = false);
      }
    }
  }

  void _setTrailSection(ContentModuleSection section) {
    if (_selectedIndex == 1 && _trailSection == section) {
      return;
    }

    setState(() {
      _pushCurrentLocation();
      _selectedIndex = 1;
      _trailSection = section;
      if (section != ContentModuleSection.catalog) {
        _suggestedTrailIdToOpen = null;
      }
    });
  }

  void _openSuggestedTrail(int trailId) {
    setState(() {
      _pushCurrentLocation();
      _selectedIndex = 1;
      _trailSection = ContentModuleSection.catalog;
      _suggestedTrailIdToOpen = trailId;
    });
  }

  void _consumeSuggestedTrailOpen() {
    if (_suggestedTrailIdToOpen == null) {
      return;
    }

    setState(() => _suggestedTrailIdToOpen = null);
  }

  void _openSpacesSection(SocialModuleTab section) {
    if (_selectedIndex == _spacesIndex && _spaceSection == section) {
      return;
    }

    setState(() {
      _pushCurrentLocation();
      _selectedIndex = _spacesIndex;
      _spaceSection = section;
    });
  }

  void _openProfileSection(ProfileModuleSection section) {
    final targetIndex = section == ProfileModuleSection.evolutionMirror
        ? _mirrorIndex
        : _profileIndex;
    if (_selectedIndex == targetIndex && _profileSection == section) {
      return;
    }

    setState(() {
      _pushCurrentLocation();
      _selectedIndex = targetIndex;
      _profileSection = section;
    });
  }

  void _openAdminSection(AdminPanelSection section) {
    if (_selectedIndex == _adminIndex && _adminSection == section) {
      return;
    }

    setState(() {
      _pushCurrentLocation();
      _selectedIndex = _adminIndex;
      _adminSection = section;
    });
  }

  void _handleMobileBack() {
    final spacesInternalBackAction = _spacesInternalBackAction;
    if (_selectedIndex == _spacesIndex && spacesInternalBackAction != null) {
      spacesInternalBackAction();
      return;
    }

    setState(() {
      if (_history.isNotEmpty) {
        _restoreLocation(_history.removeLast());
        return;
      }
      if (_selectedIndex != 0) {
        _selectedIndex = 0;
      }
    });
  }

  void _scheduleInitialCheckInPrompt({
    required bool isCompact,
    required AuthSession? session,
    required AsyncValue<CheckInHistoryState> checkInState,
  }) {
    if (!isCompact ||
        session == null ||
        _checkInOpening ||
        _openingReminderCheckIn ||
        _initialCheckInPromptOpening) {
      return;
    }

    final history = checkInState.asData?.value;
    if (history == null ||
        !history.belongsToUser(session.userId) ||
        hasCheckInToday(
          history.result.items,
          latestCreatedCheckIn: history.latestCreatedCheckIn,
        )) {
      return;
    }

    final hasAnyCheckIn =
        history.latestCreatedCheckIn != null || history.result.items.isNotEmpty;
    if (!hasAnyCheckIn) {
      final firstExperienceKey = _firstExperienceStorageKey(session.userId);
      if (_firstExperienceKey == firstExperienceKey) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFirstExperienceIfNeeded(
          firstExperienceKey: firstExperienceKey,
          initialPromptKey: _initialCheckInPromptStorageKey(session.userId),
        );
      });
      return;
    }

    final key = _initialCheckInPromptStorageKey(session.userId);
    if (_initialCheckInPromptKey == key) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInitialCheckInPromptIfNeeded(key);
    });
  }

  void _consumePendingReminderCheckInIfNeeded({required AuthSession? session}) {
    if (session == null || _openingReminderCheckIn || _checkInOpening) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _openingReminderCheckIn || _checkInOpening) {
        return;
      }
      _openingReminderCheckIn = true;
      try {
        final shouldOpen = await ref
            .read(dailyCheckInReminderControllerProvider.notifier)
            .consumePendingCheckInPayload();
        if (!mounted || !shouldOpen) {
          return;
        }
        await _markInitialCheckInPromptHandled(session.userId);
        _showHomeFromReminderNotification();
      } finally {
        _openingReminderCheckIn = false;
      }
    });
  }

  Future<void> _openHomeFromReminderNotification() async {
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null || _openingReminderCheckIn || _checkInOpening) {
      return;
    }
    _openingReminderCheckIn = true;
    try {
      await _markInitialCheckInPromptHandled(session.userId);
      _showHomeFromReminderNotification();
    } finally {
      _openingReminderCheckIn = false;
    }
  }

  void _showHomeFromReminderNotification() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIndex = 0;
      _history.clear();
      _suggestedTrailIdToOpen = null;
    });
    GoRouter.maybeOf(context)?.go('/home');
  }

  Future<void> _markInitialCheckInPromptHandled(String userId) async {
    await _markInitialCheckInPromptKeyHandled(
      _initialCheckInPromptStorageKey(userId),
    );
  }

  Future<void> _markInitialCheckInPromptKeyHandled(String key) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setBool(key, true);
    _initialCheckInPromptKey = key;
  }

  Future<void> _markFirstExperienceHandled(String key) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setBool(key, true);
    _firstExperienceKey = key;
  }

  Future<void> _openFirstExperienceIfNeeded({
    required String firstExperienceKey,
    required String initialPromptKey,
  }) async {
    if (!mounted ||
        _firstExperienceOpening ||
        _openingReminderCheckIn ||
        _checkInOpening) {
      return;
    }

    _firstExperienceOpening = true;
    try {
      _openingReminderCheckIn = true;
      late final bool shouldOpenReminder;
      try {
        shouldOpenReminder = await ref
            .read(dailyCheckInReminderControllerProvider.notifier)
            .consumePendingCheckInPayload();
      } finally {
        _openingReminderCheckIn = false;
      }
      if (!mounted) {
        return;
      }
      if (shouldOpenReminder) {
        _openingReminderCheckIn = true;
        try {
          await _markFirstExperienceHandled(firstExperienceKey);
          await _markInitialCheckInPromptKeyHandled(initialPromptKey);
          _showHomeFromReminderNotification();
        } finally {
          _openingReminderCheckIn = false;
        }
        return;
      }
      final preferences = await ref.read(sharedPreferencesProvider.future);
      if (preferences.getBool(firstExperienceKey) == true || !mounted) {
        _firstExperienceKey = firstExperienceKey;
        return;
      }

      final startCheckIn = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 18,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _FirstExperienceSheet(
                  onStart: () => Navigator.of(sheetContext).pop(true),
                  onDismiss: () => Navigator.of(sheetContext).pop(false),
                ),
              ),
            ),
          ),
        ),
      );
      if (!mounted || startCheckIn == null) {
        return;
      }

      await _markFirstExperienceHandled(firstExperienceKey);
      await _markInitialCheckInPromptKeyHandled(initialPromptKey);
      if (startCheckIn) {
        await _openCheckIn(compact: true);
      }
    } finally {
      _firstExperienceOpening = false;
    }
  }

  Future<void> _openInitialCheckInPromptIfNeeded(String key) async {
    if (!mounted || _initialCheckInPromptOpening) {
      return;
    }

    _initialCheckInPromptOpening = true;
    try {
      final preferences = await ref.read(sharedPreferencesProvider.future);
      if (preferences.getBool(key) == true || !mounted) {
        return;
      }

      await _markInitialCheckInPromptKeyHandled(key);
      await _openCheckIn(compact: true);
    } finally {
      _initialCheckInPromptOpening = false;
    }
  }

  String _initialCheckInPromptStorageKey(String userId) {
    final now = DateTime.now().toLocal();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return 'evolua.initial_checkin_prompt.$userId.$date';
  }

  String _firstExperienceStorageKey(String userId) {
    return 'evolua.first_experience.$userId.v1';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledBillingReturn) {
      return;
    }
    final checkoutId = Uri.base.queryParameters['billingCheckoutId'];
    if (checkoutId == null || checkoutId.isEmpty) {
      _handledBillingReturn = true;
      return;
    }
    _handledBillingReturn = true;
    _selectedIndex = _profileIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(subscriptionControllerProvider.notifier)
          .trackCheckout(checkoutId);
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    StartupDiagnostics.mark('home dashboard first build');
    final isCompact = ResponsiveBreakpoints.isCompact(context);
    final pagePadding = ResponsiveBreakpoints.pagePadding(context);
    final session = ref.watch(authControllerProvider).asData?.value;
    _preloadInterstitialForFreeUser(session);
    _schedulePostLoginWarmup(session);
    final checkInState = ref.watch(checkInControllerProvider);
    final historyForFirstExperience = checkInState.asData?.value;
    final shouldFirstExperienceHandleCheckIn =
        isCompact &&
        session != null &&
        historyForFirstExperience != null &&
        historyForFirstExperience.belongsToUser(session.userId) &&
        historyForFirstExperience.latestCreatedCheckIn == null &&
        historyForFirstExperience.result.items.isEmpty;
    _scheduleInitialCheckInPrompt(
      isCompact: isCompact,
      session: session,
      checkInState: checkInState,
    );
    if (!shouldFirstExperienceHandleCheckIn) {
      _consumePendingReminderCheckInIfNeeded(session: session);
    }
    final isAdmin = session?.isAdmin ?? false;
    final l10n = context.l10n;
    final destinations = [
      _NavItem(label: l10n.navHome, icon: Icons.home_rounded),
      _NavItem(label: l10n.navTrails, icon: Icons.auto_stories_rounded),
      _NavItem(label: l10n.navSpaces, icon: Icons.groups_rounded),
      _NavItem(label: l10n.navMirror, icon: Icons.auto_graph_rounded),
    ];

    final content = _DashboardContent(
      selectedIndex: _selectedIndex,
      trailSection: _trailSection,
      suggestedTrailIdToOpen: _suggestedTrailIdToOpen,
      spaceSection: _spaceSection,
      reflectionScope: _reflectionScope,
      profileSection: _profileSection,
      adminSection: _adminSection,
      onNavigate: _goTo,
      onOpenSuggestedTrail: _openSuggestedTrail,
      onSuggestedTrailConsumed: _consumeSuggestedTrailOpen,
      onOpenSpacesSection: _openSpacesSection,
      onSpacesInternalBackChanged: (action) {
        _spacesInternalBackAction = action;
      },
      onOpenMentor: () => _goTo(_mentorIndex),
      onOpenProfileSection: _openProfileSection,
      onOpenAdminSection: _openAdminSection,
      onOpenFutureMessages: () => context.push('/future-messages'),
      onOpenCheckIn: () => _openCheckInSafely(compact: isCompact),
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
      onResendEmailVerification: _resendEmailVerification,
      onRefreshEmailVerification: _refreshEmailVerificationStatus,
      isResendingEmailVerification: _resendingEmailVerification,
      isRefreshingEmailVerification: _refreshingEmailVerification,
    );

    return PopScope<void>(
      canPop: !isCompact || (_selectedIndex == 0 && _history.isEmpty),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !isCompact) {
          return;
        }
        _handleMobileBack();
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          pagePadding,
          16,
          pagePadding,
          isCompact ? 10 : 24,
        ),
        child: isCompact
            ? Column(
                children: [
                  Expanded(child: content),
                  const SizedBox(height: 12),
                  PrimaryPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    semanticLabel: 'Navegação principal',
                    child: NavigationBar(
                      selectedIndex: _selectedIndex >= destinations.length
                          ? 0
                          : _selectedIndex,
                      height: 72,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      onDestinationSelected: _goTo,
                      destinations: destinations
                          .map(
                            (item) => NavigationDestination(
                              icon: Tooltip(
                                message: item.label,
                                child: Icon(item.icon),
                              ),
                              selectedIcon: Icon(item.icon),
                              label: item.label,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 308),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: PrimaryPanel(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            semanticLabel: 'Menu lateral',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const EvoluaLogo(
                                  variant: EvoluaLogoVariant.sidebar,
                                ),
                                const SizedBox(height: 24),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        ...List.generate(destinations.length, (
                                          index,
                                        ) {
                                          final item = destinations[index];
                                          final isSelected =
                                              index == _selectedIndex;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: _NavEntry(
                                              item: item,
                                              isSelected: isSelected,
                                              onTap: () => _goTo(index),
                                              submenu: switch (index) {
                                                1 when isSelected =>
                                                  _buildDesktopSubmenu(
                                                    context,
                                                    entries: [
                                                      _SubnavEntry(
                                                        label:
                                                            l10n.trailMyJourney,
                                                        selected:
                                                            _trailSection ==
                                                            ContentModuleSection
                                                                .journey,
                                                        onTap: () =>
                                                            _setTrailSection(
                                                              ContentModuleSection
                                                                  .journey,
                                                            ),
                                                      ),
                                                      _SubnavEntry(
                                                        label:
                                                            l10n.trailCatalog,
                                                        selected:
                                                            _trailSection ==
                                                            ContentModuleSection
                                                                .catalog,
                                                        onTap: () =>
                                                            _setTrailSection(
                                                              ContentModuleSection
                                                                  .catalog,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                2 when isSelected =>
                                                  _buildDesktopSubmenu(
                                                    context,
                                                    entries: [
                                                      _SubnavEntry(
                                                        label:
                                                            l10n.spacesFeatured,
                                                        selected:
                                                            _spaceSection ==
                                                            SocialModuleTab
                                                                .featured,
                                                        onTap: () =>
                                                            _openSpacesSection(
                                                              SocialModuleTab
                                                                  .featured,
                                                            ),
                                                      ),
                                                      _SubnavEntry(
                                                        label: l10n
                                                            .spacesReflections,
                                                        selected:
                                                            _spaceSection ==
                                                            SocialModuleTab
                                                                .reflections,
                                                        onTap: () =>
                                                            _openSpacesSection(
                                                              SocialModuleTab
                                                                  .reflections,
                                                            ),
                                                      ),
                                                      _SubnavEntry(
                                                        label: l10n.spacesMine,
                                                        selected:
                                                            _spaceSection ==
                                                            SocialModuleTab
                                                                .mySpaces,
                                                        onTap: () =>
                                                            _openSpacesSection(
                                                              SocialModuleTab
                                                                  .mySpaces,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                _ => null,
                                              },
                                            ),
                                          );
                                        }),
                                        if (isAdmin)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: _NavEntry(
                                              item: _NavItem(
                                                label: l10n.navAdminPanel,
                                                icon: Icons
                                                    .admin_panel_settings_rounded,
                                              ),
                                              isSelected:
                                                  _selectedIndex == _adminIndex,
                                              onTap: () => _goTo(_adminIndex),
                                              submenu:
                                                  _selectedIndex == _adminIndex
                                                  ? _buildDesktopSubmenu(
                                                      context,
                                                      entries: [
                                                        _SubnavEntry(
                                                          label: l10n.navTrails,
                                                          selected:
                                                              _adminSection ==
                                                              AdminPanelSection
                                                                  .trails,
                                                          onTap: () =>
                                                              _openAdminSection(
                                                                AdminPanelSection
                                                                    .trails,
                                                              ),
                                                        ),
                                                        _SubnavEntry(
                                                          label: l10n
                                                              .notificationsTitle,
                                                          selected:
                                                              _adminSection ==
                                                              AdminPanelSection
                                                                  .notifications,
                                                          onTap: () =>
                                                              _openAdminSection(
                                                                AdminPanelSection
                                                                    .notifications,
                                                              ),
                                                        ),
                                                      ],
                                                    )
                                                  : null,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(child: content),
                    ],
                  );
                },
              ),
      ),
    );
  }

  void _preloadInterstitialForFreeUser(AuthSession? session) {
    if (session == null ||
        session.isPremium ||
        _interstitialPreloadUserId == session.userId) {
      return;
    }
    _interstitialPreloadUserId = session.userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(interstitialAdServiceProvider).preload();
    });
  }

  void _schedulePostLoginWarmup(AuthSession? session) {
    if (session == null || _startupWarmupUserId == session.userId) {
      return;
    }
    _startupWarmupUserId = session.userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(appStartupControllerProvider)
          .warmUpAfterFirstFrame(
            ref.read(authControllerProvider).asData?.value,
          );
    });
  }
}

class _DashboardLocation {
  const _DashboardLocation({
    required this.selectedIndex,
    required this.trailSection,
    required this.spaceSection,
    required this.profileSection,
    required this.adminSection,
  });

  final int selectedIndex;
  final ContentModuleSection trailSection;
  final SocialModuleTab spaceSection;
  final ProfileModuleSection profileSection;
  final AdminPanelSection adminSection;

  @override
  bool operator ==(Object other) {
    return other is _DashboardLocation &&
        other.selectedIndex == selectedIndex &&
        other.trailSection == trailSection &&
        other.spaceSection == spaceSection &&
        other.profileSection == profileSection &&
        other.adminSection == adminSection;
  }

  @override
  int get hashCode => Object.hash(
    selectedIndex,
    trailSection,
    spaceSection,
    profileSection,
    adminSection,
  );
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({
    required this.selectedIndex,
    required this.trailSection,
    required this.suggestedTrailIdToOpen,
    required this.spaceSection,
    required this.reflectionScope,
    required this.profileSection,
    required this.adminSection,
    required this.onNavigate,
    required this.onOpenSuggestedTrail,
    required this.onSuggestedTrailConsumed,
    required this.onOpenSpacesSection,
    required this.onSpacesInternalBackChanged,
    required this.onOpenMentor,
    required this.onOpenProfileSection,
    required this.onOpenAdminSection,
    required this.onOpenFutureMessages,
    required this.onOpenCheckIn,
    required this.onLogout,
    required this.onResendEmailVerification,
    required this.onRefreshEmailVerification,
    required this.isResendingEmailVerification,
    required this.isRefreshingEmailVerification,
  });

  final int selectedIndex;
  final ContentModuleSection trailSection;
  final int? suggestedTrailIdToOpen;
  final SocialModuleTab spaceSection;
  final SocialFeedScope reflectionScope;
  final ProfileModuleSection profileSection;
  final AdminPanelSection adminSection;
  final void Function(int index) onNavigate;
  final ValueChanged<int> onOpenSuggestedTrail;
  final VoidCallback onSuggestedTrailConsumed;
  final void Function(SocialModuleTab section) onOpenSpacesSection;
  final ValueChanged<VoidCallback?> onSpacesInternalBackChanged;
  final VoidCallback onOpenMentor;
  final void Function(ProfileModuleSection section) onOpenProfileSection;
  final void Function(AdminPanelSection section) onOpenAdminSection;
  final VoidCallback onOpenFutureMessages;
  final VoidCallback onOpenCheckIn;
  final VoidCallback onLogout;
  final Future<void> Function() onResendEmailVerification;
  final Future<void> Function() onRefreshEmailVerification;
  final bool isResendingEmailVerification;
  final bool isRefreshingEmailVerification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;
    final sessionUserId = session?.userId ?? 'anonymous';
    final isHomeSelected = selectedIndex == 0;
    final shouldReadProfile = selectedIndex == 3 || selectedIndex == 4;
    final profile = shouldReadProfile
        ? ref.watch(currentProfileProvider)
        : null;
    final currentSubscription = null;
    final trailsCount = 0;
    final checkInsCount = isHomeSelected
        ? ref
                  .watch(checkInControllerProvider)
                  .asData
                  ?.value
                  .result
                  .totalItems ??
              0
        : 0;
    final postsCount = 0;
    final communitiesCount = 0;
    final compact = ResponsiveBreakpoints.isCompact(context);
    final pageTitle = _pageTitleFor(context, selectedIndex);
    final preferences =
        ref.watch(accessibilityPreferencesControllerProvider).value ??
        AccessibilityPreferences.defaults();
    final reduceMotion = preferences.shouldReduceMotion;

    final sections = [
      HomeHubView(
        profilesCount: profile == null ? 0 : 1,
        trailsCount: trailsCount,
        checkInsCount: checkInsCount,
        postsCount: postsCount,
        communitiesCount: communitiesCount,
        displayName: profile?.displayName ?? session?.displayName,
        mentorPremiumPassActive:
            currentSubscription?.mentorPremiumPassActive ?? false,
        mentorPremiumPassEndsAt: currentSubscription?.mentorPremiumPassEndsAt,
        deferSecondaryProviders: true,
        checkInGateHandledExternally: true,
        onOpenTrails: () => onNavigate(1),
        onOpenSuggestedTrail: onOpenSuggestedTrail,
        onOpenFeed: () => onOpenSpacesSection(SocialModuleTab.reflections),
        onOpenCommunity: () => onOpenSpacesSection(SocialModuleTab.featured),
        onOpenProfile: () =>
            onOpenProfileSection(ProfileModuleSection.overview),
        onOpenEvolutionMirror: () =>
            onOpenProfileSection(ProfileModuleSection.evolutionMirror),
        onOpenFutureMessages: () => context.push('/future-messages'),
        onOpenFutureMessage: (id) => context.push('/future-messages/$id'),
        onOpenCareShare: () => context.push('/care/share'),
        onOpenDailyRitual: (type) => context.push(
          '/daily-ritual?type=${type == 'EVENING' ? 'evening' : 'morning'}',
        ),
        onOpenCheckIn: onOpenCheckIn,
        onOpenPremium: () =>
            onOpenProfileSection(ProfileModuleSection.plansSubscriptions),
      ),
      ContentModuleView(
        key: ValueKey('trails-$sessionUserId-${trailSection.name}'),
        section: trailSection,
        initialTrailId: suggestedTrailIdToOpen,
        onInitialTrailConsumed: onSuggestedTrailConsumed,
        showSectionChips: compact,
        onOpenMentor: onOpenMentor,
        onOpenPremium: () =>
            onOpenProfileSection(ProfileModuleSection.plansSubscriptions),
      ),
      SocialModuleView(
        key: ValueKey('spaces-${spaceSection.name}-${reflectionScope.name}'),
        initialTab: spaceSection,
        feedScope: reflectionScope,
        showTabs: true,
        showScopeChips: false,
        onTabChanged: onOpenSpacesSection,
        onOpenFutureMessages: () => context.push('/future-messages'),
        onInternalBackChanged: onSpacesInternalBackChanged,
      ),
      const _ProfileArea(section: ProfileModuleSection.evolutionMirror),
      _ProfileArea(section: profileSection),
      MentorEvoluaModuleView(
        onOpenTrails: () => onNavigate(1),
        onOpenPremium: () =>
            onOpenProfileSection(ProfileModuleSection.plansSubscriptions),
      ),
      session?.isAdmin == true
          ? AdminPanelView(
              section: adminSection,
              onOpenSection: onOpenAdminSection,
            )
          : const AdminAccessDeniedPanel(),
    ];

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: PrimaryPanel(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 18,
              vertical: 10,
            ),
            semanticLabel: 'Cabeçalho da área autenticada',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: compact
                      ? const _TopBarIdentity()
                      : _TopBarTitle(title: pageTitle),
                ),
                const SizedBox(width: 16),
                _HeaderActions(
                  notificationBell: const NotificationBellButton(),
                  session: session,
                  profile: profile,
                  onOpenCheckIn: onOpenCheckIn,
                  onOpenProfileSection: onOpenProfileSection,
                  onOpenAdminPanel: session?.isAdmin == true
                      ? () => onOpenAdminSection(AdminPanelSection.overview)
                      : null,
                  onOpenFutureMessages: onOpenFutureMessages,
                  onOpenCareShare: () => context.push('/care/share'),
                  onLogout: onLogout,
                ),
              ],
            ),
          ),
        ),
        if (session != null && !session.emailVerified) ...[
          const SizedBox(height: 12),
          _EmailVerificationNotice(
            onResend: onResendEmailVerification,
            onRefresh: onRefreshEmailVerification,
            resending: isResendingEmailVerification,
            refreshing: isRefreshingEmailVerification,
          ),
        ],
        const SizedBox(height: 18),
        Expanded(
          child: AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 260),
            reverseDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              if (reduceMotion) {
                return child;
              }
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.018, 0.015),
                    end: Offset.zero,
                  ).animate(curved),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.992, end: 1).animate(curved),
                    child: child,
                  ),
                ),
              );
            },
            child: selectedIndex == 1
                ? KeyedSubtree(
                    key: ValueKey(_sectionKey(sessionUserId)),
                    child:
                        sections[selectedIndex.clamp(0, sections.length - 1)],
                  )
                : SingleChildScrollView(
                    key: ValueKey(_sectionKey(sessionUserId)),
                    child:
                        sections[selectedIndex.clamp(0, sections.length - 1)],
                  ),
          ),
        ),
      ],
    );
  }

  String _pageTitleFor(BuildContext context, int index) {
    final l10n = context.l10n;
    return switch (index) {
      0 => l10n.navHome,
      1 => l10n.navTrails,
      2 => l10n.navSpaces,
      3 => l10n.navMirror,
      4 => l10n.navProfile,
      5 => 'Mentor Evolua',
      6 => switch (adminSection) {
        AdminPanelSection.overview => l10n.navAdminPanel,
        AdminPanelSection.trails => l10n.adminTrailsTitle,
        AdminPanelSection.notifications => l10n.adminNotificationsTitle,
      },
      _ => l10n.appTitle,
    };
  }

  String _sectionKey(String userId) {
    return switch (selectedIndex) {
      1 => 'trails-$userId-${trailSection.name}',
      2 => 'spaces-$userId-${spaceSection.name}-${reflectionScope.name}',
      3 => 'profile-$userId-${ProfileModuleSection.evolutionMirror.name}',
      4 => 'profile-$userId-${profileSection.name}',
      5 => 'mentor-$userId',
      6 => 'admin-$userId-${adminSection.name}',
      _ => 'main-$userId-$selectedIndex',
    };
  }
}

Widget? _buildDesktopSubmenu(
  BuildContext context, {
  required List<_SubnavEntry> entries,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 18),
    child: Column(
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: entry.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: entry.selected
                        ? context.evoluaColors.surfaceStrong.withValues(
                            alpha: 0.62,
                          )
                        : Colors.transparent,
                    border: Border.all(
                      color: entry.selected
                          ? AppColors.accent.withValues(alpha: 0.3)
                          : context.evoluaColors.outline.withValues(
                              alpha: 0.18,
                            ),
                    ),
                  ),
                  child: Text(
                    entry.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: entry.selected
                          ? context.evoluaColors.textPrimary
                          : context.evoluaColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _MobileSwipeRegion extends StatefulWidget {
  const _MobileSwipeRegion({
    required this.child,
    required this.onSwipeVelocity,
  });

  final Widget child;
  final ValueChanged<double> onSwipeVelocity;

  @override
  State<_MobileSwipeRegion> createState() => _MobileSwipeRegionState();
}

class _MobileSwipeRegionState extends State<_MobileSwipeRegion> {
  Offset? _startPosition;
  DateTime? _startTime;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _startPosition = event.position;
        _startTime = DateTime.now();
      },
      onPointerUp: (event) {
        final start = _startPosition;
        final startTime = _startTime;
        _startPosition = null;
        _startTime = null;
        if (start == null || startTime == null) {
          return;
        }

        final delta = event.position - start;
        if (delta.dx.abs() < 80 || delta.dx.abs() < delta.dy.abs() * 1.2) {
          return;
        }

        final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsedMs <= 0) {
          return;
        }

        widget.onSwipeVelocity(delta.dx / (elapsedMs / 1000));
      },
      child: widget.child,
    );
  }
}

class _ProfileArea extends StatelessWidget {
  const _ProfileArea({required this.section});

  final ProfileModuleSection section;

  @override
  Widget build(BuildContext context) {
    return ProfileModuleView(section: section);
  }
}

class _EmailVerificationNotice extends StatelessWidget {
  const _EmailVerificationNotice({
    required this.onResend,
    required this.onRefresh,
    required this.resending,
    required this.refreshing,
  });

  final Future<void> Function() onResend;
  final Future<void> Function() onRefresh;
  final bool resending;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final colors = context.evoluaColors;
    final busy = resending || refreshing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.mark_email_unread_rounded, color: AppColors.accent),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Confirme seu e-mail para manter sua conta mais segura.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: busy ? null : () => unawaited(onResend()),
            child: Text(resending ? 'Enviando...' : 'Reenviar e-mail'),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => unawaited(onRefresh()),
            child: Text(refreshing ? 'Atualizando...' : 'Ja confirmei'),
          ),
        ],
      ),
    );
  }
}

class _TopBarIdentity extends StatelessWidget {
  const _TopBarIdentity();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: context.evoluaColors.outline.withValues(alpha: 0.16),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/branding/app_logo_trimmed.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'Evolua',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBarTitle extends StatelessWidget {
  const _TopBarTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: context.evoluaColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.notificationBell,
    required this.session,
    required this.profile,
    required this.onOpenCheckIn,
    required this.onOpenProfileSection,
    required this.onOpenAdminPanel,
    required this.onOpenFutureMessages,
    required this.onOpenCareShare,
    required this.onLogout,
  });

  final Widget notificationBell;
  final AuthSession? session;
  final Profile? profile;
  final VoidCallback onOpenCheckIn;
  final void Function(ProfileModuleSection section) onOpenProfileSection;
  final VoidCallback? onOpenAdminPanel;
  final VoidCallback onOpenFutureMessages;
  final VoidCallback onOpenCareShare;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        notificationBell,
        const SizedBox(width: 8),
        _CheckInHeaderButton(onPressed: onOpenCheckIn),
        const SizedBox(width: 8),
        _AccountMenuButton(
          session: session,
          profile: profile,
          onOpenProfileSection: onOpenProfileSection,
          onOpenAdminPanel: onOpenAdminPanel,
          onOpenFutureMessages: onOpenFutureMessages,
          onOpenCareShare: onOpenCareShare,
          onLogout: onLogout,
        ),
      ],
    );
  }
}

class _CheckInHeaderButton extends StatelessWidget {
  const _CheckInHeaderButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: l10n.homeDailyDayPrimary,
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.favorite_rounded),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                border: Border.all(
                  color: context.evoluaColors.surface,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 10,
                color: context.evoluaColors.background,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountMenuButton extends StatelessWidget {
  const _AccountMenuButton({
    required this.session,
    required this.profile,
    required this.onOpenProfileSection,
    required this.onOpenAdminPanel,
    required this.onOpenFutureMessages,
    required this.onOpenCareShare,
    required this.onLogout,
  });

  final AuthSession? session;
  final Profile? profile;
  final void Function(ProfileModuleSection section) onOpenProfileSection;
  final VoidCallback? onOpenAdminPanel;
  final VoidCallback onOpenFutureMessages;
  final VoidCallback onOpenCareShare;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayName =
        profile?.displayName ??
        session?.displayName ??
        session?.email.split('@').first ??
        l10n.navProfile;
    final avatarUrl = profile?.avatarUrl ?? session?.avatarUrl;
    final email = session?.email ?? 'você@evolua.app';

    return PopupMenuButton<_AccountMenuAction>(
      tooltip: 'Abrir menu da conta',
      color: context.evoluaColors.surfaceStrong,
      offset: const Offset(0, 14),
      itemBuilder: (context) => [
        PopupMenuItem<_AccountMenuAction>(
          enabled: false,
          padding: const EdgeInsets.all(0),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderAvatar(
                      imageUrl: avatarUrl,
                      fallbackText: displayName,
                      radius: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _AccountMenuAction.overview,
          child: _MenuLabel(icon: Icons.person_rounded, label: l10n.navProfile),
        ),
        PopupMenuItem(
          value: _AccountMenuAction.settings,
          child: _MenuLabel(
            icon: Icons.settings_rounded,
            label: l10n.settingsPrivacyTitle,
          ),
        ),
        PopupMenuItem(
          value: _AccountMenuAction.plans,
          child: _MenuLabel(
            icon: Icons.workspace_premium_rounded,
            label: l10n.avatarPlans,
          ),
        ),
        PopupMenuItem(
          value: _AccountMenuAction.evolutionMirror,
          child: _MenuLabel(
            icon: Icons.auto_graph_rounded,
            label: l10n.avatarEvolutionMirror,
          ),
        ),
        PopupMenuItem(
          value: _AccountMenuAction.futureMessages,
          child: _MenuLabel(
            icon: Icons.forward_to_inbox_rounded,
            label: l10n.avatarFutureMessages,
          ),
        ),
        const PopupMenuItem(
          value: _AccountMenuAction.careShare,
          child: _MenuLabel(
            icon: Icons.health_and_safety_outlined,
            label: 'Conectar Terapeuta',
          ),
        ),
        if (onOpenAdminPanel != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _AccountMenuAction.adminPanel,
            child: _MenuLabel(
              icon: Icons.admin_panel_settings_rounded,
              label: l10n.navAdminPanel,
            ),
          ),
        ],
        const PopupMenuItem(
          value: _AccountMenuAction.help,
          child: _MenuLabel(
            icon: Icons.help_outline_rounded,
            label: 'Ajuda e suporte',
          ),
        ),
        const PopupMenuItem(
          value: _AccountMenuAction.accessibility,
          child: _MenuLabel(
            icon: Icons.dark_mode_rounded,
            label: 'Tela e acessibilidade',
          ),
        ),
        const PopupMenuItem(
          value: _AccountMenuAction.feedback,
          child: _MenuLabel(
            icon: Icons.feedback_outlined,
            label: 'Dar feedback',
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _AccountMenuAction.logout,
          child: _MenuLabel(
            icon: Icons.logout_rounded,
            label: l10n.avatarLogout,
          ),
        ),
        const PopupMenuItem<_AccountMenuAction>(
          enabled: false,
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _AccountMenuSignature(),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case _AccountMenuAction.overview:
            onOpenProfileSection(ProfileModuleSection.overview);
          case _AccountMenuAction.plans:
            onOpenProfileSection(ProfileModuleSection.plansSubscriptions);
          case _AccountMenuAction.evolutionMirror:
            onOpenProfileSection(ProfileModuleSection.evolutionMirror);
          case _AccountMenuAction.futureMessages:
            onOpenFutureMessages();
          case _AccountMenuAction.careShare:
            onOpenCareShare();
          case _AccountMenuAction.adminPanel:
            onOpenAdminPanel?.call();
          case _AccountMenuAction.settings:
            onOpenProfileSection(ProfileModuleSection.settingsPrivacy);
          case _AccountMenuAction.help:
            onOpenProfileSection(ProfileModuleSection.helpSupport);
          case _AccountMenuAction.accessibility:
            onOpenProfileSection(ProfileModuleSection.displayAccessibility);
          case _AccountMenuAction.feedback:
            onOpenProfileSection(ProfileModuleSection.feedback);
          case _AccountMenuAction.logout:
            onLogout();
        }
      },
      child: _HeaderAvatar(
        imageUrl: avatarUrl,
        fallbackText: displayName,
        radius: 22,
      ),
    );
  }
}

class _FirstExperienceSheet extends StatelessWidget {
  const _FirstExperienceSheet({required this.onStart, required this.onDismiss});

  final VoidCallback onStart;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PrimaryPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.firstExperienceTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.firstExperienceMainMessage,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.firstExperienceDescription,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.evoluaColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(l10n.firstExperienceStart),
              ),
              OutlinedButton(
                onPressed: onDismiss,
                child: Text(l10n.firstExperienceNotNow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _AccountMenuAction {
  overview,
  plans,
  evolutionMirror,
  futureMessages,
  careShare,
  adminPanel,
  settings,
  help,
  accessibility,
  feedback,
  logout,
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({
    required this.imageUrl,
    required this.fallbackText,
    required this.radius,
  });

  final String? imageUrl;
  final String fallbackText;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl == null || imageUrl!.isEmpty
        ? null
        : imageUrl!;
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.evoluaColors.surfaceStrong,
      backgroundImage: normalizedUrl != null
          ? NetworkImage(normalizedUrl)
          : null,
      child: normalizedUrl == null
          ? Text(
              _initials(fallbackText),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.evoluaColors.textPrimary,
              ),
            )
          : null,
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'E';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _AccountMenuSignature extends StatelessWidget {
  const _AccountMenuSignature();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(left: 36),
      child: Text(
        '${l10n.avatarSignatureCreatedBy}\n${l10n.avatarSignatureVersion}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.evoluaColors.textSecondary.withValues(alpha: 0.72),
          height: 1.35,
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _SubnavEntry {
  const _SubnavEntry({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
}

class _NavEntry extends StatelessWidget {
  const _NavEntry({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.submenu,
  });

  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? submenu;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.18)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent.withValues(alpha: 0.45)
                      : context.evoluaColors.outline.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: isSelected
                        ? AppColors.accent
                        : context.evoluaColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isSelected
                            ? context.evoluaColors.textPrimary
                            : context.evoluaColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...?(submenu == null ? null : [submenu!]),
        ],
      ),
    );
  }
}
