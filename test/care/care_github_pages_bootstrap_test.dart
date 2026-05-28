import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GitHub Pages bootstrap keeps Flutter base placeholder for web builds',
    () {
      final index = File('web/index.html').readAsStringSync();

      expect(index, contains(r'<base href="$FLUTTER_BASE_HREF">'));
      expect(index, contains('normalizeCareHashRoute'));
      expect(index, contains('/evolua-frontend/care/claim?sid='));
    },
  );
}
