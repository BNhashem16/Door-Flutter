import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'guest_pass.dart';

/// Realtime Database wrapper for guest passes, scoped to one resident's subtree
/// `/guest_passes/{ownerUid}`.
///
/// A focused service in the **GateService** spirit (a dedicated wrapper, not
/// `AuthService` bloat). Widgets go through this — never `FirebaseDatabase`
/// directly. Creation is a plain owner write; redemption + the `usedCount`
/// bump happen server-side in the `guestPass` Cloud Function (Admin SDK), so
/// the app never needs a privileged write.
class GuestService {
  GuestService({FirebaseDatabase? db})
      : _db = db ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: _databaseUrl,
            );

  final FirebaseDatabase _db;

  /// RTDB instance host shared with [AuthService]/[GateService].
  static const String _databaseUrl = 'https://microiot.firebaseio.com';

  /// Public redeem endpoint — a free Cloudflare Worker (see
  /// `cloudflare/guest-worker/`) that replaces the Blaze-only `guestPass` Cloud
  /// Function. Owner uid is not sensitive; the token is the bearer capability.
  static const String _redeemBase =
      'https://door-gate.hashem-codes.workers.dev';

  /// Lowercase RFC-4648 base32 alphabet (matches the function's token regex
  /// `^[a-z2-7]{8,16}$`).
  static const String _alphabet = 'abcdefghijklmnopqrstuvwxyz234567';

  DatabaseReference _ownerRef(String ownerUid) =>
      _db.ref('guest_passes/$ownerUid');

  /// Cryptographically-strong ~50-bit token (10 base32 chars).
  static String _generateToken() {
    final rng = Random.secure();
    return List.generate(10, (_) => _alphabet[rng.nextInt(_alphabet.length)])
        .join();
  }

  /// Build the shareable redeem link for a pass.
  static String redeemUrl({required String ownerUid, required String token}) =>
      '$_redeemBase?u=$ownerUid&c=$token';

  /// Create a pass for [ownerUid]. [validFor] sets the window from now;
  /// [maxUses] `0` ⇒ unlimited within the window. Returns the stored
  /// [GuestPass] (with its token) so the caller can show the share view.
  Future<GuestPass> createPass({
    required String ownerUid,
    required String createdByName,
    required String label,
    required Duration validFor,
    required int maxUses,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final token = _generateToken();
    final pass = GuestPass(
      token: token,
      label: label.trim(),
      createdBy: ownerUid,
      createdByName: createdByName.trim(),
      createdAt: now,
      expiresAt: now + validFor.inMilliseconds,
      maxUses: maxUses,
      usedCount: 0,
      status: GuestPassStatus.active,
    );
    await _ownerRef(ownerUid).child(token).set(pass.toMap());
    return pass;
  }

  /// Live list of [ownerUid]'s passes, newest first.
  Stream<List<GuestPass>> watchPasses(String ownerUid) {
    return _ownerRef(ownerUid).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <GuestPass>[];
      return value.entries
          .where((e) => e.value is Map)
          .map((e) => GuestPass.fromMap(e.key as String, e.value as Map))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  /// Revoke a pass (owner write). Flips `status` to `revoked`; the function
  /// then refuses redemption. Kept instead of delete so the row stays auditable.
  Future<void> revoke(String ownerUid, String passId) =>
      _ownerRef(ownerUid).child(passId).update({'status': 'revoked'});

  /// Permanently remove a pass row.
  Future<void> delete(String ownerUid, String passId) =>
      _ownerRef(ownerUid).child(passId).remove();
}
