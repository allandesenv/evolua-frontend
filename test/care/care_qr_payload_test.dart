import 'package:evolua_frontend/features/care/application/care_claim_controller.dart';
import 'package:evolua_frontend/features/care/application/care_qr_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates GitHub Pages hash bootstrap link with secret', () {
    const payload = CareQrPayload(
      shareId: 'share-1',
      numericCode: '123456',
      secretBase64: 'secret=',
    );

    final url = payload.toString();

    expect(url, contains('/evolua-frontend/#/care/claim'));
    expect(url, contains('sid=share-1'));
    expect(url, contains('code=123456'));
    expect(url, contains('k=secret'));
    expect(url, isNot(contains('/evolua-care')));
  });

  test('parses current and legacy care claim links', () {
    final current = CareClaimLink.fromUri(
      Uri.parse(
        'https://allandesenv.github.io/evolua-frontend/#/care/claim?sid=share-1&code=123456&k=secret%3D',
      ),
    );
    expect(current.shareId, 'share-1');
    expect(current.code, '123456');
    expect(current.secretBase64, 'secret=');
    expect(current.isComplete, isTrue);

    final legacy = CareClaimLink.fromUri(
      Uri.parse(
        'https://allandesenv.github.io/evolua-frontend/care/claim?sid=share-2&code=654321#k=legacy%3D',
      ),
    );
    expect(legacy.shareId, 'share-2');
    expect(legacy.code, '654321');
    expect(legacy.secretBase64, 'legacy=');
    expect(legacy.isComplete, isTrue);

    final normalized = CareClaimLink.fromUri(
      Uri.parse(
        'https://allandesenv.github.io/evolua-frontend/care/claim?sid=share-3&code=111222',
      ),
      storedSecretReader: (shareId) => shareId == 'share-3' ? 'stored=' : '',
    );
    expect(normalized.shareId, 'share-3');
    expect(normalized.code, '111222');
    expect(normalized.secretBase64, 'stored=');
    expect(normalized.isComplete, isTrue);
  });
}
