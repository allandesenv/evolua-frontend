import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const auditedFiles = [
    'lib/features/daily_ritual/presentation/pages/daily_ritual_page.dart',
    'lib/features/care/presentation/pages/care_share_page.dart',
    'lib/core/network/api_error_message.dart',
  ];

  test('textos críticos não têm mojibake em arquivos auditados', () {
    final forbiddenPatterns = <Pattern>['NÃ', 'vocÃ', 'possÃ', 'intenÃ', 'aÃ§'];

    for (final path in auditedFiles) {
      final content = File(path).readAsStringSync();
      for (final pattern in forbiddenPatterns) {
        expect(
          content.contains(pattern),
          isFalse,
          reason: '$path contém texto quebrado ou técnico: $pattern',
        );
      }
    }
  });
}
