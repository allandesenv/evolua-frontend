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

  test('interactive controls keep accessible tap targets', () {
    final theme = AppTheme.dark(accessibleFont: true);
    final states = const <WidgetState>{};

    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve(states),
      const Size(48, 48),
    );
    expect(
      theme.outlinedButtonTheme.style?.minimumSize?.resolve(states),
      const Size(48, 48),
    );
    expect(
      theme.textButtonTheme.style?.minimumSize?.resolve(states),
      const Size(48, 48),
    );
    expect(
      theme.elevatedButtonTheme.style?.minimumSize?.resolve(states),
      const Size(48, 52),
    );
    expect(
      theme.iconButtonTheme.style?.minimumSize?.resolve(states),
      const Size.square(48),
    );
    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
  });

  test('dark theme semantic text colors pass AA contrast on surfaces', () {
    final colors = AppTheme.dark(
      accessibleFont: true,
    ).extension<EvoluaThemeColors>()!;

    expect(
      _contrastRatio(colors.textPrimary, colors.background),
      greaterThan(4.5),
    );
    expect(
      _contrastRatio(colors.textPrimary, colors.surface),
      greaterThan(4.5),
    );
    expect(
      _contrastRatio(colors.textSecondary, colors.background),
      greaterThan(4.5),
    );
    expect(
      _contrastRatio(colors.textSecondary, colors.surface),
      greaterThan(4.5),
    );
    expect(_contrastRatio(colors.accent, colors.background), greaterThan(4.5));
    expect(
      _contrastRatio(colors.accentWarm, colors.background),
      greaterThan(4.5),
    );
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
    final decoratedBoxes = tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    );

    final decoration = decoratedBoxes
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere(
          (decoration) => decoration.gradient is LinearGradient,
        );

    final gradient = decoration.gradient! as LinearGradient;

    expect(Theme.of(context).brightness, Brightness.light);
    expect(gradient.colors.first, colors.background);
    expect(gradient.colors.first, isNot(AppColors.background));
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
