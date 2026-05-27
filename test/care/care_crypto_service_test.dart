import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:evolua_frontend/features/care/application/care_crypto_service.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CareCryptoService', () {
    test(
      'encrypts and decrypts clinical payload without plaintext leakage',
      () async {
        final service = CareCryptoService();
        final secret = List<int>.generate(32, (index) => index + 1);
        final key = await service.deriveSessionKey(
          shareSecret: secret,
          shareId: 'share-1',
          purpose: 'clinical-report-v1',
        );
        final payload = {
          'mood': 'ansiedade',
          'trigger': 'trabalho',
          'reflection': 'preciso descansar',
        };

        final encrypted = await service.encryptJson(
          key: key,
          shareId: 'share-1',
          json: payload,
        );
        final rawCipherText = utf8.decode(
          base64Url.decode(encrypted.cipherTextBase64),
          allowMalformed: true,
        );

        expect(rawCipherText, isNot(contains('ansiedade')));
        expect(rawCipherText, isNot(contains('trabalho')));

        final decrypted = await service.decryptJson(
          key: key,
          shareId: 'share-1',
          payload: encrypted,
        );

        expect(decrypted['mood'], 'ansiedade');
        expect(decrypted['trigger'], 'trabalho');
      },
    );

    test('rejects corrupted keys and tampered payloads', () async {
      final service = CareCryptoService();
      final key = await service.deriveSessionKey(
        shareSecret: List<int>.filled(32, 7),
        shareId: 'share-1',
        purpose: 'clinical-report-v1',
      );
      final wrongKey = await service.deriveSessionKey(
        shareSecret: List<int>.filled(32, 8),
        shareId: 'share-1',
        purpose: 'clinical-report-v1',
      );
      final encrypted = await service.encryptJson(
        key: key,
        shareId: 'share-1',
        json: {'mood': 'calma'},
      );

      expect(
        () => service.decryptJson(
          key: wrongKey,
          shareId: 'share-1',
          payload: encrypted,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      final tampered = CareEncryptedPayload(
        algorithm: encrypted.algorithm,
        nonceBase64: encrypted.nonceBase64,
        cipherTextBase64: encrypted.cipherTextBase64,
        macBase64: base64UrlEncode(List<int>.filled(16, 1)),
      );

      expect(
        () => service.decryptJson(
          key: key,
          shareId: 'share-1',
          payload: tampered,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test(
      'encrypts and decrypts attachment bytes with separate purpose',
      () async {
        final service = CareCryptoService();
        final secret = List<int>.generate(32, (index) => index + 3);
        final key = await service.deriveSessionKey(
          shareSecret: secret,
          shareId: 'share-1',
          purpose: 'care-attachment-v1',
        );
        final bytes = utf8.encode('conteudo sensivel do anexo');

        final encrypted = await service.encryptBytes(
          key: key,
          shareId: 'share-1',
          bytes: bytes,
          purpose: CareCryptoPayloadPurpose.attachment,
        );

        expect(
          utf8.decode(
            base64Url.decode(encrypted.cipherTextBase64),
            allowMalformed: true,
          ),
          isNot(contains('conteudo sensivel')),
        );

        final decrypted = await service.decryptBytes(
          key: key,
          shareId: 'share-1',
          payload: encrypted,
          purpose: CareCryptoPayloadPurpose.attachment,
        );

        expect(decrypted, bytes);
      },
    );
  });
}
