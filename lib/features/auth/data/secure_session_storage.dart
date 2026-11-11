import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists tokens in Keychain/Keystore-backed storage rather than app prefs.
/// On web the platform implementation requires HTTPS or localhost and uses
/// browser storage; it cannot offer native Keychain isolation from page scripts.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    required this.storageKey,
    FlutterSecureStorage? storage,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
           );

  final String storageKey;
  final FlutterSecureStorage _storage;
  Future<void> _pending = Future<void>.value();
  bool _writesAllowed = true;
  int _generation = 0;

  void suspendWrites() {
    _writesAllowed = false;
    _generation++;
  }

  void resumeWrites() {
    _writesAllowed = true;
    _generation++;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _pending.catchError((Object _) {}).then((_) => action());
    _pending = operation;
    return operation;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<String?> accessToken() async {
    await _pending.catchError((Object _) {});
    return _storage.read(key: storageKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    final generation = _generation;
    return _enqueue(() async {
      if (!_writesAllowed || generation != _generation) return;
      final value = jsonDecode(persistSessionString) as Map<String, dynamic>;
      final user = value['user'] as Map<String, dynamic>?;
      // An unverified signup must never become an auto-login session.
      if (user?['email_confirmed_at'] == null) return;
      await _storage.write(key: storageKey, value: persistSessionString);
    });
  }

  @override
  Future<void> removePersistedSession() =>
      _enqueue(() => _storage.delete(key: storageKey));
}
