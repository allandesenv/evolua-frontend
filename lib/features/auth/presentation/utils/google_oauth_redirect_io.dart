import 'package:url_launcher/url_launcher.dart';

Future<void> openGoogleOAuthRedirect(String url) async {
  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!opened) {
    throw StateError('Could not open Google OAuth URL.');
  }
}
