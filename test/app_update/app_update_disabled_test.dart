import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/features/app_update/application/app_version_status_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'EVOLUA_APP_UPDATE_CHECK_ENABLED=false disables version check',
    () async {
      if (AppConfig.appUpdateCheckEnabled) {
        return;
      }

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await container.read(appVersionStatusProvider.future);

      expect(state.disabled, isTrue);
      expect(state.status.updateRequired, isFalse);
    },
  );
}
