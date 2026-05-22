import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/home/presentation/widgets/dashboard_shell.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;
    final checkInState = ref.watch(checkInControllerProvider);
    final checkInHistory = checkInState.asData?.value;
    final hasStaleSessionState =
        session != null &&
        checkInHistory != null &&
        !checkInHistory.belongsToUser(session.userId);
    if ((checkInState.isLoading && !checkInState.hasValue) ||
        hasStaleSessionState) {
      return const GradientScaffold(child: _HomeGateLoading());
    }

    return const GradientScaffold(child: DashboardShell());
  }
}

class _HomeGateLoading extends StatelessWidget {
  const _HomeGateLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: HeroSkeleton(showActions: false)),
    );
  }
}
