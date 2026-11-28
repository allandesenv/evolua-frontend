import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic feasibility only. No production persistence or authentication.
// Fixed candidate KDF profile, not a portable format or parser.
final _cipher = AesGcm.with256bits();
List<int> _random(int count) {
  final random = Random.secure();
  return List<int>.generate(count, (_) => random.nextInt(256));
}

List<int> _aad(String profile, String purpose) =>
    utf8.encode(jsonEncode(['evp-key-spike', 1, profile, purpose, 19456, 2, 1]));

Future<SecretKey> _derive(String password, List<int> salt) async {
  // Only send credential and salt to a worker, never to a remote service.
  final bytes = await Isolate.run(() async {
    final kdf = Argon2id(
      memory: 19456,
      iterations: 2,
      parallelism: 1,
      hashLength: 32,
    );
    final key = await kdf.deriveKeyFromPassword(password: password, nonce: salt);
    return key.extractBytes();
  });
  return SecretKey(bytes);
}

typedef _Envelope = ({List<int> salt, SecretBox box});

Future<_Envelope> _wrap(List<int> dek, String password, String profile,
    String purpose) async {
  final salt = _random(16);
  final key = await _derive(password, salt);
  final box = await _cipher.encrypt(dek,
      secretKey: key, nonce: _cipher.newNonce(), aad: _aad(profile, purpose));
  return (salt: salt, box: box);
}

Future<List<int>> _unwrap(_Envelope envelope, String password,
    String profile, String purpose) async {
  final key = await _derive(password, envelope.salt);
  return _cipher.decrypt(envelope.box,
      secretKey: key, aad: _aad(profile, purpose));
}

void main() {
  const profile = 'synthetic-profile-a';
  const password = 'synthetic local phrase, not a real password';
  const recovery = 'synthetic recovery phrase, not a real password';
  const newPassword = 'synthetic replacement phrase';
  late List<int> dek;
  late _Envelope local;
  late _Envelope portable;
  late _Envelope rotated;

  setUpAll(() async {
    dek = _random(32);
    local = await _wrap(dek, password, profile, 'local');
    portable = await _wrap(dek, recovery, profile, 'recovery');
    rotated = await _wrap(dek, newPassword, profile, 'local');
  });

  test('local credential unwraps independently generated 256-bit DEK', () async {
    expect(dek.length, 32);
    expect(await _unwrap(local, password, profile, 'local'), orderedEquals(dek));
    expect(_random(32), isNot(orderedEquals(dek)));
  });

  test('independent recovery credential unwraps the same DEK', () async {
    expect(await _unwrap(portable, recovery, profile, 'recovery'), orderedEquals(dek));
    expect(portable.salt, isNot(orderedEquals(local.salt)));
    expect(portable.box.nonce, isNot(orderedEquals(local.box.nonce)));
  });

  test('wrong local credential fails authentication', () async {
    await expectLater(_unwrap(local, recovery, profile, 'local'),
        throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('wrong profile fails authentication', () async {
    await expectLater(_unwrap(local, password, 'synthetic-profile-b', 'local'),
        throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('wrong purpose fails authentication', () async {
    await expectLater(_unwrap(portable, recovery, profile, 'local'),
        throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('modified envelope salt or authentication tag fails', () async {
    final salt = List<int>.of(local.salt);
    salt[0] ^= 1;
    await expectLater(_unwrap((salt: salt, box: local.box), password, profile, 'local'),
        throwsA(isA<SecretBoxAuthenticationError>()));
    final tag = List<int>.of(local.box.mac.bytes);
    tag[0] ^= 1;
    final modified = SecretBox(local.box.cipherText, nonce: local.box.nonce, mac: Mac(tag));
    await expectLater(_unwrap((salt: local.salt, box: modified), password, profile, 'local'),
        throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('credential change rewraps same DEK; old credential cannot open new envelope', () async {
    expect(await _unwrap(rotated, newPassword, profile, 'local'), orderedEquals(dek));
    await expectLater(_unwrap(rotated, password, profile, 'local'),
        throwsA(isA<SecretBoxAuthenticationError>()));
    expect(rotated.salt, isNot(orderedEquals(local.salt)));
    // Old exported envelopes remain valid; rewrap does not revoke copies.
  });

  test('Google identifiers are not necessary to recover the key', () async {
    expect(await _unwrap(portable, recovery, profile, 'recovery'), orderedEquals(dek));
  });
}
