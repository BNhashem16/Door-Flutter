import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../logs/gate_log.dart';
import 'device_session.dart';
import 'email_otp_service.dart';
import 'otp_result.dart';

export 'otp_result.dart';

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
    this.emailVerified = false,
  });

  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final UserStatus status;
  final int createdAt;
  final String apartment;
  final String bio;

  /// Whether the user confirmed ownership of [email] via the 4-digit OTP.
  /// Flipped to `true` only by the verify Cloud Function (Admin SDK write);
  /// owners cannot self-set it (see `database.rules.json`).
  final bool emailVerified;

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
      emailVerified: map['emailVerified'] == true,
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
      activeDevice: activeDevice,
      emailVerified: emailVerified,
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
        'emailVerified': emailVerified,
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
  AuthService({FirebaseAuth? auth, FirebaseDatabase? db, EmailOtpService? otp})
      : _auth = auth ?? FirebaseAuth.instance,
        _otp = otp ?? EmailOtpService(),
        _db = db ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: databaseUrl,
            );

  // Must match the project's Realtime Database instance.
  static const String databaseUrl = 'https://microiot.firebaseio.com';

  final FirebaseAuth _auth;
  final FirebaseDatabase _db;
  final EmailOtpService _otp;

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
  /// [locale] (`ar`|`en`) selects the language of the OTP email.
  Future<void> register({
    required String email,
    required String password,
    required String name,
    String locale = 'ar',
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
    // Send the first 4-digit OTP. AuthGate keeps the account on the verify
    // screen until the profile's emailVerified flag flips (set server-side by
    // the verify Cloud Function). A send failure is non-fatal here — the user
    // can resend from the verify screen.
    await sendEmailOtp(locale);
  }

  /// Send a fresh 4-digit OTP to the signed-in user's email in [locale]
  /// (`ar`|`en`). Returns [OtpOk], [OtpCooldown] while the resend cooldown is
  /// active, or [OtpError] (email failed / not configured / signed out).
  Future<OtpResult> sendEmailOtp(String locale) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return const OtpError();
    return _otp.send(uid: user.uid, email: email, locale: locale);
  }

  /// Verify the entered [code]. On [OtpOk], flips `emailVerified` in RTDB so
  /// the profile stream re-routes the gate forward.
  Future<OtpResult> verifyEmailOtp(String code) async {
    final user = _auth.currentUser;
    if (user == null) return const OtpError();
    final result = await _otp.verify(uid: user.uid, code: code);
    if (result is OtpOk) {
      await _userRef(user.uid).update({'emailVerified': true});
    }
    return result;
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

  /// Verify the current user's password against Firebase. Throws a
  /// [FirebaseAuthException] (`wrong-password`/`invalid-credential`) on mismatch.
  /// Used to confirm identity before saving credentials for biometric unlock.
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);
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

  // --- Gate access logs (/gate_logs/{uid}/{logId}) ---

  /// In-app write of a gate action. Runs as the signed-in user, so the RTDB
  /// rule `auth.uid === $uid` authorizes the write. Server-stamps the time.
  Future<void> logGateAction({
    required String uid,
    required String name,
    required GateAction action,
    required GateSource source,
  }) {
    return _db.ref('gate_logs/$uid').push().set({
      'name': name.trim(),
      'action': action == GateAction.open ? 'open' : 'close',
      'source': source == GateSource.widget ? 'widget' : 'app',
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Owner/admin: live stream of one user's gate logs, newest first.
  Stream<List<GateLog>> watchUserLogs(String uid) {
    final ref = _db.ref('gate_logs/$uid');
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <GateLog>[];
      return value.entries
          .where((e) => e.value is Map)
          .map((e) => GateLog.fromMap(e.key as String, uid, e.value as Map))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  /// Admin: live stream of every user's gate logs, flattened, newest first.
  Stream<List<GateLog>> watchAllLogs() {
    return _db.ref('gate_logs').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <GateLog>[];
      final logs = <GateLog>[];
      for (final userEntry in value.entries) {
        final uid = userEntry.key as String;
        final userLogs = userEntry.value;
        if (userLogs is! Map) continue;
        for (final logEntry in userLogs.entries) {
          if (logEntry.value is Map) {
            logs.add(GateLog.fromMap(
                logEntry.key as String, uid, logEntry.value as Map));
          }
        }
      }
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    });
  }

  /// Admin: delete a user's profile record.
  ///
  /// NOTE: this removes the RTDB profile only. The underlying Firebase Auth
  /// account cannot be deleted from the client — that needs the Admin SDK
  /// (a Cloud Function, which requires the Blaze plan). After this, the user
  /// falls back to the pending screen if still signed in elsewhere, and can no
  /// longer reach the gate.
  Future<void> deleteUser(String uid) => _userRef(uid).remove();

  static String _roleRaw(UserRole role) =>
      role == UserRole.admin ? 'admin' : 'user';

  static String _statusRaw(UserStatus status) => switch (status) {
        UserStatus.approved => 'approved',
        UserStatus.rejected => 'rejected',
        _ => 'pending',
      };
}
