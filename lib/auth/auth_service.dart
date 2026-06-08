import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'device_session.dart';

/// User account status controlled by an admin.
enum UserStatus { pending, approved, rejected, unknown }

/// User role.
enum UserRole { user, admin }

/// Immutable profile record stored under /app_users/{uid}.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.createdAt,
    this.apartment = '',
    this.bio = '',
    this.activeDevice = '',
  });

  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final UserStatus status;
  final int createdAt;
  final String apartment;
  final String bio;

  /// Id of the device currently allowed to use this account (single-device).
  final String activeDevice;

  bool get isAdmin => role == UserRole.admin;
  bool get isApproved => status == UserStatus.approved;

  factory AppUser.fromMap(String uid, Map<dynamic, dynamic> map) {
    return AppUser(
      uid: uid,
      email: (map['email'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      role: (map['role'] == 'admin') ? UserRole.admin : UserRole.user,
      status: _statusFrom(map['status'] as String?),
      createdAt: (map['createdAt'] ?? 0) as int,
      apartment: (map['apartment'] ?? '') as String,
      bio: (map['bio'] ?? '') as String,
      activeDevice: (map['activeDevice'] ?? '') as String,
    );
  }

  AppUser copyWith({
    String? name,
    String? apartment,
    String? bio,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      name: name ?? this.name,
      role: role,
      status: status,
      createdAt: createdAt,
      apartment: apartment ?? this.apartment,
      bio: bio ?? this.bio,
    );
  }

  Map<String, Object?> toMap() => {
        'email': email,
        'name': name,
        'role': role == UserRole.admin ? 'admin' : 'user',
        'status': switch (status) {
          UserStatus.approved => 'approved',
          UserStatus.rejected => 'rejected',
          UserStatus.pending => 'pending',
          UserStatus.unknown => 'pending',
        },
        'createdAt': createdAt,
        'apartment': apartment,
        'bio': bio,
      };

  static UserStatus _statusFrom(String? raw) => switch (raw) {
        'approved' => UserStatus.approved,
        'rejected' => UserStatus.rejected,
        'pending' => UserStatus.pending,
        _ => UserStatus.unknown,
      };
}

/// Wraps FirebaseAuth + Realtime Database user records.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseDatabase? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: databaseUrl,
            );

  // Must match the project's Realtime Database instance.
  static const String databaseUrl = 'https://microiot.firebaseio.com';

  final FirebaseAuth _auth;
  final FirebaseDatabase _db;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  DatabaseReference _userRef(String uid) => _db.ref('app_users/$uid');

  /// Live profile stream for an authenticated user.
  Stream<AppUser?> userProfile(String uid) {
    final ref = _userRef(uid);
    // Keep this node warm in the local cache so it emits instantly on the next
    // launch instead of waiting on the network.
    unawaited(ref.keepSynced(true));
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return null;
      return AppUser.fromMap(uid, value);
    });
  }

  /// Register with email/password and create a pending profile record.
  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    final profile = AppUser(
      uid: uid,
      email: email.trim(),
      name: name.trim(),
      role: UserRole.user,
      status: UserStatus.pending,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _userRef(uid).set(profile.toMap());
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Single-device: claim this account for the current device. Any other
    // device still signed in will observe the change and sign itself out.
    final uid = cred.user?.uid;
    if (uid != null) {
      final deviceId = await DeviceSession.id();
      await _userRef(uid).update({'activeDevice': deviceId});
    }
  }

  /// The id of the device currently bound to this install.
  Future<String> currentDeviceId() => DeviceSession.id();

  Future<void> signOut() => _auth.signOut();

  /// Owner: update editable profile fields only (never role/status/email).
  Future<void> updateProfile(
    String uid, {
    required String name,
    required String apartment,
    required String bio,
  }) {
    return _userRef(uid).update({
      'name': name.trim(),
      'apartment': apartment.trim(),
      'bio': bio.trim(),
    });
  }

  /// Admin: live list of all user profiles.
  Stream<List<AppUser>> watchAllUsers() {
    return _db.ref('app_users').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <AppUser>[];
      return value.entries
          .where((e) => e.value is Map)
          .map((e) => AppUser.fromMap(e.key as String, e.value as Map))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  /// Admin: change a user's approval status.
  Future<void> setStatus(String uid, UserStatus status) {
    return _userRef(uid).update({'status': _statusRaw(status)});
  }

  /// Admin: promote/demote a user's role.
  Future<void> setRole(String uid, UserRole role) {
    return _userRef(uid).update({'role': _roleRaw(role)});
  }

  /// Admin: full edit of a user's profile, including the admin-only fields
  /// (`role`/`status`). `email`/`createdAt` stay immutable — they are left out
  /// of the patch so the RTDB `.validate` still sees them on the merged node.
  Future<void> adminUpdateUser(
    String uid, {
    required String name,
    required String apartment,
    required String bio,
    required UserRole role,
    required UserStatus status,
  }) {
    return _userRef(uid).update({
      'name': name.trim(),
      'apartment': apartment.trim(),
      'bio': bio.trim(),
      'role': _roleRaw(role),
      'status': _statusRaw(status),
    });
  }

  /// Admin: delete a user's profile record.
  ///
  /// NOTE: this removes the RTDB profile only. The underlying Firebase Auth
  /// account cannot be deleted from the client — that needs the Admin SDK
  /// (a Cloud Function). After this, the user falls back to the pending screen
  /// if still signed in elsewhere, and can no longer reach the gate.
  Future<void> deleteUser(String uid) => _userRef(uid).remove();

  static String _roleRaw(UserRole role) =>
      role == UserRole.admin ? 'admin' : 'user';

  static String _statusRaw(UserStatus status) => switch (status) {
        UserStatus.approved => 'approved',
        UserStatus.rejected => 'rejected',
        _ => 'pending',
      };
}
