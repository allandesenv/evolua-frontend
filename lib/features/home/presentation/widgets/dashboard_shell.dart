import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/content_module_view.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/home/presentation/widgets/home_hub_view.dart';
import 'package:evolua_frontend/features/notification/presentation/widgets/notification_module_view.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/social/presentation/widgets/social_module_view.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/presentation/widgets/subscription_module_view.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
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
  SocialFeedScope _reflectionScope = SocialFeedScope.moment;
  SocialCommunityScope _spaceScope = SocialCommunityScope.explore;
  bool _handledBillingReturn = false;

  static const _destinations = [
    _NavItem(label: 'Home', icon: Icons.home_rounded),
    _NavItem(label: 'Trilhas', icon: Icons.auto_stories_rounded),
    _NavItem(label: 'Reflexoes', icon: Icons.dynamic_feed_rounded),
    _NavItem(label: 'Espacos', icon: Icons.groups_rounded),
    _NavItem(label: 'Perfil', icon: Icons.person_rounded),
  ];

  void _goTo(int index) {
    setState(() => _selectedIndex = index);
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
    _selectedIndex = 4;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionControllerProvider.notifier).trackCheckout(checkoutId);
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveBreakpoints.isCompact(context);
    final pagePadding = ResponsiveBreakpoints.pagePadding(context);
    final session = ref.watch(authControllerProvider).asData?.value;

    final content = _DashboardContent(
      selectedIndex: _selectedIndex,
      email: session?.email ?? 'voce@evolua.app',
      trailSection: _trailSection,
      reflectionScope: _reflectionScope,
      spaceScope: _spaceScope,
      onNavigate: _goTo,
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
    );

    return Padding(
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
                  semanticLabel: 'Navegacao principal',
                  child: NavigationBar(
                    selectedIndex: _selectedIndex,
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
                              const EvoluaLogo(compact: true),
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
                                                      onTap: () => setState(
                                                        () => _trailSection =
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
                                                      onTap: () => setState(
                                                        () => _trailSection =
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
                                                      label: 'Do momento',
                                                      selected:
                                                          _reflectionScope ==
                                                          SocialFeedScope
                                                              .moment,
                                                      onTap: () => setState(
                                                        () => _reflectionScope =
                                                            SocialFeedScope
                                                                .moment,
                                                      ),
                                                    ),
                                                    _SubnavEntry(
                                                      label: 'Minhas reflexoes',
                                                      selected:
                                                          _reflectionScope ==
                                                          SocialFeedScope.mine,
                                                      onTap: () => setState(
                                                        () => _reflectionScope =
                                                            SocialFeedScope
                                                                .mine,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              3 when isSelected =>
                                                _buildDesktopSubmenu(
                                                  context,
                                                  entries: [
                                                    _SubnavEntry(
                                                      label: 'Explorar',
                                                      selected:
                                                          _spaceScope ==
                                                          SocialCommunityScope
                                                              .explore,
                                                      onTap: () => setState(
                                                        () => _spaceScope =
                                                            SocialCommunityScope
                                                                .explore,
                                                      ),
                                                    ),
                                                    _SubnavEntry(
                                                      label: 'Meus espacos',
                                                      selected:
                                                          _spaceScope ==
                                                          SocialCommunityScope
                                                              .mine,
                                                      onTap: () => setState(
                                                        () => _spaceScope =
                                                            SocialCommunityScope
                                                                .mine,
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
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({
    required this.selectedIndex,
    required this.email,
    required this.trailSection,
    required this.reflectionScope,
    required this.spaceScope,
    required this.onNavigate,
    required this.onLogout,
  });

  final int selectedIndex;
  final String email;
  final ContentModuleSection trailSection;
  final SocialFeedScope reflectionScope;
  final SocialCommunityScope spaceScope;
  final void Function(int index) onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles =
        ref.watch(profileControllerProvider).asData?.value ?? const [];
    final trailsCount =
        ref.watch(trailControllerProvider).asData?.value.totalItems ?? 0;
    final checkInsCount =
        ref.watch(checkInControllerProvider).asData?.value.result.totalItems ??
        0;
    final postsCount =
        ref.watch(socialPostControllerProvider).asData?.value.totalItems ?? 0;
    final communitiesCount =
        ref.watch(communityControllerProvider).asData?.value.totalItems ?? 0;

    final sections = [
      HomeHubView(
        profilesCount: profiles.length,
        trailsCount: trailsCount,
        checkInsCount: checkInsCount,
        postsCount: postsCount,
        communitiesCount: communitiesCount,
        onOpenTrails: () => onNavigate(1),
        onOpenFeed: () => onNavigate(2),
        onOpenCommunity: () => onNavigate(3),
        onOpenProfile: () => onNavigate(4),
      ),
      ContentModuleView(
        key: ValueKey('trails-${trailSection.name}'),
        section: trailSection,
        showSectionChips: true,
      ),
      SocialModuleView(
        key: ValueKey('feed-${reflectionScope.name}'),
        initialTab: SocialModuleTab.feed,
        feedScope: reflectionScope,
        showTabs: false,
        showScopeChips: true,
      ),
      _CommunityView(scope: spaceScope),
      const _ProfileArea(),
    ];

    return Column(
      children: [
        PrimaryPanel(
          semanticLabel: 'Cabecalho da area autenticada',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;

              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderText(email: email),
                        const SizedBox(height: 20),
                        _HeaderActions(
                          notificationBell: const NotificationBellButton(),
                          onContinue: () => onNavigate(0),
                          onLogout: onLogout,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _HeaderText(email: email)),
                        const SizedBox(width: 20),
                        _HeaderActions(
                          notificationBell: const NotificationBellButton(),
                          onContinue: () => onNavigate(0),
                          onLogout: onLogout,
                        ),
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: SingleChildScrollView(
              key: ValueKey(selectedIndex),
              child: sections[selectedIndex],
            ),
          ),
        ),
      ],
    );
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
                        ? AppColors.surfaceStrong.withValues(alpha: 0.62)
                        : Colors.transparent,
                    border: Border.all(
                      color: entry.selected
                          ? AppColors.accent.withValues(alpha: 0.3)
                          : AppColors.outline.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    entry.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: entry.selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
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

class _CommunityView extends StatelessWidget {
  const _CommunityView({required this.scope});

  final SocialCommunityScope scope;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SocialModuleView(
          initialTab: SocialModuleTab.communities,
          showTabs: false,
          communityScope: scope,
          showScopeChips: true,
        ),
      ],
    );
  }
}

class _ProfileArea extends StatelessWidget {
  const _ProfileArea();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ProfileModuleView(),
        SizedBox(height: 16),
        SubscriptionModuleView(),
      ],
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Usuario logado',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.accent),
        ),
        const SizedBox(height: 10),
        Text(
          '$email conectado.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.notificationBell,
    required this.onContinue,
    required this.onLogout,
  });

  final Widget notificationBell;
  final VoidCallback onContinue;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        notificationBell,
        Tooltip(
          message: 'Voltar para a home principal',
          child: FilledButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.favorite_outline_rounded),
            label: const Text('Ir para home'),
          ),
        ),
        Tooltip(
          message: 'Encerrar sessao',
          child: OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair'),
          ),
        ),
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
                      : AppColors.outline.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
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
