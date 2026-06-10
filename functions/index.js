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

module.exports = {
  sendEmailOtp,
  verifyEmailOtp,
  deleteUser,
  // Exposed for unit tests (functions/test/otp.test.js).
  _internal: { sha256Hex, timingSafeEqualHex, generateCode, buildOtpRecord },
};
