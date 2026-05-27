import 'package:web/web.dart' as web;

String readStoredCareClaimSecret(String shareId) {
  return web.window.sessionStorage.getItem(
        'evolua.care.claim.secret.$shareId',
      ) ??
      '';
}
