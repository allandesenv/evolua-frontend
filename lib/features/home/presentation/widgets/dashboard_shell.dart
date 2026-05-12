import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/content_module_view.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/mentor_evolua_module_view.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/home/presentation/widgets/home_hub_view.dart';
import 'package:evolua_frontend/features/notification/presentation/widgets/notification_module_view.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_module_view.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/user/application/accessibility_preferences_controller.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/presentation/widgets/profile_module_view.dart';
import 'package:evolua_frontend/shared/presentation/widgets/evolua_logo.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _selectedIndex = 0;
  ContentModuleSection _trailSection = ContentModuleSection.journey;
  SocialModuleTab _spaceSection = SocialModuleTab.featured;
  final SocialFeedScope _reflectionScope = SocialFeedScope.moment;
  ProfileModuleSection _profileSection = ProfileModuleSection.overview;
  final List<_DashboardLocation> _history = [];
  bool _handledBillingReturn = false;

  static const _destinations = [
    _NavItem(label: 'Inicio', icon: Icons.home_rounded),
    _NavItem(label: 'Trilhas', icon: Icons.auto_stories_rounded),
    _NavItem(label: 'Espacos', icon: Icons.groups_rounded),
    _NavItem(label: 'Espelho', icon: Icons.auto_graph_rounded),
  ];

  static const _spacesIndex = 2;
  static const _mirrorIndex = 3;
  static const _profileIndex = 4;
  static const _mentorIndex = 5;
  static const _swipeVelocityThreshold = 350.0;

  _DashboardLocation _currentLocation() {
    return _DashboardLocation(
      selectedIndex: _selectedIndex,
      trailSection: _trailSection,
      spaceSection: _spaceSection,
      profileSection: _profileSection,
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
  }

  void _goTo(int index, {bool recordHistory = true}) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      if (index == 0) {
        _history.clear();
      } else if (recordHistory) {
        _pushCurrentLocation();
      }
      _selectedIndex = index;
      if (index == _mirrorIndex) {
        _profileSection = ProfileModuleSection.evolutionMirror;
      }
    });
  }

  void _setTrailSection(ContentModuleSection section) {
    if (_selectedIndex == 1 && _trailSection == section) {
      return;
    }

    setState(() {
      _pushCurrentLocation();
      _selectedIndex = 1;
      _trailSection = section;
    });
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

  void _handleMobileBack() {
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

  void _handleMobileSwipeVelocity(double velocity) {
    if (_selectedIndex < 0 || _selectedIndex >= _destinations.length) {
      return;
    }

    if (velocity.abs() < _swipeVelocityThreshold) {
      return;
    }

    if (velocity < 0 && _selectedIndex < _destinations.length - 1) {
      _goTo(_selectedIndex + 1);
      return;
    }

    if (velocity > 0 && _selectedIndex > 0) {
      _goTo(_selectedIndex - 1);
    }
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
    final isCompact = ResponsiveBreakpoints.isCompact(context);
    final pagePadding = ResponsiveBreakpoints.pagePadding(context);

    final content = _DashboardContent(
      selectedIndex: _selectedIndex,
      trailSection: _trailSection,
      spaceSection: _spaceSection,
      reflectionScope: _reflectionScope,
      profileSection: _profileSection,
      onNavigate: _goTo,
      onOpenSpacesSection: _openSpacesSection,
      onOpenMentor: () => _goTo(_mentorIndex),
      onOpenProfileSection: _openProfileSection,
      onOpenFutureMessages: () => context.push('/future-messages'),
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
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
                  Expanded(
                    child: content,
                  ),
                  const SizedBox(height: 12),
                  PrimaryPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    semanticLabel: 'Navegacao principal',
                    child: NavigationBar(
                      selectedIndex: _selectedIndex >= _destinations.length
                          ? 0
                          : _selectedIndex,
                      height: 72,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      onDestinationSelected: _goTo,
                      destinations: _destinations
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
                                      children: List.generate(
                                        _destinations.length,
                                        (index) {
                                          final item = _destinations[index];
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
                                                        label: 'Minha jornada',
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
                                                        label: 'Catalogo',
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
                                                        label: 'Em destaque',
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
                                                        label: 'Reflexoes',
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
                                                        label: 'Meus espacos',
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
                                        },
                                      ),
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
}

class _DashboardLocation {
  const _DashboardLocation({
    required this.selectedIndex,
    required this.trailSection,
    required this.spaceSection,
    required this.profileSection,
  });

  final int selectedIndex;
  final ContentModuleSection trailSection;
  final SocialModuleTab spaceSection;
  final ProfileModuleSection profileSection;

  @override
  bool operator ==(Object other) {
    return other is _DashboardLocation &&
        other.selectedIndex == selectedIndex &&
        other.trailSection == trailSection &&
        other.spaceSection == spaceSection &&
        other.profileSection == profileSection;
  }

  @override
  int get hashCode =>
      Object.hash(selectedIndex, trailSection, spaceSection, profileSection);
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({
    required this.selectedIndex,
    required this.trailSection,
    required this.spaceSection,
    required this.reflectionScope,
    required this.profileSection,
    required this.onNavigate,
    required this.onOpenSpacesSection,
    required this.onOpenMentor,
    required this.onOpenProfileSection,
    required this.onOpenFutureMessages,
    required this.onLogout,
  });

  final int selectedIndex;
  final ContentModuleSection trailSection;
  final SocialModuleTab spaceSection;
  final SocialFeedScope reflectionScope;
  final ProfileModuleSection profileSection;
  final void Function(int index) onNavigate;
  final void Function(SocialModuleTab section) onOpenSpacesSection;
  final VoidCallback onOpenMentor;
  final void Function(ProfileModuleSection section) onOpenProfileSection;
  final VoidCallback onOpenFutureMessages;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final currentSubscription = ref
        .watch(subscriptionControllerProvider)
        .asData
        ?.value
        .current;
    final trailsCount =
        ref.watch(trailControllerProvider).asData?.value.totalItems ?? 0;
    final checkInsCount =
        ref.watch(checkInControllerProvider).asData?.value.result.totalItems ??
        0;
    final postsCount =
        ref.watch(socialPostControllerProvider).asData?.value.totalItems ?? 0;
    final communitiesCount =
        ref.watch(communityControllerProvider).asData?.value.totalItems ?? 0;
    final compact = ResponsiveBreakpoints.isCompact(context);
    final pageTitle = _pageTitleFor(selectedIndex);
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
        displayName: profile?.displayName,
        mentorPremiumPassActive:
            currentSubscription?.mentorPremiumPassActive ?? false,
        mentorPremiumPassEndsAt: currentSubscription?.mentorPremiumPassEndsAt,
        onOpenTrails: () => onNavigate(1),
        onOpenFeed: () => onOpenSpacesSection(SocialModuleTab.reflections),
        onOpenCommunity: () => onOpenSpacesSection(SocialModuleTab.featured),
        onOpenProfile: () =>
            onOpenProfileSection(ProfileModuleSection.overview),
        onOpenEvolutionMirror: () =>
            onOpenProfileSection(ProfileModuleSection.evolutionMirror),
        onOpenFutureMessages: () => context.push('/future-messages'),
        onOpenFutureMessage: (id) => context.push('/future-messages/$id'),
        onOpenDailyRitual: (type) => context.push(
          '/daily-ritual?type=${type == 'EVENING' ? 'evening' : 'morning'}',
        ),
        onOpenCheckIn: () => context.push('/check-in'),
        onOpenPremium: () =>
            onOpenProfileSection(ProfileModuleSection.plansSubscriptions),
      ),
      ContentModuleView(
        key: ValueKey('trails-${trailSection.name}'),
        section: trailSection,
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
      ),
      const _ProfileArea(section: ProfileModuleSection.evolutionMirror),
      _ProfileArea(section: profileSection),
      MentorEvoluaModuleView(
        onOpenTrails: () => onNavigate(1),
        onOpenPremium: () =>
            onOpenProfileSection(ProfileModuleSection.plansSubscriptions),
      ),
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
            semanticLabel: 'Cabecalho da area autenticada',
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
                  onOpenCheckIn: () => context.push('/check-in'),
                  onOpenProfileSection: onOpenProfileSection,
                  onOpenFutureMessages: onOpenFutureMessages,
                  onLogout: onLogout,
                ),
              ],
            ),
          ),
        ),
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
                    key: ValueKey(_sectionKey()),
                    child:
                        sections[selectedIndex.clamp(0, sections.length - 1)],
                  )
                : SingleChildScrollView(
                    key: ValueKey(_sectionKey()),
                    child:
                        sections[selectedIndex.clamp(0, sections.length - 1)],
                  ),
          ),
        ),
      ],
    );
  }

  String _pageTitleFor(int index) {
    return switch (index) {
      0 => 'Inicio',
      1 => 'Trilhas',
      2 => 'Espacos',
      3 => 'Espelho',
      4 => 'Perfil',
      5 => 'Mentor Evolua',
      _ => 'Evolua',
    };
  }

  String _sectionKey() {
    return switch (selectedIndex) {
      1 => 'trails-${trailSection.name}',
      2 => 'spaces-${spaceSection.name}-${reflectionScope.name}',
      3 => 'profile-${ProfileModuleSection.evolutionMirror.name}',
      4 => 'profile-${profileSection.name}',
      5 => 'mentor',
      _ => 'main-$selectedIndex',
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
    required this.onOpenFutureMessages,
    required this.onLogout,
  });

  final Widget notificationBell;
  final AuthSession? session;
  final Profile? profile;
  final VoidCallback onOpenCheckIn;
  final void Function(ProfileModuleSection section) onOpenProfileSection;
  final VoidCallback onOpenFutureMessages;
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
          onOpenFutureMessages: onOpenFutureMessages,
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
    return IconButton(
      tooltip: 'Fazer check-in',
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
    required this.onOpenFutureMessages,
    required this.onLogout,
  });

  final AuthSession? session;
  final Profile? profile;
  final void Function(ProfileModuleSection section) onOpenProfileSection;
  final VoidCallback onOpenFutureMessages;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final displayName =
        profile?.displayName ??
        session?.displayName ??
        session?.email.split('@').first ??
        'Seu perfil';
    final avatarUrl = profile?.avatarUrl ?? session?.avatarUrl;
    final email = session?.email ?? 'voce@evolua.app';

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
        const PopupMenuItem(
          value: _AccountMenuAction.overview,
          child: _MenuLabel(icon: Icons.person_rounded, label: 'Ver perfil'),
        ),
        const PopupMenuItem(
          value: _AccountMenuAction.plans,
          child: _MenuLabel(
            icon: Icons.workspace_premium_rounded,
            label: 'Planos e assinaturas',
          ),
        ),
        const PopupMenuItem(
          value: _AccountMenuAction.evolutionMirror,
          child: _MenuLabel(
            icon: Icons.auto_graph_rounded,
            label: 'Espelho da Evolucao',
          ),
        ),
        const PopupMenuItem(
          value: _AccountMenuAction.futureMessages,
          child: _MenuLabel(
            icon: Icons.forward_to_inbox_rounded,
            label: 'Mensagens para o futuro',
          ),
        ),
        const PopupMenuItem(
          value: _AccountMenuAction.settings,
          child: _MenuLabel(
            icon: Icons.settings_rounded,
            label: 'Configuracoes e privacidade',
          ),
        ),
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
        const PopupMenuItem(
          value: _AccountMenuAction.logout,
          child: _MenuLabel(icon: Icons.logout_rounded, label: 'Sair'),
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

enum _AccountMenuAction {
  overview,
  plans,
  evolutionMirror,
  futureMessages,
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
