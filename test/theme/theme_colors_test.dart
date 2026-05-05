import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark theme semantic colors keep the closed palette', () {
    final colors = AppTheme.dark(
      accessibleFont: true,
    ).extension<EvoluaThemeColors>()!;

    expect(colors.background, AppColors.background);
    expect(colors.backgroundSecondary, AppColors.backgroundSecondary);
    expect(colors.surface, AppColors.surface);
    expect(colors.surfaceStrong, AppColors.surfaceStrong);
    expect(colors.outline, AppColors.outline);
    expect(colors.textPrimary, AppColors.textPrimary);
    expect(colors.textSecondary, AppColors.textSecondary);
  });

  testWidgets('PrimaryPanel uses light semantic surface in light mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(accessibleFont: true),
        home: const Scaffold(body: PrimaryPanel(child: Text('Painel claro'))),
      ),
    );

    final context = tester.element(find.text('Painel claro'));
    final colors = context.evoluaColors;
    final panel = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = panel.decoration! as BoxDecoration;

    expect(Theme.of(context).brightness, Brightness.light);
    expect(decoration.color, colors.surface.withValues(alpha: 0.94));
    expect(decoration.color, isNot(AppColors.surface.withValues(alpha: 0.94)));
  });

  testWidgets('GradientScaffold uses light background in light mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(accessibleFont: true),
        home: const GradientScaffold(child: Text('Fundo claro')),
      ),
    );

    final context = tester.element(find.text('Fundo claro'));
    final colors = context.evoluaColors;
    final containers = tester.widgetList<Container>(find.byType(Container));
    final decorated = containers.firstWhere(
      (container) => container.decoration is BoxDecoration,
    );
    final decoration = decorated.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;

    expect(Theme.of(context).brightness, Brightness.light);
    expect(gradient.colors.first, colors.background);
    expect(gradient.colors.first, isNot(AppColors.background));
  });
}
