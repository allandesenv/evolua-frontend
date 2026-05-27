import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';

final careSecretStoreProvider = Provider<CareSecretStore>((ref) {
  return FlutterCareSecretStore(
    const FlutterSecureStorage(),
    currentUserId: () => ref.read(authControllerProvider).asData?.value?.userId,
  );
});

abstract class CareSecretStore {
  Future<void> save(String shareId, String secretBase64);
  Future<String?> read(String shareId);
  Future<void> delete(String shareId);
}

class FlutterCareSecretStore implements CareSecretStore {
  const FlutterCareSecretStore(
    this._storage, {
    String? Function()? currentUserId,
  }) : _currentUserId = currentUserId;

  final FlutterSecureStorage _storage;
  final String? Function()? _currentUserId;

  String _legacyKey(String shareId) => 'evolua.care.share_secret.$shareId';

  String _key(String shareId) {
    final userId = _currentUserId?.call();
    if (userId == null || userId.isEmpty) {
      return _legacyKey(shareId);
    }
    return 'evolua.care.share_secret.$userId.$shareId';
  }

  @override
  Future<void> save(String shareId, String secretBase64) {
    return _storage.write(key: _key(shareId), value: secretBase64);
  }

  @override
  Future<String?> read(String shareId) async {
    final key = _key(shareId);
    final scoped = await _storage.read(key: key);
    if (scoped != null && scoped.isNotEmpty) {
      return scoped;
    }
    final legacy = await _storage.read(key: _legacyKey(shareId));
    if (legacy != null && legacy.isNotEmpty && key != _legacyKey(shareId)) {
      await _storage.write(key: key, value: legacy);
      return legacy;
    }
    return legacy;
  }

  @override
  Future<void> delete(String shareId) async {
    await _storage.delete(key: _key(shareId));
    await _storage.delete(key: _legacyKey(shareId));
  }
}
