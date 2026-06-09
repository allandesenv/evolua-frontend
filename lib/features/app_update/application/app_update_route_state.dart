import 'package:flutter_riverpod/flutter_riverpod.dart';

final appUpdateCurrentRouteProvider =
    NotifierProvider<AppUpdateCurrentRouteController, String>(
      AppUpdateCurrentRouteController.new,
    );

final appUpdateSensitiveFlowProvider =
    NotifierProvider<AppUpdateSensitiveFlowController, bool>(
      AppUpdateSensitiveFlowController.new,
    );

class AppUpdateCurrentRouteController extends Notifier<String> {
  @override
  String build() => '/';

  void setRoute(String route) {
    state = route;
  }
}

class AppUpdateSensitiveFlowController extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() {
    state = true;
  }

  void leave() {
    state = false;
  }
}
