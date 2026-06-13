'use strict';

// Pure validator for the access-code redeem endpoint. Returns an error reason
// string ('invalid' | 'used' | 'expired' | 'not_pending') or null when the
// redemption is allowed. Kept in its own ESM module so the node:test unit test
// and the Worker (`index.js`) share one source of truth.
//
// rec     — the /access_codes/{uid} record (or null)
// profile — the /app_users/{uid} record (or null)
// code    — the code the caller submitted (already lowercased/trimmed)
// now     — Date.now() epoch ms
export function accessInvalidReason(rec, profile, code, now) {
  if (!rec || typeof rec !== 'object') return 'invalid';
  if (typeof code !== 'string' || rec.code !== code) return 'invalid';
  if (rec.used === true) return 'used';
  if (typeof rec.expiresAt !== 'number' || now > rec.expiresAt) return 'expired';
  if (!profile || typeof profile !== 'object' || profile.status !== 'pending') {
    return 'not_pending';
  }
  return null;
}
