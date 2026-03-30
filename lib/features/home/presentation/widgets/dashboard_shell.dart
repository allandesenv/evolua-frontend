import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/chat/presentation/widgets/chat_module_view.dart';
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
    _NavItem(label: 'Comunidade', icon: Icons.groups_rounded),
    _NavItem(label: 'Chat', icon: Icons.chat_bubble_rounded),
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
          : Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 308),
                  child: PrimaryPanel(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    semanticLabel: 'Menu lateral',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EvoluaLogo(compact: true),
                        const SizedBox(height: 24),
                        Text(
                          'Clareza para agir, calma para continuar.',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Escolha um unico foco por vez e avance sem sobrecarga.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        NavigationRail(
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: _goTo,
                          minWidth: 240,
                          labelType: NavigationRailLabelType.all,
                          leading: const SizedBox.shrink(),
                          destinations: _destinations
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: Tooltip(
                                    message: item.label,
                                    child: Icon(item.icon),
                                  ),
                                  selectedIcon: Icon(item.icon),
                                  label: Text(item.label),
                                ),
                              )
                              .toList(),
                        ),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: AppColors.surfaceStrong.withValues(alpha: 0.7),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Acesso rapido',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Check-in rapido',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Uma acao pequena vale mais do que muitas opcoes abertas.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(child: content),
              ],
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
        onOpenCommunity: () => onNavigate(2),
        onOpenChat: () => onNavigate(3),
        onOpenProfile: () => onNavigate(4),
      ),
      const ContentModuleView(),
      const _CommunityView(),
      const ChatModuleView(),
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(selectedIndex),
            child: sections[selectedIndex],
          ),
        ),
        const SizedBox(height: 12),
        if (selectedIndex == 4) const _DevelopmentInfo(),
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
        SocialModuleView(),
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
          'Bom te ver por aqui',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.accent,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Um lugar simples para entender o que voce sente e seguir com consistencia.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'Sessao ativa para $email. Escolha um foco de cada vez: cuidar de voce, praticar, conversar ou acompanhar seu progresso.',
          style: Theme.of(context).textTheme.bodyLarge,
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
          message: 'Continuar sua jornada com menos friccao',
          child: FilledButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.favorite_outline_rounded),
            label: const Text('Seguir no meu ritmo'),
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

class _DevelopmentInfo extends StatelessWidget {
  const _DevelopmentInfo();

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ambiente de desenvolvimento',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Auth: ${AppConfig.authBaseUrl}\nUser: ${AppConfig.userBaseUrl}\nContent: ${AppConfig.contentBaseUrl}\nEmotional: ${AppConfig.emotionalBaseUrl}\nSocial: ${AppConfig.socialBaseUrl}\nChat: ${AppConfig.chatBaseUrl}\nSubscription: ${AppConfig.subscriptionBaseUrl}\nNotification: ${AppConfig.notificationBaseUrl}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
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
