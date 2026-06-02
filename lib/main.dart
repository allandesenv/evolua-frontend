import 'package:evolua_frontend/app/app.dart';
import 'package:evolua_frontend/app/startup/startup_diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupDiagnostics.mark('binding initialized');
  if (kIsWeb) {
    usePathUrlStrategy();
    StartupDiagnostics.mark('path url strategy configured');
  }
  StartupDiagnostics.mark('runApp');
  runApp(const ProviderScope(child: EvoluaApp()));
}
