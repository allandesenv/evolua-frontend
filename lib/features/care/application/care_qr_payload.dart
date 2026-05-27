import 'package:evolua_frontend/core/config/app_config.dart';

class CareQrPayload {
  const CareQrPayload({
    required this.shareId,
    required this.numericCode,
    required this.secretBase64,
  });

  final String shareId;
  final String numericCode;
  final String secretBase64;

  Uri toUri() {
    final base = Uri.parse(AppConfig.carePortalBaseUrl);
    final path = base.path.endsWith('/')
        ? '${base.path}claim'
        : '${base.path}/claim';
    return base.replace(
      path: path,
      queryParameters: {'sid': shareId, 'code': numericCode},
      fragment: 'k=$secretBase64',
    );
  }

  @override
  String toString() => toUri().toString();
}
