import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

// Feasibility spike only. No persistence, production key lifecycle or
// network. The synthetic values and context are deliberately not real data.
void main() {
  final cipher = AesGcm.with256bits();
  final plaintext = utf8.encode('synthetic check-in');
  List<int> context(String profile, String record, int version) =>
      utf8.encode(jsonEncode(['evp-spike', profile, record, version]));

  late SecretKey key;
  late List<int> aad;

  setUp(() async {
    key = await cipher.newSecretKey();
    aad = context('synthetic-profile-a', 'record-1', 1);
  });

  Future<SecretBox> seal() => cipher.encrypt(
        plaintext,
        secretKey: key,
        nonce: cipher.newNonce(),
        aad: aad,
      );

  Future<List<int>> open(SecretBox box, {SecretKey? withKey, List<int>? withAad}) =>
      cipher.decrypt(box, secretKey: withKey ?? key, aad: withAad ?? aad);

  test('authenticated round trip', () async {
    expect(await open(await seal()), orderedEquals(plaintext));
  });

  test('fresh nonce for each write (sample, not a randomness proof)', () async {
    final first = await seal();
    final second = await seal();
    expect(first.nonce, isNot(orderedEquals(second.nonce)));
    expect(await open(second), orderedEquals(plaintext));
  });

  test('different key rejects ciphertext', () async {
    final box = await seal();
    final otherKey = await cipher.newSecretKey();
    await expectLater(open(box, withKey: otherKey),
        throwsA(isA<SecretBoxAuthenticationError>()));
  });

  for (final changed in [
    ['synthetic-profile-b', 'record-1', 1],
    ['synthetic-profile-a', 'record-2', 1],
    ['synthetic-profile-a', 'record-1', 2],
  ]) {
    test('rejects changed authenticated context: $changed', () async {
      final box = await seal();
      final changedAad = context(changed[0] as String, changed[1] as String,
          changed[2] as int);
      await expectLater(open(box, withAad: changedAad),
          throwsA(isA<SecretBoxAuthenticationError>()));
    });
  }

  test('rejects modified ciphertext', () async {
    final box = await seal();
    final bytes = List<int>.of(box.cipherText);
    bytes[0] ^= 1;
    final tampered = SecretBox(bytes, nonce: box.nonce, mac: box.mac);
    await expectLater(open(tampered),
        throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('rejects modified authentication tag', () async {
    final box = await seal();
    final bytes = List<int>.of(box.mac.bytes);
    bytes[0] ^= 1;
    final tampered =
        SecretBox(box.cipherText, nonce: box.nonce, mac: Mac(bytes));
    await expectLater(open(tampered),
        throwsA(isA<SecretBoxAuthenticationError>()));
  });
}
