import 'package:evolua_frontend/features/home/presentation/widgets/dashboard_shell.dart';
import 'package:evolua_frontend/features/user/presentation/widgets/profile_module_view.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.profileSection});

  final String? profileSection;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: DashboardShell(initialProfileSection: _profileSection),
    );
  }

  ProfileModuleSection? get _profileSection {
    return switch (profileSection) {
      'plans' => ProfileModuleSection.plansSubscriptions,
      'mirror' => ProfileModuleSection.evolutionMirror,
      _ => null,
    };
  }
}
