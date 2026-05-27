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
    final basePath = base.path.isEmpty
        ? '/'
        : base.path.endsWith('/')
        ? base.path
        : '${base.path}/';
    final claimFragment = Uri(
      path: '/care/claim',
      queryParameters: {'sid': shareId, 'code': numericCode, 'k': secretBase64},
    ).toString();
    return Uri(
      scheme: base.scheme,
      userInfo: base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: basePath,
      fragment: claimFragment,
    );
  }

  @override
  String toString() => toUri().toString();
}
