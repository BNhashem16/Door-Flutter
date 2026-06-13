/// One guest-pass redemption (a visitor arrival).
///
/// Stored under `/guest_redemptions/{ownerUid}/{passId}/{pushId}` in the
/// Realtime Database, written only by the redeem Worker (service-account auth).
/// Hand-written `fromMap`/`toMap` — no code-gen, per project conventions.
library;

/// Immutable record of a single successful redemption.
class GuestRedemption {
  const GuestRedemption({required this.id, required this.at});

  /// RTDB push key for this entry.
  final String id;

  /// Epoch ms the redemption was committed (Worker `ts`).
  final int at;

  factory GuestRedemption.fromMap(String id, Map<dynamic, dynamic> map) {
    return GuestRedemption(id: id, at: (map['at'] ?? 0) as int);
  }

  Map<String, Object?> toMap() => {'at': at};
}
