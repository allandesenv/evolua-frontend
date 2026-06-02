import 'dart:async';

import 'package:flutter/foundation.dart';

class StartupDiagnostics {
  StartupDiagnostics._();

  static final Stopwatch _watch = Stopwatch()..start();
  static final Set<String> _marks = <String>{};

  static void mark(String name, {bool once = true}) {
    if (!kDebugMode) {
      return;
    }
    if (once && !_marks.add(name)) {
      return;
    }
    debugPrint('[startup] ${_watch.elapsedMilliseconds}ms $name');
  }

  static Future<T> measure<T>(
    String name,
    Future<T> Function() operation,
  ) async {
    if (!kDebugMode) {
      return operation();
    }
    final step = Stopwatch()..start();
    try {
      final result = await operation();
      debugPrint(
        '[startup] ${_watch.elapsedMilliseconds}ms $name ok '
        '(${step.elapsedMilliseconds}ms)',
      );
      return result;
    } catch (error) {
      debugPrint(
        '[startup] ${_watch.elapsedMilliseconds}ms $name failed '
        '(${step.elapsedMilliseconds}ms, ${error.runtimeType})',
      );
      rethrow;
    }
  }
}
