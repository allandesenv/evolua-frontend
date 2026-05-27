import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final careSecretStoreProvider = Provider<CareSecretStore>((ref) {
  return const FlutterCareSecretStore(FlutterSecureStorage());
});

abstract class CareSecretStore {
  Future<void> save(String shareId, String secretBase64);
  Future<String?> read(String shareId);
  Future<void> delete(String shareId);
}

class FlutterCareSecretStore implements CareSecretStore {
  const FlutterCareSecretStore(this._storage);

  final FlutterSecureStorage _storage;

  String _key(String shareId) => 'evolua.care.share_secret.$shareId';

  @override
  Future<void> save(String shareId, String secretBase64) {
    return _storage.write(key: _key(shareId), value: secretBase64);
  }

  @override
  Future<String?> read(String shareId) {
    return _storage.read(key: _key(shareId));
  }

  @override
  Future<void> delete(String shareId) {
    return _storage.delete(key: _key(shareId));
  }
}
