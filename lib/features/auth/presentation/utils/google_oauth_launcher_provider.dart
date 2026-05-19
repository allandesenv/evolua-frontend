import 'package:evolua_frontend/features/auth/presentation/utils/google_oauth_redirect.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef GoogleOAuthLauncher = Future<void> Function(String url);

final googleOAuthLauncherProvider = Provider<GoogleOAuthLauncher>((ref) {
  return openGoogleOAuthRedirect;
});
