import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where passwords live. Never the database, never a settings row.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Key under which the proxy password is kept.
const proxyPasswordKey = 'haul.proxy';

/// Key under which the login for [host] is kept.
String siteLoginKey(String host) => 'haul.login.${host.toLowerCase()}';

/// The platform's own secret store: the macOS Keychain, or the encrypted
/// per-user storage Windows provides.
///
/// On macOS, Haul is distributed as a DMG without a provisioning profile, so
/// it uses the legacy (file-based) keychain; the data-protection keychain
/// would need the `keychain-access-groups` entitlement and a profile. This is
/// the option `flutter_secure_storage` documents for that situation. Windows
/// ignores that option and encrypts with the user's own login.
class SecureStorageSecretStore implements SecretStore {
  SecureStorageSecretStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// For tests and previews. Nothing is persisted.
class MemorySecretStore implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
