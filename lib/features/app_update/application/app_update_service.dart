import 'package:evolua_frontend/features/app_update/application/app_update_service_stub.dart'
    if (dart.library.io) 'package:evolua_frontend/features/app_update/application/app_update_service_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return createAppUpdateService();
});

abstract class AppUpdateService {
  Future<bool> startFlexibleUpdate();

  Future<bool> performImmediateUpdate();

  Future<bool> openStore(String storeUrl);
}
