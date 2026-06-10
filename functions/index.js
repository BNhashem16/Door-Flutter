'use strict';

// Door — OTP email verification (Firebase Functions v2, JavaScript).
//
// Two callables:
//   sendEmailOtp({ locale })  -> generates a 4-digit code, stores a salted
//                                SHA-256 hash in RTDB, emails the code via Brevo.
//   verifyEmailOtp({ code })  -> checks the code, on success flips
//                                /app_users/{uid}/emailVerified = true.
//
// All writes to /email_verifications/{uid} use the Admin SDK (bypasses RTDB
// rules). The client never reads or writes that node — see database.rules.json.

const crypto = require('crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const {
  onValueCreated,
  onValueUpdated,
} = require('firebase-functions/v2/database');
const { defineSecret } = require('firebase-functions/params');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

const config = require('./config');
const { otpEmail } = require('./email_templates');

admin.initializeApp();
setGlobalOptions({ region: config.region });

const BREVO_API_KEY = defineSecret('BREVO_API_KEY');

// ---------------------------------------------------------------------------
// Pure helpers (exported for unit tests).
// ---------------------------------------------------------------------------

function sha256Hex(value) {
  return crypto.createHash('sha256').update(value, 'utf8').digest('hex');
}

// Constant-time hex compare. Returns false on length mismatch instead of
// throwing, so it is safe to call on attacker-influenced input.
function timingSafeEqualHex(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const bufA = Buffer.from(a, 'hex');
  const bufB = Buffer.from(b, 'hex');
  if (bufA.length === 0 || bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

// Cryptographically-random zero-padded 4-digit code: "0000".."9999".
function generateCode() {
  return String(crypto.randomInt(0, 10000)).padStart(4, '0');
}

function buildOtpRecord(code, now) {
  const salt = crypto.randomBytes(16).toString('hex');
  return {
    hash: sha256Hex(salt + code),
    salt,
    expiresAt: now + config.codeTtlMs,
    attempts: 0,
    cooldownUntil: now + config.resendCooldownMs,
  };
}

// ---------------------------------------------------------------------------
// Infrastructure helpers.
// ---------------------------------------------------------------------------

function verifRef(uid) {
  return admin.database().ref(`/email_verifications/${uid}`);
}

async function sendBrevoEmail({ apiKey, toEmail, subject, html, text }) {
  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': apiKey,
      'content-type': 'application/json',
      accept: 'application/json',
    },
    body: JSON.stringify({
      sender: { email: config.senderEmail, name: config.senderName },
      // Reply-To points at the verified sender so replies land somewhere real.
      replyTo: { email: config.senderEmail, name: config.senderName },
      to: [{ email: toEmail }],
      subject,
      htmlContent: html,
      // Multipart: a plain-text alternative lowers spam score vs HTML-only.
      textContent: text,
      // Brevo categorizes transactional mail; helps reputation tracking.
      tags: ['otp'],
    }),
  });

  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    // Don't leak the Brevo response wholesale to the client.
    console.error('Brevo send failed', res.status, detail.slice(0, 500));
    throw new HttpsError('internal', 'email_send_failed');
  }
}

// ---------------------------------------------------------------------------
// Callable: sendEmailOtp
// ---------------------------------------------------------------------------

const sendEmailOtp = onCall({ secrets: [BREVO_API_KEY] }, async (request) => {
  const auth = request.auth;
  if (!auth) throw new HttpsError('unauthenticated', 'sign_in_required');

  const uid = auth.uid;
  const email = auth.token && auth.token.email;
  if (!email) throw new HttpsError('failed-precondition', 'no_email');

  const now = Date.now();
  const ref = verifRef(uid);

  const snap = await ref.get();
  if (snap.exists()) {
    const rec = snap.val();
    if (rec.cooldownUntil && rec.cooldownUntil > now) {
      const remaining = Math.ceil((rec.cooldownUntil - now) / 1000);
      throw new HttpsError('resource-exhausted', 'cooldown', {
        cooldownSeconds: remaining,
      });
    }
  }

  const code = generateCode();
  await ref.set(buildOtpRecord(code, now));

  const locale = request.data && request.data.locale === 'en' ? 'en' : 'ar';
  const { subject, html, text } = otpEmail(locale, code);

  await sendBrevoEmail({
    apiKey: BREVO_API_KEY.value(),
    toEmail: email,
    subject,
    html,
    text,
  });

  return { ok: true, cooldownSeconds: Math.round(config.resendCooldownMs / 1000) };
});

// ---------------------------------------------------------------------------
// Callable: verifyEmailOtp
// ---------------------------------------------------------------------------

const verifyEmailOtp = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) throw new HttpsError('unauthenticated', 'sign_in_required');

  const uid = auth.uid;
  const code = String((request.data && request.data.code) || '');
  if (!/^\d{4}$/.test(code)) {
    throw new HttpsError('invalid-argument', 'bad_code');
  }

  const ref = verifRef(uid);
  const snap = await ref.get();
  if (!snap.exists()) throw new HttpsError('failed-precondition', 'expired');

  const rec = snap.val();
  const now = Date.now();

  if (!rec.expiresAt || rec.expiresAt < now) {
    await ref.remove();
    throw new HttpsError('failed-precondition', 'expired');
  }
  if ((rec.attempts || 0) >= config.maxAttempts) {
    throw new HttpsError('failed-precondition', 'too_many');
  }

  const candidate = sha256Hex(rec.salt + code);
  if (timingSafeEqualHex(candidate, rec.hash)) {
    await admin.database().ref(`/app_users/${uid}/emailVerified`).set(true);
    await ref.remove();
    return { ok: true };
  }

  const attempts = (rec.attempts || 0) + 1;
  await ref.child('attempts').set(attempts);
  return { ok: false, attemptsLeft: Math.max(0, config.maxAttempts - attempts) };
});

// ---------------------------------------------------------------------------
// Callable: deleteUser (admin only)
// ---------------------------------------------------------------------------
//
// Fully removes a user: their Firebase Auth account (Admin SDK), their RTDB
// profile (/app_users/{uid}), any pending OTP record
// (/email_verifications/{uid}), and their gate access logs
// (/gate_logs/{uid}). Only an admin (role === 'admin' in their own
// profile) may call this. The client deleteUser() routes through here so the
// Auth account is deleted too — a plain RTDB remove cannot touch Auth.

const deleteUser = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) throw new HttpsError('unauthenticated', 'sign_in_required');

  const callerUid = auth.uid;
  const targetUid = String((request.data && request.data.uid) || '');
  if (!targetUid) throw new HttpsError('invalid-argument', 'bad_uid');

  // Authorize: caller must be an admin per their own RTDB profile.
  const roleSnap = await admin
    .database()
    .ref(`/app_users/${callerUid}/role`)
    .get();
  if (roleSnap.val() !== 'admin') {
    throw new HttpsError('permission-denied', 'admin_only');
  }

  // Guard against an admin deleting their own account by accident.
  if (targetUid === callerUid) {
    throw new HttpsError('failed-precondition', 'cannot_delete_self');
  }

  // Delete the Auth account. Tolerate an already-missing account so the RTDB
  // cleanup below still runs (keeps the two stores from drifting).
  try {
    await admin.auth().deleteUser(targetUid);
  } catch (err) {
    if (!err || err.code !== 'auth/user-not-found') {
      console.error('Auth deleteUser failed', targetUid, err && err.code);
      throw new HttpsError('internal', 'auth_delete_failed');
    }
  }

  await Promise.all([
    admin.database().ref(`/app_users/${targetUid}`).remove(),
    admin.database().ref(`/email_verifications/${targetUid}`).remove(),
    admin.database().ref(`/gate_logs/${targetUid}`).remove(),
  ]);

  return { ok: true };
});

// ---------------------------------------------------------------------------
// Push notifications (FCM) — RTDB-triggered
// ---------------------------------------------------------------------------
//
// Tokens live at /fcm_tokens/{uid}/{token} = true (owner-written, see
// database.rules.json). These triggers read them with the Admin SDK and fan
// out via sendEachForMulticast. Two events:
//   onNewPendingUser   — a new /app_users/{uid} (status=pending) → tell admins.
//   onUserStatusChanged— /app_users/{uid}/status flips → tell that user.
//
// The RTDB instance is non-default ('microiot'), so every trigger pins
// `instance` explicitly or it would bind to the wrong database.

const DB_INSTANCE = 'microiot';

// FCM error codes that mean the token is permanently dead — prune on sight.
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

// Returns [{ uid, token }] for a single user's saved devices.
async function recipientsForUid(uid) {
  const snap = await admin.database().ref(`/fcm_tokens/${uid}`).get();
  if (!snap.exists()) return [];
  return Object.keys(snap.val() || {}).map((token) => ({ uid, token }));
}

// Returns [{ uid, token }] for every admin's devices.
async function adminRecipients() {
  const snap = await admin
    .database()
    .ref('/app_users')
    .orderByChild('role')
    .equalTo('admin')
    .get();
  if (!snap.exists()) return [];
  const uids = Object.keys(snap.val() || {});
  const lists = await Promise.all(uids.map(recipientsForUid));
  return lists.flat();
}

// Send `notification` (+ optional data) to recipients, pruning dead tokens.
async function sendToRecipients(recipients, notification, data) {
  if (recipients.length === 0) return;
  const tokens = recipients.map((r) => r.token);

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification,
    data: data || {},
    android: {
      priority: 'high',
      notification: { channelId: 'door_default', sound: 'default' },
    },
  });

  const removals = [];
  res.responses.forEach((r, i) => {
    if (r.success) return;
    const code = r.error && r.error.code;
    if (DEAD_TOKEN_CODES.has(code)) {
      const { uid, token } = recipients[i];
      removals.push(admin.database().ref(`/fcm_tokens/${uid}/${token}`).remove());
    }
  });
  await Promise.all(removals);
}

// New registration lands a pending profile → notify all admins.
const onNewPendingUser = onValueCreated(
  { ref: '/app_users/{uid}', instance: DB_INSTANCE },
  async (event) => {
    const profile = event.data.val();
    if (!profile || profile.status !== 'pending') return;

    const name = (profile.name && String(profile.name).trim()) || 'مستخدم جديد';
    const recipients = await adminRecipients();
    await sendToRecipients(
      recipients,
      { title: 'طلب انضمام جديد', body: `${name} بانتظار الموافقة` },
      { type: 'pending_user', uid: event.params.uid },
    );
  },
);

// Admin approves/rejects → notify that user.
const onUserStatusChanged = onValueUpdated(
  { ref: '/app_users/{uid}/status', instance: DB_INSTANCE },
  async (event) => {
    const before = event.data.before.val();
    const after = event.data.after.val();
    if (before === after) return;

    let notification;
    if (after === 'approved') {
      notification = {
        title: 'تم قبول حسابك',
        body: 'يمكنك الآن التحكم في البوابة',
      };
    } else if (after === 'rejected') {
      notification = {
        title: 'تم رفض الطلب',
        body: 'لم تتم الموافقة على حسابك',
      };
    } else {
      return;
    }

    const recipients = await recipientsForUid(event.params.uid);
    await sendToRecipients(recipients, notification, {
      type: 'status',
      status: after,
    });
  },
);

module.exports = {
  sendEmailOtp,
  verifyEmailOtp,
  deleteUser,
  onNewPendingUser,
  onUserStatusChanged,
  // Exposed for unit tests (functions/test/otp.test.js).
  _internal: { sha256Hex, timingSafeEqualHex, generateCode, buildOtpRecord },
};
