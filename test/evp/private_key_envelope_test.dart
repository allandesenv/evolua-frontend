import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:evolua_frontend/core/private_core/private_key_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PrivateKeyEnvelopeService();
  const profile = 'synthetic-profile-a';
  const credential = 'synthetic test phrase only';
  const recovery = 'synthetic independent recovery phrase';
  const purpose = PrivateKeyPurpose.local;
  late SecretKeyData dek;
  late PrivateKeyEnvelope envelope;

  setUpAll(() async {
    dek = service.generateDek();
    envelope = await service.wrap(
        dek: dek, credential: credential, profileId: profile, purpose: purpose);
  });
  tearDownAll(() => dek.destroy());

  Future<SecretKeyData> open(PrivateKeyEnvelope value,
          {String password = credential,
          String id = profile,
          PrivateKeyPurpose use = purpose}) =>
      service.unwrap(
          envelope: value, credential: password, profileId: id, purpose: use);

  test('canonical serialized envelope round trip and explicit key disposal', () async {
    final decoded = PrivateKeyEnvelope.decode(envelope.encode());
    final clear = await open(decoded);
    try {
      expect(clear.bytes, orderedEquals(dek.bytes));
    } finally {
      clear.destroy();
    }
    expect(clear.isDestroyed, isTrue);
  });

  test('wrong credential, profile and purpose fail closed', () async {
    for (final attempt in [
      () => open(envelope, password: recovery),
      () => open(envelope, id: 'synthetic-profile-b'),
      () => open(envelope, use: PrivateKeyPurpose.recovery),
    ]) {
      await expectLater(attempt(), throwsA(isA<SecretBoxAuthenticationError>()));
    }
  });

  test('independent recovery envelope restores the same data key', () async {
    final portable = await service.wrap(
        dek: dek, credential: recovery, profileId: profile,
        purpose: PrivateKeyPurpose.recovery);
    final clear = await open(PrivateKeyEnvelope.decode(portable.encode()),
        password: recovery, use: PrivateKeyPurpose.recovery);
    try {
      expect(clear.bytes, orderedEquals(dek.bytes));
    } finally {
      clear.destroy();
    }
    expect(portable.encode(), isNot(envelope.encode()));
  });

  test('unknown version and excess KDF parameters rejected before derivation', () {
    final map = jsonDecode(envelope.encode()) as Map<String, dynamic>;
    for (final changed in [
      {...map, 'v': 2},
      {...map, 'v': 1.0},
      {...map, 'memory': 999999999},
      {...map, 'salt': 'x'},
      {...map, 'nonce': null},
      {...map, 'ciphertext': ''},
      {...map, 'tag': 1},
    ]) {
      expect(() => PrivateKeyEnvelope.decode(jsonEncode(changed)), throwsFormatException);
    }
  });

  test('oversized, malformed, duplicate and noncanonical input rejected', () {
    for (final invalid in [
      List.filled(513, 'x').join(),
      'not json',
      '[1,2]',
      'null',
      '{"v":1,' + envelope.encode().substring(1),
      ' ' + envelope.encode(),
    ]) {
      expect(() => PrivateKeyEnvelope.decode(invalid), throwsFormatException);
    }
  });

  test('valid-length ciphertext tampering fails authentication', () async {
    final map = jsonDecode(envelope.encode()) as Map<String, dynamic>;
    final bytes = base64Url.decode(map['ciphertext'] as String);
    bytes[0] ^= 1;
    map['ciphertext'] = base64UrlEncode(bytes);
    final altered = PrivateKeyEnvelope.decode(jsonEncode(map));
    await expectLater(open(altered), throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('invalid profile and excessive credential rejected', () async {
    await expectLater(open(envelope, id: 'invalid/profile'), throwsArgumentError);
    await expectLater(open(envelope, password: ''), throwsArgumentError);
    await expectLater(open(envelope, password: List.filled(1025, 'x').join()),
        throwsArgumentError);
  });

  test('rewrap preserves DEK and randomizes salt and nonce', () async {
    final changed = await service.wrap(
        dek: dek, credential: recovery, profileId: profile, purpose: purpose);
    final originalMap = jsonDecode(envelope.encode()) as Map<String, dynamic>;
    final changedMap = jsonDecode(changed.encode()) as Map<String, dynamic>;
    expect(changedMap['salt'], isNot(originalMap['salt']));
    expect(changedMap['nonce'], isNot(originalMap['nonce']));
    final clear = await open(changed, password: recovery);
    try {
      expect(clear.bytes, orderedEquals(dek.bytes));
    } finally {
      clear.destroy();
    }
    await expectLater(open(changed), throwsA(isA<SecretBoxAuthenticationError>()));
  });
}
