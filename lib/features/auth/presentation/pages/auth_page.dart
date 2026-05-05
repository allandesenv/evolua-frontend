import 'package:evolua_frontend/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:evolua_frontend/features/auth/presentation/widgets/auth_hero.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:flutter/material.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return GradientScaffold(
      resizeToAvoidBottomInset: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;
          final horizontalPadding = isCompact ? 20.0 : 32.0;
          final verticalPadding = isCompact ? 16.0 : 24.0;
          final bottomPadding = verticalPadding + viewInsets.bottom;
          final minContentHeight =
              constraints.maxHeight - verticalPadding - bottomPadding;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              verticalPadding,
              horizontalPadding,
              bottomPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minContentHeight > 0 ? minContentHeight : 0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: isCompact
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AuthHero(),
                              const SizedBox(height: 16),
                              const AuthFormCard(),
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              flex: 6,
                              child: Padding(
                                padding: EdgeInsets.only(right: 32),
                                child: AuthHero(),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 540,
                                  ),
                                  child: const AuthFormCard(),
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
    );
  }
}
