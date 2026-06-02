import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GitHub Pages bootstrap keeps Flutter base placeholder for web builds',
    () {
      final index = File('web/index.html').readAsStringSync();

      expect(index, contains(r'<base href="$FLUTTER_BASE_HREF">'));
      expect(index, contains('background-color: #0B1220'));
      expect(index, contains('flutter-view'));
      expect(index, contains('overscroll-behavior: none'));
      expect(index, contains('normalizeCareHashRoute'));
      expect(index, contains('/evolua-frontend/care/claim?sid='));
    },
  );

  test('GitHub Pages 404 redirect also uses Evolua background', () {
    final page404 = File('web/404.html').readAsStringSync();

    expect(page404, contains('background-color: #0B1220'));
    expect(page404, contains("sessionStorage.setItem('evolua.github_pages.redirect'"));
  });
}
