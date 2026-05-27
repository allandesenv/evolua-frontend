import 'dart:async';

import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations.dart';
import 'package:evolua_frontend/shared/presentation/widgets/evolua_async_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget testApp(Widget child, {Locale locale = const Locale('pt', 'BR')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets(
    'EvoluaAsyncButton dispara a ação apenas uma vez enquanto carrega',
    (tester) async {
      final completer = Completer<void>();
      var calls = 0;

      await tester.pumpWidget(
        testApp(
          EvoluaAsyncButton.filled(
            label: 'Salvar',
            onPressed: () {
              calls++;
              return completer.future;
            },
          ),
        ),
      );

      await tester.tap(find.text('Salvar'));
      await tester.tap(find.text('Salvar'));
      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pump();
      expect(calls, 2);
    },
  );

  testWidgets('EvoluaAsyncButton usa texto de carregamento localizado', (
    tester,
  ) async {
    final completer = Completer<void>();

    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => EvoluaAsyncButton.filled(
            label: context.l10n.commonSave,
            onPressed: () => completer.future,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Salvar'));
    await tester.pump();

    expect(find.text('Carregando...'), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('texto localizado muda ao trocar o locale sem reiniciar fluxo', (
    tester,
  ) async {
    Widget localizedLabel(Locale locale) {
      return testApp(
        Builder(builder: (context) => Text(context.l10n.commonSave)),
        locale: locale,
      );
    }

    await tester.pumpWidget(localizedLabel(const Locale('pt', 'BR')));
    expect(find.text('Salvar'), findsOneWidget);

    await tester.pumpWidget(localizedLabel(const Locale('en', 'US')));
    await tester.pump();
    expect(find.text('Save'), findsOneWidget);
  });
}
