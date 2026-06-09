import 'package:evolua_frontend/features/app_update/application/app_update_service.dart';

AppUpdateService createAppUpdateService() => const StubAppUpdateService();

class StubAppUpdateService implements AppUpdateService {
  const StubAppUpdateService();

  @override
  Future<bool> startFlexibleUpdate() async => false;

  @override
  Future<bool> performImmediateUpdate() async => false;

  @override
  Future<bool> openStore(String storeUrl) async => false;
}
