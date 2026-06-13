import 'dart:convert';

import 'secure_store.dart';

/// A saved account as exposed to the UI — never carries the password.
class SavedAccount {
  const SavedAccount({required this.email, required this.name});

  final String email;
  final String name;

  /// Lowercased email — the stable identity key for an account.
  String get key => email.trim().toLowerCase();
}

/// Internal record including the stored password. Kept private to this file so
/// the plaintext password never escapes into widget code.
class _StoredAccount {
  const _StoredAccount({
    required this.email,
    required this.name,
    required this.password,
  });

  final String email;
  final String name;
  final String password;

  String get key => email.trim().toLowerCase();

  factory _StoredAccount.fromMap(Map<String, dynamic> map) => _StoredAccount(
        email: (map['email'] ?? '') as String,
        name: (map['name'] ?? '') as String,
        password: (map['password'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'email': email,
        'name': name,
        'password': password,
      };

  _StoredAccount copyWith({String? name, String? password}) => _StoredAccount(
        email: email,
        name: name ?? this.name,
        password: password ?? this.password,
      );
}

/// Stores the set of accounts the user has signed in with on this device, so
/// they can switch between them without a manual logout/login round-trip.
///
/// The whole list — including passwords — lives as a single JSON blob in the OS
/// secure store (Keychain on iOS, EncryptedSharedPreferences on Android), the
/// same boundary the biometric-unlock feature uses. Passwords never reach the
/// UI: [list] returns [SavedAccount] (email + name only).
class AccountStore {
  const AccountStore({SecureStore store = const FlutterSecureStore()})
      : _store = store;

  final SecureStore _store;

  static const _key = 'multi_accounts_v1';

  Future<List<_StoredAccount>> _readAll() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => _StoredAccount.fromMap(m.cast<String, dynamic>()))
          .where((a) => a.email.isNotEmpty)
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> _writeAll(List<_StoredAccount> accounts) async {
    final json = jsonEncode(accounts.map((a) => a.toMap()).toList());
    await _store.write(_key, json);
  }

  /// Add [email]/[password] to the device list, or update them in place if the
  /// email is already saved. [name] refreshes the cached display name when
  /// non-empty (an empty name keeps any previously stored one).
  Future<void> remember({
    required String email,
    required String password,
    String name = '',
  }) async {
    final accounts = await _readAll();
    final k = email.trim().toLowerCase();
    final idx = accounts.indexWhere((a) => a.key == k);
    if (idx >= 0) {
      accounts[idx] = accounts[idx].copyWith(
        password: password,
        name: name.isNotEmpty ? name : null,
      );
    } else {
      accounts.add(
        _StoredAccount(
            email: email.trim(), name: name.trim(), password: password),
      );
    }
    await _writeAll(accounts);
  }

  /// Refresh the cached display name for [email] (no-op if not saved).
  Future<void> setName(String email, String name) async {
    if (name.trim().isEmpty) return;
    final accounts = await _readAll();
    final k = email.trim().toLowerCase();
    final idx = accounts.indexWhere((a) => a.key == k);
    if (idx < 0) return;
    if (accounts[idx].name == name.trim()) return;
    accounts[idx] = accounts[idx].copyWith(name: name.trim());
    await _writeAll(accounts);
  }

  /// All saved accounts (email + name only).
  Future<List<SavedAccount>> list() async {
    final accounts = await _readAll();
    return accounts
        .map((a) => SavedAccount(email: a.email, name: a.name))
        .toList();
  }

  /// Stored credentials for [email], or null if not saved.
  Future<({String email, String password})?> credentials(String email) async {
    final accounts = await _readAll();
    final k = email.trim().toLowerCase();
    final idx = accounts.indexWhere((a) => a.key == k);
    if (idx < 0) return null;
    return (email: accounts[idx].email, password: accounts[idx].password);
  }

  /// Forget [email] (e.g. user removed it from the switcher).
  Future<void> remove(String email) async {
    final accounts = await _readAll();
    final k = email.trim().toLowerCase();
    accounts.removeWhere((a) => a.key == k);
    await _writeAll(accounts);
  }
}
