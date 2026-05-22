import 'package:evolua_frontend/app/app.dart';
import 'package:evolua_frontend/features/notification/application/local_check_in_reminder_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCheckInReminderNotifications.initialize();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  runApp(const ProviderScope(child: EvoluaApp()));
}
