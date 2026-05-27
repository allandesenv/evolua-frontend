import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_encrypted_payload.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final careCryptoServiceProvider = Provider<CareCryptoService>((ref) {
  return CareCryptoService();
});

enum CareCryptoPayloadPurpose { clinicalReport, customRitual }

class CareCryptoService {
  CareCryptoService({AesGcm? cipher, Hkdf? hkdf})
    : _cipher = cipher ?? AesGcm.with256bits(),
      _hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  final AesGcm _cipher;
  final Hkdf _hkdf;

  Future<SecretKey> deriveSessionKey({
    required List<int> shareSecret,
    required String shareId,
    required String purpose,
  }) {
    return _hkdf.deriveKey(
      secretKey: SecretKey(shareSecret),
      nonce: utf8.encode('evolua-care:$shareId'),
      info: utf8.encode(purpose),
    );
  }

  Future<CareEncryptedPayload> encryptJson({
    required SecretKey key,
    required String shareId,
    required Map<String, dynamic> json,
    CareCryptoPayloadPurpose purpose = CareCryptoPayloadPurpose.clinicalReport,
  }) async {
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(json)),
      secretKey: key,
      nonce: nonce,
      aad: utf8.encode(_aad(shareId, purpose)),
    );

    return CareEncryptedPayload(
      algorithm: 'AES-256-GCM',
      nonceBase64: base64UrlEncode(nonce),
      cipherTextBase64: base64UrlEncode(box.cipherText),
      macBase64: base64UrlEncode(box.mac.bytes),
    );
  }

  Future<Map<String, dynamic>> decryptJson({
    required SecretKey key,
    required String shareId,
    required CareEncryptedPayload payload,
    CareCryptoPayloadPurpose purpose = CareCryptoPayloadPurpose.clinicalReport,
  }) async {
    final box = SecretBox(
      base64Url.decode(payload.cipherTextBase64),
      nonce: base64Url.decode(payload.nonceBase64),
      mac: Mac(base64Url.decode(payload.macBase64)),
    );
    final bytes = await _cipher.decrypt(
      box,
      secretKey: key,
      aad: utf8.encode(_aad(shareId, purpose)),
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Payload clínico inválido.');
    }
    return decoded;
  }

  String _aad(String shareId, CareCryptoPayloadPurpose purpose) {
    return switch (purpose) {
      CareCryptoPayloadPurpose.clinicalReport =>
        'evolua-care-report:$shareId:v1',
      CareCryptoPayloadPurpose.customRitual =>
        'evolua-care-prescription:$shareId:v1',
    };
  }
}
