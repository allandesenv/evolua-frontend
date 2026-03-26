import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:evolua_frontend/features/auth/presentation/widgets/auth_hero.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:flutter/material.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveBreakpoints.isCompact(context);

    return GradientScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 20 : 32,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: isCompact
                ? const Column(
                    children: [
                      AuthHero(),
                      SizedBox(height: 24),
                      AuthFormCard(),
                    ],
                  )
                : const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: EdgeInsets.only(right: 24),
                          child: AuthHero(),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: AuthFormCard(),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
