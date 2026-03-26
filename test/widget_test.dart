import 'package:evolua_frontend/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('renders Evolua auth shell', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EvoluaApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Evolua'), findsWidgets);
    expect(find.textContaining('Seu espaco seguro'), findsOneWidget);
  });
}
