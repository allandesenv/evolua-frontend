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
import 'package:evolua_frontend/features/subscription/presentation/widgets/subscription_module_view.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/presentation/widgets/profile_module_view.dart';
import 'package:evolua_frontend/shared/presentation/widgets/evolua_logo.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _selectedIndex = 0;

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
  Widget build(BuildContext context) {
    final isCompact = ResponsiveBreakpoints.isCompact(context);
    final pagePadding = ResponsiveBreakpoints.pagePadding(context);
    final session = ref.watch(authControllerProvider).asData?.value;

    final content = _DashboardContent(
      selectedIndex: _selectedIndex,
      email: session?.email ?? 'voce@evolua.app',
      onNavigate: _goTo,
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(pagePadding, 16, pagePadding, isCompact ? 10 : 24),
      child: isCompact
          ? Column(
              children: [
                Expanded(child: content),
                const SizedBox(height: 12),
                PrimaryPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  semanticLabel: 'Navegacao principal',
                  child: NavigationBar(
                    selectedIndex: _selectedIndex,
                    height: 72,
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
                                        final isSelected = index == _selectedIndex;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: Tooltip(
                                            message: item.label,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(18),
                                              onTap: () => _goTo(index),
                                              child: AnimatedContainer(
                                                duration:
                                                    const Duration(milliseconds: 180),
                                                curve: Curves.easeOutCubic,
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 14,
                                                ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  color: isSelected
                                                      ? AppColors.accent
                                                          .withValues(alpha: 0.18)
                                                      : Colors.transparent,
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? AppColors.accent.withValues(
                                                            alpha: 0.45,
                                                          )
                                                        : AppColors.outline.withValues(
                                                            alpha: 0.22,
                                                          ),
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
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.copyWith(
                                                              color: isSelected
                                                                  ? AppColors.textPrimary
                                                                  : AppColors
                                                                      .textSecondary,
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
    required this.onNavigate,
    required this.onLogout,
  });

  final int selectedIndex;
  final String email;
  final void Function(int index) onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profileControllerProvider).asData?.value ?? const [];
    final trailsCount = ref.watch(trailControllerProvider).asData?.value.totalItems ?? 0;
    final checkInsCount = ref.watch(checkInControllerProvider).asData?.value.result.totalItems ?? 0;
    final postsCount = ref.watch(socialPostControllerProvider).asData?.value.totalItems ?? 0;
    final communitiesCount = ref.watch(communityControllerProvider).asData?.value.totalItems ?? 0;

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
      const ContentModuleView(),
      const SocialModuleView(
        initialTab: SocialModuleTab.feed,
        showTabs: false,
      ),
      const _CommunityView(),
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

class _CommunityView extends StatelessWidget {
  const _CommunityView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SocialModuleView(
          initialTab: SocialModuleTab.communities,
          showTabs: false,
        ),
        SizedBox(height: 16),
        NotificationModuleView(),
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
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.accent,
              ),
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
    required this.onContinue,
    required this.onLogout,
  });

  final VoidCallback onContinue;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
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
  const _NavItem({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}
