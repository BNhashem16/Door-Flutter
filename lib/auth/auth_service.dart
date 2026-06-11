import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../admin/audit_log.dart';
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
  AuthService({
    FirebaseAuth? auth,
    FirebaseDatabase? db,
    EmailOtpService? otp,
  })  : _auth = auth ?? FirebaseAuth.instance,
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

  /// Local storage namespace for a pre-account registration OTP, keyed by the
  /// normalized email (no uid exists yet at this stage).
  String _regKey(String email) => 'reg:${email.trim().toLowerCase()}';

  /// Send a 4-digit OTP to [email] BEFORE any account is created, so an
  /// unverified email never lands a row in the database. [locale] (`ar`|`en`)
  /// selects the email language. Returns [OtpOk], [OtpCooldown] during the
  /// resend cooldown, or [OtpError] (email failed / Brevo not configured).
  Future<OtpResult> sendRegistrationOtp({
    required String email,
    required String locale,
  }) {
    return _otp.send(uid: _regKey(email), email: email.trim(), locale: locale);
  }

  /// Check the registration [code] for [email]. Does NOT create the account —
  /// call [completeRegistration] after this returns [OtpOk].
  Future<OtpResult> verifyRegistrationOtp({
    required String email,
    required String code,
  }) {
    return _otp.verify(uid: _regKey(email), code: code);
  }

  /// Create the Firebase Auth user and the pending profile record AFTER the
  /// email OTP has been verified. createUser auto-signs-in, so [AuthGate]
  /// routes the new (pending) user to the pending screen. The profile is
  /// written with `emailVerified: false` because the security rules require it
  /// on owner-create; email ownership is already proven by the OTP step.
  /// Throws [FirebaseAuthException] (e.g. `email-already-in-use`).
  Future<void> completeRegistration({
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
    await _otp.clear(_regKey(email));
  }

  /// Forgot-password (user is signed OUT): trigger Firebase's built-in
  /// password-reset email to [email]. Firebase sends a secure reset link
  /// (localized by [locale], `ar`|`en`) from its own authenticated mailer; the
  /// user sets a new password from it. Free — no paid backend required.
  ///
  /// Throws [FirebaseAuthException]; callers should treat `user-not-found` as
  /// success to avoid revealing which emails are registered.
  Future<void> sendPasswordResetEmail({
    required String email,
    required String locale,
  }) async {
    await _auth.setLanguageCode(locale);
    await _auth.sendPasswordResetEmail(email: email.trim());
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

  /// Signed-in owner: change own password. Reauthenticates with
  /// [currentPassword] (proves identity, satisfies Firebase's recent-login
  /// requirement) then sets [newPassword]. Throws [FirebaseAuthException]
  /// (`wrong-password`/`invalid-credential` on a bad current password,
  /// `weak-password` on a short new one, `no-current-user` if signed out).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    await reauthenticate(currentPassword);
    await user.updatePassword(newPassword);
  }

  /// The id of the device currently bound to this install.
  Future<String> currentDeviceId() => DeviceSession.id();

  Future<void> signOut() async {
    // Best-effort: drop this device's push token for the signing-out user so it
    // stops receiving their notifications. Must run while still authenticated
    // (the RTDB rule requires auth.uid === $uid).
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await removeFcmToken(uid, token);
      } on Exception {
        // Token cleanup is non-critical; never block sign-out on it.
      }
    }
    await _auth.signOut();
  }

  // --- FCM push tokens (/fcm_tokens/{uid}/{token}) ---

  /// Owner: register this device's push token. Stored as a set of token keys so
  /// a user with several devices receives notifications on all of them. Cloud
  /// Functions read these via the Admin SDK to target a user/admin.
  Future<void> saveFcmToken(String uid, String token) =>
      _db.ref('fcm_tokens/$uid/$token').set(true);

  /// Owner: drop one push token (on sign-out or when FCM reports it stale).
  Future<void> removeFcmToken(String uid, String token) =>
      _db.ref('fcm_tokens/$uid/$token').remove();

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

  /// Admin: remove a user's Realtime Database records.
  ///
  /// Atomically deletes the RTDB profile (/app_users/{uid}) and the user's
  /// gate access logs (/gate_logs/{uid}) in a single multi-location update.
  /// The security rules permit this only when the caller is an admin.
  ///
  /// Note: this is a client-side delete and CANNOT remove the Firebase Auth
  /// account (only the Admin SDK can). The Auth record is orphaned — the user
  /// can no longer sign in (their profile is gone), but the email stays
  /// reserved in Auth and cannot be reused for a fresh registration.
  ///
  /// Throws on failure (e.g. the rules reject the write if the caller is not
  /// an admin).
  Future<void> deleteUser(String uid) async {
    await _db.ref().update(<String, Object?>{
      'app_users/$uid': null,
      'gate_logs/$uid': null,
    });
  }

  // --- Admin push outbox (/push_outbox/{id}) ---

  /// Admin: enqueue a push notification for [targetUid]. The Cloudflare Worker
  /// cron drains `/push_outbox` once a minute and sends it via FCM (the app's
  /// receive stack already exists), so it reaches the user even if their app is
  /// closed. [type] is one of `approved` | `rejected` | `ticket_resolved`; the
  /// Worker owns the Arabic copy. Admin-only write per the security rules.
  Future<void> enqueuePush({
    required String type,
    required String targetUid,
  }) {
    return _db.ref('push_outbox').push().set({
      'type': type,
      'targetUid': targetUid,
      'createdAt': ServerValue.timestamp,
    });
  }

  /// Admin: broadcast an announcement to every approved resident. The Worker
  /// cron fans it out (FCM push + a stored `/notifications` entry per user).
  /// Admin-authored copy, so [title]/[body] travel in the outbox entry.
  Future<void> enqueueBroadcast({
    required String title,
    required String body,
  }) {
    return _db.ref('push_outbox').push().set({
      'type': 'broadcast',
      'title': title.trim(),
      'body': body.trim(),
      'createdAt': ServerValue.timestamp,
    });
  }

  // --- Admin audit log (/audit_logs/{id}) ---

  /// Admin: append an audit entry for an admin action. [action] is a stable key
  /// (`approve`/`reject`/`make_admin`/`remove_admin`/`edit_user`/`delete_user`/
  /// `resolve_ticket`); the UI localizes it. Names are denormalized so the entry
  /// survives the target's deletion. No-op when signed out.
  Future<void> recordAudit({
    required String actorName,
    required String action,
    required String targetUid,
    required String targetName,
  }) {
    final actorUid = _auth.currentUser?.uid;
    if (actorUid == null) return Future<void>.value();
    return _db.ref('audit_logs').push().set({
      'actorUid': actorUid,
      'actorName': actorName.trim(),
      'action': action,
      'targetUid': targetUid,
      'targetName': targetName.trim(),
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Admin: live stream of audit-log entries, newest first.
  Stream<List<AuditLog>> watchAuditLogs() {
    return _db.ref('audit_logs').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <AuditLog>[];
      return value.entries
          .where((e) => e.value is Map)
          .map((e) => AuditLog.fromMap(e.key as String, e.value as Map))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  /// Owner: permanently delete own account. Clears all RTDB records first
  /// (while still authenticated, so the rules authorize each path) then deletes
  /// the Firebase Auth user. Reauthenticates with [password] to satisfy
  /// Firebase's recent-login requirement. Throws [FirebaseAuthException]
  /// (`wrong-password`/`invalid-credential`, `no-current-user`).
  Future<void> deleteOwnAccount(String password) async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (user == null || uid == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    await reauthenticate(password);
    await _db.ref().update(<String, Object?>{
      'app_users/$uid': null,
      'gate_logs/$uid': null,
      'guest_passes/$uid': null,
      'support_tickets/$uid': null,
      'notifications/$uid': null,
      'fcm_tokens/$uid': null,
      'notification_prefs/$uid': null,
    });
    await user.delete();
  }

  // --- Notification preferences (/notification_prefs/{uid}) ---
  // Owner-controlled per-type opt-out for NON-critical pushes (guest redeem,
  // announcements, doorbell ring). Approval/rejection/ticket-resolved always
  // send. The Worker reads this node before pushing each notification.

  /// Live notification preferences for [uid] as a `{type: enabled}` map. A
  /// missing entry means enabled (opt-out model).
  Stream<Map<String, bool>> watchNotificationPrefs(String uid) {
    return _db.ref('notification_prefs/$uid').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <String, bool>{};
      return value.map((k, v) => MapEntry(k.toString(), v == true));
    });
  }

  /// Owner: set whether [type] notifications are enabled.
  Future<void> setNotificationPref(String uid, String type, bool enabled) {
    return _db.ref('notification_prefs/$uid').update({type: enabled});
  }

  static String _roleRaw(UserRole role) =>
      role == UserRole.admin ? 'admin' : 'user';

  static String _statusRaw(UserStatus status) => switch (status) {
        UserStatus.approved => 'approved',
        UserStatus.rejected => 'rejected',
        _ => 'pending',
      };
}
