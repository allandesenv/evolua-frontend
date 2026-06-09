import 'dart:io' show Platform;

String currentAppUpdatePlatform() {
  if (Platform.isAndroid) {
    return 'android';
  }
  if (Platform.isIOS) {
    return 'ios';
  }
  return 'web';
}
