import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Candidate internal key-envelope format. Not yet a persisted app contract,
/// device binding, backup format, or authentication policy.
enum PrivateKeyPurpose { local, recovery }

final class PrivateKeyEnvelope {
  PrivateKeyEnvelope._(this._salt, this._nonce, this._ciphertext, this._tag);

  static const int version = 1;
  static const int memoryKiB = 19456;
  static const int iterations = 2;
  static const int lanes = 1;
  static const int maxEncodedLength = 512;
  final String _salt;
  final String _nonce;
  final String _ciphertext;
  final String _tag;

  String encode() => jsonEncode({
        'v': version,
        'salt': _salt,
        'nonce': _nonce,
        'ciphertext': _ciphertext,
        'tag': _tag,
      });

  /// Accept only the exact canonical v1 representation. Reject malformed
  /// or unknown versions before scheduling expensive KDF work.
  factory PrivateKeyEnvelope.decode(String encoded) {
    if (encoded.length > maxEncodedLength) {
      throw const FormatException('Invalid private key envelope');
    }
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic> ||
          value.length != 5 ||
          value['v'] is! int ||
          value['v'] != version) {
        throw const FormatException('Invalid private key envelope');
      }
      final envelope = PrivateKeyEnvelope._(
        _validatedField(value['salt'], 16),
        _validatedField(value['nonce'], 12),
        _validatedField(value['ciphertext'], 32),
        _validatedField(value['tag'], 16),
      );
      if (envelope.encode() != encoded) {
        throw const FormatException('Invalid private key envelope');
      }
      return envelope;
    } on FormatException {
      // Never expose the original input in a parse error.
      throw const FormatException('Invalid private key envelope');
    }
  }

  static String _validatedField(Object? value, int length) {
    if (value is! String) {
      throw const FormatException('Invalid private key envelope');
    }
    final bytes = base64Url.decode(value);
    if (bytes.length != length || base64UrlEncode(bytes) != value) {
      throw const FormatException('Invalid private key envelope');
    }
    return value;
  }
}

final class PrivateKeyEnvelopeService {
  const PrivateKeyEnvelopeService();

  static final _cipher = AesGcm.with256bits();

  /// Caller owns and must destroy the returned in-memory key when done.
  SecretKeyData generateDek() {
    _requireSupported();
    return SecretKeyData.random(length: 32);
  }

  Future<PrivateKeyEnvelope> wrap({
    required SecretKeyData dek,
    required String credential,
    required String profileId,
    required PrivateKeyPurpose purpose,
  }) async {
    _requireSupported();
    final aad = _context(profileId, purpose, credential);
    if (dek.bytes.length != 32) {
      throw ArgumentError('Invalid private data key length');
    }
    final salt = _random(16);
    final key = await _derive(credential, salt);
    try {
      final box = await _cipher.encrypt(dek.bytes,
          secretKey: key, nonce: _cipher.newNonce(), aad: aad);
      return PrivateKeyEnvelope._(
        base64UrlEncode(salt),
        base64UrlEncode(box.nonce),
        base64UrlEncode(box.cipherText),
        base64UrlEncode(box.mac.bytes),
      );
    } finally {
      key.destroy();
    }
  }

  /// Caller owns and must destroy the returned key. An authentication
  /// failure does not create a new key or fall back to another context.
  Future<SecretKeyData> unwrap({
    required PrivateKeyEnvelope envelope,
    required String credential,
    required String profileId,
    required PrivateKeyPurpose purpose,
  }) async {
    _requireSupported();
    final aad = _context(profileId, purpose, credential);
    final key = await _derive(credential, base64Url.decode(envelope._salt));
    try {
      final bytes = await _cipher.decrypt(
        SecretBox(base64Url.decode(envelope._ciphertext),
            nonce: base64Url.decode(envelope._nonce),
            mac: Mac(base64Url.decode(envelope._tag))),
        secretKey: key,
        aad: aad,
      );
      return SecretKeyData(bytes, overwriteWhenDestroyed: true);
    } finally {
      key.destroy();
    }
  }

  static void _requireSupported() {
    // Native worker implementation only. Never silently run on Web or
    // substitute weaker encryption. Web policy will be decided separately.
    if (kIsWeb) throw UnsupportedError('Private key worker unavailable');
  }

  static List<int> _context(
      String profileId, PrivateKeyPurpose purpose, String credential) {
    if (profileId.isEmpty ||
        profileId.length > 128 ||
        RegExp(r'[A-Za-z0-9_-]+').stringMatch(profileId) != profileId) {
      throw ArgumentError('Invalid local profile identifier');
    }
    // This is an input resource bound, not a password strength policy.
    if (credential.isEmpty ||
        credential.length > 1024 ||
        utf8.encode(credential).length > 1024) {
      throw ArgumentError('Invalid credential length');
    }
    return utf8.encode(jsonEncode([
      'evolua-private-key-envelope',
      PrivateKeyEnvelope.version,
      profileId,
      purpose.name,
      PrivateKeyEnvelope.memoryKiB,
      PrivateKeyEnvelope.iterations,
      PrivateKeyEnvelope.lanes,
    ]));
  }

  static List<int> _random(int count) {
    final random = Random.secure();
    return List<int>.generate(count, (_) => random.nextInt(256));
  }

  static Future<SecretKeyData> _derive(
      String credential, List<int> salt) async {
    final bytes = await Isolate.run(() async {
      final kdf = Argon2id(
        memory: PrivateKeyEnvelope.memoryKiB,
        iterations: PrivateKeyEnvelope.iterations,
        parallelism: PrivateKeyEnvelope.lanes,
        hashLength: 32,
      );
      final key = await kdf.deriveKeyFromPassword(
          password: credential, nonce: salt);
      try {
        return List<int>.of(await key.extractBytes());
      } finally {
        if (key is SecretKeyData) key.destroy();
      }
    });
    return SecretKeyData(bytes, overwriteWhenDestroyed: true);
  }
}
