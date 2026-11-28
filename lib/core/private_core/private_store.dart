import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Internal Android-only candidate. Disabled by default and not an auth API.
final class PrivateStore {
  const PrivateStore({this.enabled = false, MethodChannel channel =
      const MethodChannel('evolua/private_store_v1')}) : _channel = channel;

  final bool enabled;
  final MethodChannel _channel;

  Future<PrivateStoreSession> create(String profile, SecretKeyData dek) =>
      _start('create', profile, dek);

  Future<PrivateStoreSession> open(String profile, SecretKeyData dek) =>
      _start('open', profile, dek);

  Future<PrivateStoreSession> _start(
      String method, String profile, SecretKeyData dek) async {
    if (!enabled || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Private storage unavailable');
    }
    if (!_validId(profile) || dek.isDestroyed || dek.bytes.length != 32) {
      throw ArgumentError('Invalid private storage input');
    }
    final bytes = Uint8List.fromList(dek.bytes);
    try {
      final handle = await _channel.invokeMethod<String>(method, {
        'profile': profile,
        'key': bytes,
      });
      if (handle == null || handle.isEmpty) {
        throw StateError('Private storage session unavailable');
      }
      return PrivateStoreSession._(_channel, handle);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }
}

bool _validId(String id) =>
    id.length <= 128 && RegExp(r'[A-Za-z0-9_-]+').stringMatch(id) == id &&
    id.isNotEmpty;

final class PrivateRecord {
  PrivateRecord({required this.id, required this.createdAt, required this.body}) {
    if (!_validId(id) || createdAt < 0 || body.isEmpty || body.length > 16384) {
      throw ArgumentError('Invalid private record');
    }
  }

  final String id;
  final int createdAt;
  final String body;

  Map<String, Object> _encode() =>
      {'id': id, 'createdAt': createdAt, 'body': body};

  factory PrivateRecord._decode(Map<Object?, Object?> value) => PrivateRecord(
        id: value['id'] as String,
        createdAt: value['createdAt'] as int,
        body: value['body'] as String,
      );
}

/// A native session owns one profile. No local fallback or implicit reopen.
final class PrivateStoreSession {
  PrivateStoreSession._(this._channel, this._handle);
  final MethodChannel _channel;
  final String _handle;
  bool _closed = false;

  void _requireOpen() {
    if (_closed) throw StateError('Private storage session closed');
  }

  Future<void> insertBatch(List<PrivateRecord> records) async {
    _requireOpen();
    if (records.isEmpty || records.length > 100) {
      throw ArgumentError('Invalid batch size');
    }
    final count = await _channel.invokeMethod<int>('insertBatch', {
      'session': _handle,
      'records': records.map((record) => record._encode()).toList(),
    });
    _requireOpen();
    if (count != records.length) throw StateError('Private storage write incomplete');
  }

  Future<List<PrivateRecord>> page({int limit = 30, PrivateRecord? before}) async {
    _requireOpen();
    if (limit < 1 || limit > 100) throw ArgumentError('Invalid page size');
    final rows = await _channel.invokeListMethod<Object?>('page', {
      'session': _handle,
      'limit': limit,
      'beforeTime': before?.createdAt,
      'beforeId': before?.id,
    });
    _requireOpen();
    if (rows == null) throw StateError('Private storage response unavailable');
    return List.unmodifiable(rows.map((row) =>
        PrivateRecord._decode(row as Map<Object?, Object?>)));
  }

  Future<void> close() async {
    if (_closed) return;
    // Invalidate immediately: in-flight results cannot repopulate a closed session.
    _closed = true;
    await _channel.invokeMethod<void>('close', {'session': _handle});
  }
}
