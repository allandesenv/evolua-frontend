import 'package:evolua_frontend/app/router/auth_router_notifier.dart';
import 'package:evolua_frontend/features/app_update/application/app_update_route_state.dart';
import 'package:evolua_frontend/features/auth/application/authenticated_session_reset.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/presentation/pages/auth_page.dart';
import 'package:evolua_frontend/features/auth/presentation/pages/google_auth_callback_page.dart';
import 'package:evolua_frontend/features/auth/presentation/pages/reset_password_page.dart';
import 'package:evolua_frontend/features/care/presentation/pages/care_claim_page.dart';
import 'package:evolua_frontend/features/care/presentation/pages/care_share_page.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/daily_ritual/presentation/pages/daily_ritual_page.dart';
import 'package:evolua_frontend/features/emotional/presentation/pages/check_in_quick_page.dart';
import 'package:evolua_frontend/features/emotional/presentation/pages/consciousness_timeline_page.dart';
import 'package:evolua_frontend/features/future_message/presentation/pages/future_messages_page.dart';
import 'package:evolua_frontend/features/home/presentation/pages/home_page.dart';
import 'package:evolua_frontend/features/subscription/presentation/pages/billing_return_page.dart';
import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:evolua_frontend/shared/presentation/widgets/evolua_logo.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRouterNotifier = AuthRouterNotifier();
  ref.watch(authenticatedSessionResetObserverProvider);
  ref.listen(authControllerProvider, (previous, next) {
    final changed = authRouterNotifier.sync(next);
    if (changed) {
      authRouterNotifier.refresh();
    }
  }, fireImmediately: true);
  ref.onDispose(authRouterNotifier.dispose);

  return buildAppRouter(
    authRouterNotifier: authRouterNotifier,
    onRouteMatched: (route) =>
        ref.read(appUpdateCurrentRouteProvider.notifier).setRoute(route),
  );
});

GoRouter buildAppRouter({
  required AuthRouterNotifier authRouterNotifier,
  GoRouterWidgetBuilder? authPageBuilder,
  GoRouterWidgetBuilder? resetPasswordPageBuilder,
  GoRouterWidgetBuilder? googleCallbackPageBuilder,
  GoRouterWidgetBuilder? homePageBuilder,
  GoRouterWidgetBuilder? checkInPageBuilder,
  GoRouterWidgetBuilder? careClaimPageBuilder,
  GoRouterWidgetBuilder? dailyRitualPageBuilder,
  GoRouterWidgetBuilder? futureMessagesPageBuilder,
  GoRouterWidgetBuilder? futureMessageDetailPageBuilder,
  GoRouterWidgetBuilder? consciousnessTimelinePageBuilder,
  String initialLocation = '/',
  bool overridePlatformDefaultLocation = false,
  ValueChanged<String>? onRouteMatched,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: overridePlatformDefaultLocation,
    refreshListenable: authRouterNotifier,
    errorBuilder: (context, state) {
      if (authRouterNotifier.isBootstrapping ||
          authRouterNotifier.hasBootError) {
        return const _AuthBootPage();
      }
      return _RouteNotFoundPage(
        isAuthenticated: authRouterNotifier.isAuthenticated,
      );
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          if (_hasCareClaimHash()) {
            return const CareClaimPage();
          }
          return const _AuthBootPage();
        },
        redirect: (context, state) {
          if (_hasCareClaimHash()) {
            return null;
          }
          if (authRouterNotifier.isBootstrapping) {
            return null;
          }
          if (authRouterNotifier.hasBootError) {
            return null;
          }
          return authRouterNotifier.isAuthenticated ? '/home' : '/auth';
        },
      ),
      GoRoute(
        path: '/auth',
        builder: authPageBuilder ?? (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder:
            resetPasswordPageBuilder ??
            (context, state) =>
                ResetPasswordPage(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/auth/google/callback',
        builder:
            googleCallbackPageBuilder ??
            (context, state) => GoogleAuthCallbackPage(
              code: state.uri.queryParameters['code'],
              error: state.uri.queryParameters['error'],
            ),
      ),
      GoRoute(
        path: '/home',
        builder:
            homePageBuilder ??
            (context, state) => HomePage(
              profileSection: state.uri.queryParameters['profileSection'],
            ),
      ),
      GoRoute(
        path: '/billing/return',
        builder: (context, state) => BillingReturnPage(
          checkoutId: state.uri.queryParameters['billingCheckoutId'],
          billingReturn: state.uri.queryParameters['billingReturn'],
        ),
      ),
      GoRoute(
        path: '/check-in',
        builder:
            checkInPageBuilder ?? (context, state) => const CheckInQuickPage(),
      ),
      GoRoute(
        path: '/consciousness-timeline',
        builder:
            consciousnessTimelinePageBuilder ??
            (context, state) => const ConsciousnessTimelinePage(),
      ),
      GoRoute(
        path: '/care/share',
        builder: (context, state) => const CareSharePage(),
      ),
      GoRoute(
        path: '/care/claim',
        builder:
            careClaimPageBuilder ?? (context, state) => const CareClaimPage(),
      ),
      GoRoute(
        path: '/daily-ritual',
        builder:
            dailyRitualPageBuilder ??
            (context, state) => DailyRitualPage(
              type: DailyRitualType.fromRouteValue(
                state.uri.queryParameters['type'],
              ),
            ),
      ),
      GoRoute(
        path: '/future-messages',
        builder:
            futureMessagesPageBuilder ??
            (context, state) => const FutureMessagesPage(),
      ),
      GoRoute(
        path: '/future-messages/:id',
        builder:
            futureMessageDetailPageBuilder ??
            (context, state) => FutureMessagesPage(
              initialMessageId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
      ),
    ],
    redirect: (context, state) {
      onRouteMatched?.call(state.matchedLocation);
      if (authRouterNotifier.isBootstrapping) {
        if (state.matchedLocation == '/auth') {
          return '/';
        }
        return null;
      }
      if (authRouterNotifier.hasBootError) {
        if (state.matchedLocation == '/auth') {
          return '/';
        }
        return null;
      }

      final goingToAuth = state.matchedLocation == '/auth';
      final goingToResetPassword = state.matchedLocation == '/reset-password';
      final goingToGoogleCallback =
          state.matchedLocation == '/auth/google/callback';
      final goingToCareClaim = state.matchedLocation == '/care/claim';
      final goingToCareClaimHash =
          state.matchedLocation == '/' && _hasCareClaimHash();
      if (!authRouterNotifier.isAuthenticated &&
          !goingToAuth &&
          !goingToResetPassword &&
          !goingToGoogleCallback &&
          !goingToCareClaim &&
          !goingToCareClaimHash) {
        return '/auth';
      }

      if (authRouterNotifier.isAuthenticated && goingToAuth) {
        return '/home';
      }

      return null;
    },
  );
}

bool _hasCareClaimHash() {
  final fragment = Uri.base.fragment;
  return fragment == '/care/claim' || fragment.startsWith('/care/claim?');
}

class _AuthBootPage extends ConsumerWidget {
  const _AuthBootPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final hasBootError = authState.hasError && !authState.hasValue;

    return GradientScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EvoluaLogo(variant: EvoluaLogoVariant.sidebar),
              const SizedBox(height: 28),
              if (hasBootError) ...[
                Text(
                  context.l10n.routerBootErrorTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.routerBootErrorBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => ref.invalidate(authControllerProvider),
                  child: Text(context.l10n.commonRetry),
                ),
              ] else
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteNotFoundPage extends StatelessWidget {
  const _RouteNotFoundPage({required this.isAuthenticated});

  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EvoluaLogo(variant: EvoluaLogoVariant.sidebar),
              const SizedBox(height: 28),
              Text(
                context.l10n.routerNotFoundTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.routerNotFoundBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () =>
                    context.go(isAuthenticated ? '/home' : '/auth'),
                child: Text(context.l10n.routerBackToEvolua),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
