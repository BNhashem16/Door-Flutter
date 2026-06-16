'use strict';

// Door — Guest-pass redeem endpoint, ported from the `guestPass` Firebase
// Cloud Function to a free Cloudflare Worker (Firebase Spark plan, no Blaze).
//
// A resident writes /guest_passes/{ownerUid}/{token} from the app. The visitor
// opens the redeem link in any browser; this Worker renders a themed Arabic
// page and, on submit, atomically bumps `usedCount` (RTDB REST ETag
// compare-and-swap → double-spend safe) and writes `state:ON` to the gate node.
// The visitor is unauthenticated and never sees the gate device token.
//
// Auth: a Google service account (the Firebase Admin credential). The Worker
// signs an RS256 JWT with Web Crypto and exchanges it for an OAuth2 access
// token, then calls RTDB over REST with `Authorization: Bearer`. Authenticated
// as the service account, REST writes bypass security rules exactly like the
// Admin SDK — no deprecated legacy database secret. The full service-account
// JSON is injected as the Worker secret SERVICE_ACCOUNT.

// --- Static config (mirrors functions/config.js + gate_service.dart) ---------
const DB_URL = 'https://microiot.firebaseio.com';
const GATE_PATH = 'users/1BEy97EhEObAeP7U6s4CFM66IPr2/devices/D';
const GATE_API_KEY = 'D';
const GATE_DEVICE_NAME = 'Door';

const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
// `firebase.messaging` is required for the FCM HTTP v1 send endpoint used by
// the push-notification paths (guest redeem alert + push_outbox cron drain).
const SCOPE =
  'https://www.googleapis.com/auth/firebase.database ' +
  'https://www.googleapis.com/auth/firebase.messaging ' +
  'https://www.googleapis.com/auth/userinfo.email';

const GUEST_ACCENT = '2563eb'; // app blue
const GUEST_SUCCESS = '059669';
const GUEST_DANGER = 'dc2626';

// Epoch ms sentinel for a permanent (no-time-limit) pass — mirrors
// GuestPass.neverExpires in the app. Stored as expiresAt so the existing
// `now > expiresAt` check treats it as never expiring; only the rendered copy
// special-cases it.
const NEVER_EXPIRES = 4102444800000;

// --- Service-account OAuth2 (RS256 JWT → access token) -----------------------
// Cached at module scope; survives across requests within a warm isolate.
let _cachedToken = null; // { token, exp } (exp in epoch seconds)

function b64url(arrayBuffer) {
  const bytes = new Uint8Array(arrayBuffer);
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlString(str) {
  return btoa(unescape(encodeURIComponent(str)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function pemToPkcs8(pem) {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

async function getAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (_cachedToken && _cachedToken.exp - 60 > now) return _cachedToken.token;

  const sa = JSON.parse(env.SERVICE_ACCOUNT);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: sa.client_email,
    scope: SCOPE,
    aud: TOKEN_ENDPOINT,
    iat: now,
    exp: now + 3600,
  };
  const signingInput =
    `${b64urlString(JSON.stringify(header))}.${b64urlString(JSON.stringify(claim))}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signingInput),
  );
  const jwt = `${signingInput}.${b64url(sig)}`;

  const res = await fetch(TOKEN_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:
      'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwt,
  });
  if (!res.ok) throw new Error(`token exchange failed: ${res.status}`);
  const j = await res.json();
  _cachedToken = { token: j.access_token, exp: now + (j.expires_in || 3600) };
  return _cachedToken.token;
}

// --- Recurring-schedule helpers (Africa/Cairo local time) --------------------
// A recurring pass only opens on its scheduled weekdays inside the daily
// window. The window check uses Cairo wall-clock so it matches what the
// resident set in the app, independent of the visitor's device timezone.

// Map en-US weekday short names → DateTime.weekday numbering (1=Mon … 7=Sun).
const _WEEKDAY_NUM = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };

function cairoNow(now) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Africa/Cairo',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(new Date(now));
  let weekday = 1;
  let hour = 0;
  let minute = 0;
  for (const p of parts) {
    if (p.type === 'weekday') weekday = _WEEKDAY_NUM[p.value] || 1;
    else if (p.type === 'hour') hour = parseInt(p.value, 10) % 24;
    else if (p.type === 'minute') minute = parseInt(p.value, 10);
  }
  return { weekday, minutes: hour * 60 + minute };
}

function scheduleOpenNow(schedule, now) {
  if (!schedule || typeof schedule !== 'object') return false;
  const days = Array.isArray(schedule.weekdays)
    ? schedule.weekdays
    : Object.values(schedule.weekdays || {});
  const start = schedule.startMinute || 0;
  const end = schedule.endMinute || 0;
  const { weekday, minutes } = cairoNow(now);
  if (!days.includes(weekday)) return false;
  if (start <= end) return minutes >= start && minutes <= end;
  return minutes >= start || minutes <= end; // window wraps past midnight
}

// --- Pure validators (identical semantics to the Cloud Function) -------------
function passIsValid(pass, now) {
  if (!pass || typeof pass !== 'object') return false;
  if (pass.status !== 'active') return false;
  if (typeof pass.expiresAt !== 'number' || now > pass.expiresAt) return false;
  const maxUses = pass.maxUses || 0;
  const used = pass.usedCount || 0;
  if (maxUses > 0 && used >= maxUses) return false;
  // Recurring pass: also require the weekly window to be open right now.
  if (pass.recurring === true && !scheduleOpenNow(pass.schedule, now)) {
    return false;
  }
  return true;
}

function usesLeft(pass) {
  const maxUses = (pass && pass.maxUses) || 0;
  const used = (pass && pass.usedCount) || 0;
  if (maxUses <= 0) return Infinity;
  return Math.max(0, maxUses - used);
}

function isValidGuestToken(token) {
  return typeof token === 'string' && /^[a-z2-7]{8,16}$/.test(token);
}

function guestInvalidReason(pass, now) {
  if (!pass || typeof pass !== 'object') return 'not_found';
  if (pass.status === 'revoked') return 'revoked';
  if (pass.status === 'paused') return 'paused';
  if (typeof pass.expiresAt !== 'number' || now > pass.expiresAt) {
    return 'expired';
  }
  if (usesLeft(pass) <= 0) return 'used_up';
  if (pass.recurring === true && !scheduleOpenNow(pass.schedule, now)) {
    return 'closed_now';
  }
  return null;
}

// --- HTML rendering (ported verbatim) ----------------------------------------
function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatGuestExpiry(ms) {
  try {
    return new Intl.DateTimeFormat('ar-EG', {
      timeZone: 'Africa/Cairo',
      dateStyle: 'medium',
      timeStyle: 'short',
    }).format(new Date(ms));
  } catch (_) {
    return new Date(ms).toISOString();
  }
}

function guestPageShell({ title, accent, bodyHtml }) {
  return `<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<meta name="robots" content="noindex">
<title>${escapeHtml(title)}</title>
<style>
  :root { --accent:#${accent}; --soft:#${accent}24; --line:#${accent}8c; }
  * { box-sizing:border-box; }
  body { margin:0; min-height:100vh; display:flex; align-items:center;
    justify-content:center; padding:24px;
    font-family:-apple-system,"Segoe UI",Tahoma,Arial,sans-serif;
    background:#0d1117; color:#e6edf3; }
  .card { width:100%; max-width:420px; background:#161b22;
    border:1px solid #2d333b; border-radius:20px; padding:32px 24px;
    text-align:center; box-shadow:0 18px 50px rgba(0,0,0,.45); }
  .badge { width:84px; height:84px; border-radius:50%; margin:0 auto 20px;
    display:flex; align-items:center; justify-content:center; font-size:40px;
    background:var(--soft); border:2px solid var(--line); }
  h1 { font-size:22px; margin:0 0 6px; font-weight:700; }
  .label { font-size:18px; font-weight:700; color:var(--accent); margin:4px 0 16px; }
  .meta { font-size:14px; color:#8b949e; margin:6px 0; }
  .meta b { color:#e6edf3; font-weight:600; }
  form { margin-top:26px; }
  button { width:100%; border:0; border-radius:16px; padding:18px; font-size:18px;
    font-weight:700; color:#fff; background:var(--accent); cursor:pointer; }
  button:active { transform:translateY(1px); }
  .note { font-size:12px; color:#6b7280; margin-top:18px; line-height:1.6; }
</style>
</head>
<body><div class="card">${bodyHtml}</div></body>
</html>`;
}

// Arabic weekday names keyed by DateTime.weekday (1=Mon … 7=Sun).
const _AR_WEEKDAYS = {
  1: 'الإثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};

function formatSchedule(schedule) {
  const days = (
    Array.isArray(schedule.weekdays)
      ? schedule.weekdays
      : Object.values(schedule.weekdays || {})
  )
    .map((d) => _AR_WEEKDAYS[d] || '')
    .filter(Boolean)
    .join('، ');
  const two = (n) => String(n).padStart(2, '0');
  const hm = (m) => `${two(Math.floor(m / 60))}:${two(m % 60)}`;
  return `${days} · ${hm(schedule.startMinute || 0)}–${hm(schedule.endMinute || 0)}`;
}

function renderGuestValid(u, c, pass) {
  const usesLine =
    (pass.maxUses || 0) > 0
      ? `<div class="meta">المتبقي <b>${usesLeft(pass)}</b> مرة</div>`
      : `<div class="meta">عدد مرات الفتح: <b>غير محدود</b></div>`;
  const recurringLine =
    pass.recurring === true && pass.schedule
      ? `<div class="meta">المواعيد: <b>${escapeHtml(formatSchedule(pass.schedule))}</b></div>`
      : '';
  const validityLine =
    pass.recurring === true
      ? `<div class="meta">يتكرر حتى <b>${escapeHtml(formatGuestExpiry(pass.expiresAt))}</b></div>`
      : (pass.expiresAt || 0) >= NEVER_EXPIRES
        ? `<div class="meta">المدة: <b>بدون مدة</b></div>`
        : `<div class="meta">صالح حتى <b>${escapeHtml(formatGuestExpiry(pass.expiresAt))}</b></div>`;
  const body = `
    <div class="badge">🔓</div>
    <h1>دعوة لفتح البوابة</h1>
    <div class="label">${escapeHtml(pass.label || 'زائر')}</div>
    ${validityLine}
    ${recurringLine}
    ${usesLine}
    <form method="POST">
      <input type="hidden" name="u" value="${escapeHtml(u)}">
      <input type="hidden" name="c" value="${escapeHtml(c)}">
      <button type="submit">افتح البوابة</button>
    </form>
    <div class="note">شارك هذا الرابط مع الأشخاص الموثوقين فقط.</div>`;
  return guestPageShell({ title: 'فتح البوابة', accent: GUEST_ACCENT, bodyHtml: body });
}

function renderGuestInvalid(reason) {
  const copy = {
    not_found: ['تصريح غير موجود', 'هذا الرابط غير صحيح أو تم حذفه.'],
    expired: ['انتهت صلاحية التصريح', 'انتهت مدة هذا التصريح.'],
    revoked: ['تم إلغاء التصريح', 'ألغى المُضيف هذا التصريح.'],
    paused: [
      'التصريح موقوف مؤقتًا',
      'أوقف المُضيف هذا التصريح مؤقتًا. حاول لاحقًا أو تواصل معه.',
    ],
    used_up: ['تم استخدام التصريح', 'تم استخدام هذا التصريح بالكامل.'],
    closed_now: [
      'خارج وقت التصريح',
      'هذا التصريح صالح في أيام وأوقات محددة فقط. حاول في الموعد المسموح.',
    ],
    error: ['تعذّر فتح البوابة', 'حدث خطأ مؤقت. حاول مرة أخرى.'],
  };
  const [title, msg] = copy[reason] || copy.not_found;
  const body = `
    <div class="badge">⛔</div>
    <h1>${title}</h1>
    <div class="meta">${msg}</div>`;
  return guestPageShell({ title, accent: GUEST_DANGER, bodyHtml: body });
}

function renderGuestSuccess() {
  const body = `
    <div class="badge">✅</div>
    <h1>تم فتح البوابة</h1>
    <div class="meta">تفضّل بالدخول.</div>`;
  return guestPageShell({ title: 'تم الفتح', accent: GUEST_SUCCESS, bodyHtml: body });
}

// --- RTDB REST helpers (Bearer-authenticated) --------------------------------
function dbFetch(path, token, init = {}) {
  const headers = { ...(init.headers || {}), Authorization: `Bearer ${token}` };
  return fetch(`${DB_URL}/${path}.json`, { ...init, headers });
}

function htmlResponse(body, status) {
  return new Response(body, {
    status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function jsonResponse(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  });
}

// Mirror of src/access_validator.mjs (kept identical; that module is the tested
// reference). Returns an error reason or null when redemption is allowed.
function accessInvalidReason(rec, profile, code, now) {
  if (!rec || typeof rec !== 'object') return 'invalid';
  if (typeof code !== 'string' || rec.code !== code) return 'invalid';
  if (rec.used === true) return 'used';
  if (typeof rec.expiresAt !== 'number' || now > rec.expiresAt) return 'expired';
  if (!profile || typeof profile !== 'object' || profile.status !== 'pending') {
    return 'not_pending';
  }
  return null;
}

// POST /access {uid, code} — a pending user redeems an admin-issued access
// code. Validates against /access_codes/{uid} + /app_users/{uid}; on success
// flips status to approved (service-account write bypasses the owner-can't-set-
// status rule), burns the code, pushes the "approved" notice, and audits.
async function handleAccess(request, env, token) {
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse({ error: 'invalid' }, 400);
  }
  const uid = (body.uid || '').toString();
  const code = (body.code || '').toString().trim().toLowerCase();
  if (!uid || !/^[a-z2-7]{8}$/.test(code)) {
    return jsonResponse({ error: 'invalid' }, 400);
  }

  const recRes = await dbFetch(`access_codes/${uid}`, token);
  const profRes = await dbFetch(`app_users/${uid}`, token);
  const rec = recRes.ok ? await recRes.json() : null;
  const profile = profRes.ok ? await profRes.json() : null;

  const reason = accessInvalidReason(rec, profile, code, Date.now());
  if (reason) return jsonResponse({ error: reason }, 200);

  // Approve + burn the code.
  await dbFetch(`app_users/${uid}/status`, token, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify('approved'),
  });
  await dbFetch(`access_codes/${uid}/used`, token, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: 'true',
  });

  const name = (profile && profile.name) || '';
  await pushToUser(
    env,
    token,
    uid,
    _PUSH_COPY.approved[0],
    _PUSH_COPY.approved[1],
    'approved',
  );
  await dbFetch('audit_logs', token, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      actorUid: uid,
      actorName: name,
      action: 'code_redeemed',
      targetUid: uid,
      targetName: name,
      timestamp: Date.now(),
    }),
  }).catch(() => {});

  return jsonResponse({ ok: true }, 200);
}

// Atomic bump via ETag compare-and-swap. Returns 'ok' | reason-string.
async function redeem(u, c, token, env) {
  const path = `guest_passes/${u}/${c}`;

  for (let attempt = 0; attempt < 3; attempt++) {
    const getRes = await dbFetch(path, token, {
      headers: { 'X-Firebase-ETag': 'true' },
    });
    if (!getRes.ok) return 'error';
    const etag = getRes.headers.get('ETag');
    const pass = await getRes.json();
    const now = Date.now();

    if (!passIsValid(pass, now)) {
      return guestInvalidReason(pass, now) || 'expired';
    }

    const next = { ...pass, usedCount: (pass.usedCount || 0) + 1 };
    const putRes = await dbFetch(path, token, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...(etag ? { 'if-match': etag } : {}),
      },
      body: JSON.stringify(next),
    });

    if (putRes.status === 412) continue; // lost the race — re-read and retry
    if (!putRes.ok) return 'error';

    // Committed. Open the gate + write the log (best-effort log).
    const label = (pass.label || '').toString();
    const ts = Date.now();
    const gateRes = await dbFetch(GATE_PATH, token, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        apikey: GATE_API_KEY,
        changedby: `ضيف: ${label}`.slice(0, 80),
        state: 'ON',
        name: GATE_DEVICE_NAME,
        timestamp: ts,
        type: 'Motor',
      }),
    });
    if (!gateRes.ok) return 'error';

    await dbFetch(`gate_logs/${u}`, token, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: label,
        action: 'open',
        source: 'guest',
        timestamp: ts,
      }),
    }).catch(() => {});

    // Notify the host their pass was just redeemed (best-effort, non-blocking).
    await pushToUser(
      env,
      token,
      u,
      'تم فتح بوابتك',
      `${label || 'زائر'} فتح البوابة الآن.`,
      'guest',
    );

    return 'ok';
  }
  return 'error';
}

// --- FCM push (HTTP v1, service-account authenticated) -----------------------
// The same service-account access token (now scoped for firebase.messaging)
// sends notifications. Device tokens live at /fcm_tokens/{uid}/{token}=true; a
// stale token (UNREGISTERED) is pruned so the set self-heals.

function _projectId(env) {
  try {
    return JSON.parse(env.SERVICE_ACCOUNT).project_id;
  } catch (_) {
    return null;
  }
}

async function fcmSendOne(env, accessToken, deviceToken, title, body) {
  const projectId = _projectId(env);
  if (!projectId) return { ok: false, prune: false };
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title, body },
          android: {
            priority: 'high',
            notification: { channel_id: 'door_default' },
          },
        },
      }),
    },
  );
  // 404/400 → the token is unregistered/invalid; signal the caller to prune it.
  return { ok: res.ok, prune: res.status === 404 || res.status === 400 };
}

// Persist an in-app notification under /notifications/{uid} so the app's
// notification center keeps a history even if the OS push is missed/dismissed.
async function persistNotification(accessToken, uid, type, title, body) {
  await dbFetch(`notifications/${uid}`, accessToken, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      type,
      title,
      body,
      createdAt: Date.now(),
      read: false,
    }),
  }).catch(() => {});
}

// Critical notifications always send; everything else honors the user's
// per-type opt-out at /notification_prefs/{uid}/{type} (missing/true = allowed).
const _ALWAYS_SEND = new Set([
  'approved',
  'rejected',
  'ticket_resolved',
  'new_user',
  'code_request',
]);

async function prefAllows(accessToken, uid, type) {
  if (_ALWAYS_SEND.has(type)) return true;
  const res = await dbFetch(`notification_prefs/${uid}/${type}`, accessToken);
  if (!res.ok) return true;
  const v = await res.json();
  return v !== false;
}

// Notify [uid]: store the in-app record AND fan the FCM push out to every
// device token. Best-effort: never throws (callers sit in the redeem hot path /
// cron). A stale token (UNREGISTERED) is pruned so the set self-heals.
async function pushToUser(env, accessToken, uid, title, body, type = 'info') {
  try {
    if (!(await prefAllows(accessToken, uid, type))) return;
    await persistNotification(accessToken, uid, type, title, body);
    const res = await dbFetch(`fcm_tokens/${uid}`, accessToken);
    if (!res.ok) return;
    const tokens = await res.json();
    if (!tokens || typeof tokens !== 'object') return;
    for (const deviceToken of Object.keys(tokens)) {
      const { prune } = await fcmSendOne(
        env,
        accessToken,
        deviceToken,
        title,
        body,
      );
      if (prune) {
        await dbFetch(`fcm_tokens/${uid}/${deviceToken}`, accessToken, {
          method: 'DELETE',
        }).catch(() => {});
      }
    }
  } catch (_) {
    // best-effort
  }
}

// Arabic copy for admin-enqueued pushes, keyed by outbox `type`.
const _PUSH_COPY = {
  approved: [
    'تمت الموافقة على حسابك',
    'يمكنك الآن التحكم في البوابة من التطبيق.',
  ],
  rejected: ['تم رفض طلب حسابك', 'تواصل مع إدارة المبنى لمزيد من التفاصيل.'],
  ticket_resolved: [
    'تم حل بلاغك',
    'قام المسؤول بمعالجة المشكلة التي أبلغت عنها.',
  ],
};

// All approved residents' uids — the broadcast audience. Service-account read
// bypasses the admin-only rule on /app_users.
async function approvedUids(accessToken) {
  const res = await dbFetch('app_users', accessToken);
  if (!res.ok) return [];
  const users = await res.json();
  if (!users || typeof users !== 'object') return [];
  return Object.entries(users)
    .filter(([, u]) => u && typeof u === 'object' && u.status === 'approved')
    .map(([uid]) => uid);
}

// All admins' uids — audience for moderation alerts (e.g. new_user).
async function adminUids(accessToken) {
  const res = await dbFetch('app_users', accessToken);
  if (!res.ok) return [];
  const users = await res.json();
  if (!users || typeof users !== 'object') return [];
  return Object.entries(users)
    .filter(([, u]) => u && typeof u === 'object' && u.role === 'admin')
    .map(([uid]) => uid);
}

// Drain /push_outbox, then delete each entry. Three shapes:
//  - typed  { type, targetUid }     → Worker-owned Arabic copy → one recipient
//  - broadcast { type:'broadcast', title, body } → admin copy → all residents
//  - new_user { type:'new_user', targetUid:newUid } → alert every admin
// Entries are removed after a single attempt to avoid an unbounded retry storm.
async function drainPushOutbox(env, accessToken) {
  const res = await dbFetch('push_outbox', accessToken);
  if (!res.ok) return;
  const all = await res.json();
  if (!all || typeof all !== 'object') return;
  for (const [id, item] of Object.entries(all)) {
    try {
      if (!item || typeof item !== 'object') continue;
      if (item.type === 'broadcast' && item.title) {
        const uids = await approvedUids(accessToken);
        for (const uid of uids) {
          await pushToUser(
            env,
            accessToken,
            uid,
            item.title,
            item.body || '',
            'broadcast',
          );
        }
      } else if (item.type === 'new_user' && item.targetUid) {
        // Auto-approved self-registration → every admin gets a review alert.
        // targetUid is the NEW user here (sender), not the recipient.
        const profRes = await dbFetch(
          `app_users/${item.targetUid}`,
          accessToken,
        );
        const prof = profRes.ok ? await profRes.json() : null;
        const name = (prof && prof.name) || 'مستخدم جديد';
        const email = (prof && prof.email) || '';
        const admins = await adminUids(accessToken);
        for (const uid of admins) {
          await pushToUser(
            env,
            accessToken,
            uid,
            'مستخدم جديد سجّل في التطبيق',
            `${name}${email ? ` (${email})` : ''} — راجع الحساب من شاشة الإدارة.`,
            'new_user',
          );
        }
      } else if (item.type === 'code_request' && item.targetUid) {
        // Pending user asked for a fresh access code → alert every admin.
        const profRes = await dbFetch(
          `app_users/${item.targetUid}`,
          accessToken,
        );
        const prof = profRes.ok ? await profRes.json() : null;
        const name = (prof && prof.name) || 'مستخدم';
        const email = (prof && prof.email) || '';
        const admins = await adminUids(accessToken);
        for (const uid of admins) {
          await pushToUser(
            env,
            accessToken,
            uid,
            'طلب رمز دخول',
            `${name}${email ? ` (${email})` : ''} يطلب رمز دخول. أصدر رمزًا من شاشة الإدارة.`,
            'code_request',
          );
        }
      } else if (item.targetUid) {
        const copy = _PUSH_COPY[item.type];
        if (copy) {
          await pushToUser(
            env,
            accessToken,
            item.targetUid,
            copy[0],
            copy[1],
            item.type,
          );
        }
      }
    } finally {
      await dbFetch(`push_outbox/${id}`, accessToken, {
        method: 'DELETE',
      }).catch(() => {});
    }
  }
}

// --- Admin gate-activity monitor ---------------------------------------------
// When the admin enables /app_config/gateAlerts, every gate open/close (any
// source: app, widget, guest) pushes every admin a clear Arabic alert. The cron
// scans /gate_logs since a cursor so it catches all sources with no client
// change. The acting admin is not alerted about their own action.

const _GATE_SOURCE_AR = {
  app: 'عبر التطبيق',
  widget: 'عبر الأداة',
  guest: 'تصريح ضيف',
};

// Build the Arabic [title, body] for one gate log row.
function gateActivityCopy(log) {
  const name = (log && log.name ? String(log.name) : '').trim() || 'مستخدم';
  const opened = log && log.action === 'open';
  const src = log ? _GATE_SOURCE_AR[log.source] : undefined;
  const tail = src ? ` • ${src}` : '';
  return opened
    ? ['🚪 تم فتح البوابة', `${name} فتح البوابة${tail}`]
    : ['🔒 تم إغلاق البوابة', `${name} أغلق البوابة${tail}`];
}

async function readGateCursor(accessToken) {
  const res = await dbFetch('gate_alert_cursor', accessToken);
  if (!res.ok) return null;
  const v = await res.json();
  return typeof v === 'number' ? v : null;
}

async function setGateCursor(accessToken, value) {
  await dbFetch('gate_alert_cursor', accessToken, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(value),
  }).catch(() => {});
}

async function scanGateActivity(env, accessToken) {
  try {
    const cfgRes = await dbFetch('app_config/gateAlerts', accessToken);
    const enabled = cfgRes.ok ? (await cfgRes.json()) === true : false;
    const now = Date.now();

    // Disabled → keep the cursor at ~now so re-enabling never replays history.
    if (!enabled) {
      await setGateCursor(accessToken, now);
      return;
    }

    const cursor = await readGateCursor(accessToken);
    // First enable (no cursor) → start fresh from now, don't blast old logs.
    if (cursor === null) {
      await setGateCursor(accessToken, now);
      return;
    }

    const logsRes = await dbFetch('gate_logs', accessToken);
    if (!logsRes.ok) return;
    const byUser = await logsRes.json();
    if (!byUser || typeof byUser !== 'object') return;

    // Flatten to {actorUid, log}, keep rows newer than the cursor, sort ascending.
    const fresh = [];
    for (const [actorUid, rows] of Object.entries(byUser)) {
      if (!rows || typeof rows !== 'object') continue;
      for (const log of Object.values(rows)) {
        if (!log || typeof log !== 'object') continue;
        const ts = typeof log.timestamp === 'number' ? log.timestamp : 0;
        if (ts > cursor) fresh.push({ actorUid, log, ts });
      }
    }
    if (fresh.length === 0) return;

    fresh.sort((a, b) => a.ts - b.ts);
    // Bound a burst; still advance the cursor past everything seen this tick.
    const maxTs = fresh[fresh.length - 1].ts;
    const batch = fresh.slice(-50);

    const admins = await adminUids(accessToken);
    for (const { actorUid, log } of batch) {
      const [title, body] = gateActivityCopy(log);
      // A guest open is the guest's action, logged under the host's uid — alert
      // every admin (incl. the host-admin). Only skip self for the admin's own
      // manual open (app/widget), so they're not alerted about their own tap.
      const skipActor = log && log.source !== 'guest';
      for (const uid of admins) {
        if (skipActor && uid === actorUid) continue;
        await pushToUser(env, accessToken, uid, title, body, 'gate_activity');
      }
    }

    await setGateCursor(accessToken, maxTs);
  } catch (_) {
    // best-effort: a monitoring failure must never break the cron.
  }
}

// --- Doorbell (ring a resident) ----------------------------------------------
// A static QR at the gate points at `/ring`. A visitor with no pass taps the
// button; the Worker pushes every approved resident and records a single
// `/ring_request` the app streams. A resident approves in-app (opens the gate +
// marks the request `opened`). Throttled to one push per 30s to curb spam.
function renderRingPage(sent) {
  const body = sent
    ? `
    <div class="badge">🔔</div>
    <h1>تم إرسال الطلب</h1>
    <div class="meta">سيصلك رد من أحد سكان المبنى قريبًا.</div>`
    : `
    <div class="badge">🔔</div>
    <h1>طلب فتح الباب</h1>
    <div class="meta">اضغط لإرسال تنبيه إلى سكان المبنى لفتح الباب لك.</div>
    <form method="POST">
      <button type="submit">اطلب فتح الباب</button>
    </form>
    <div class="note">يصل طلبك إلى السكان المصرّح لهم فقط.</div>`;
  return guestPageShell({
    title: 'طلب فتح الباب',
    accent: GUEST_ACCENT,
    bodyHtml: body,
  });
}

async function handleRing(env, accessToken) {
  const now = Date.now();
  // Throttle: if a pending ring younger than 30s exists, don't re-push/re-write.
  const cur = await dbFetch('ring_request', accessToken);
  if (cur.ok) {
    const r = await cur.json();
    if (
      r &&
      r.status === 'pending' &&
      typeof r.createdAt === 'number' &&
      now - r.createdAt < 30000
    ) {
      return;
    }
  }
  await dbFetch('ring_request', accessToken, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status: 'pending', createdAt: now }),
  }).catch(() => {});
  const uids = await approvedUids(accessToken);
  for (const uid of uids) {
    await pushToUser(
      env,
      accessToken,
      uid,
      'طلب فتح الباب 🔔',
      'يوجد شخص عند البوابة يطلب الدخول.',
      'ring',
    );
  }
}

// --- Worker entry ------------------------------------------------------------
export default {
  // Cron (every minute, see wrangler.toml) drains the admin push outbox so an
  // approval/rejection/ticket-resolved notification reaches a user even when
  // their app is closed — the FCM receive stack already exists in the app.
  async scheduled(event, env, ctx) {
    if (!env.SERVICE_ACCOUNT) return;
    let token;
    try {
      token = await getAccessToken(env);
    } catch (_) {
      return;
    }
    await drainPushOutbox(env, token);
    await scanGateActivity(env, token);
  },

  async fetch(request, env) {
    if (!env.SERVICE_ACCOUNT) return htmlResponse(renderGuestInvalid('error'), 500);

    const url = new URL(request.url);

    // Doorbell: `/ring` — visitor requests that a resident open the gate.
    if (url.pathname.endsWith('/ring')) {
      let token;
      try {
        token = await getAccessToken(env);
      } catch (_) {
        return htmlResponse(renderGuestInvalid('error'), 500);
      }
      if (request.method === 'POST') {
        await handleRing(env, token);
        return htmlResponse(renderRingPage(true), 200);
      }
      return htmlResponse(renderRingPage(false), 200);
    }

    // Access-code redeem (in-app JSON API): pending user → approved.
    if (url.pathname.endsWith('/access')) {
      if (request.method !== 'POST') {
        return jsonResponse({ error: 'invalid' }, 405);
      }
      let token;
      try {
        token = await getAccessToken(env);
      } catch (_) {
        return jsonResponse({ error: 'error' }, 500);
      }
      return handleAccess(request, env, token);
    }

    let u = url.searchParams.get('u') || '';
    let c = url.searchParams.get('c') || '';

    if (request.method === 'POST') {
      const ct = request.headers.get('content-type') || '';
      if (ct.includes('application/x-www-form-urlencoded')) {
        const form = await request.formData();
        u = (form.get('u') || u).toString();
        c = (form.get('c') || c).toString();
      }
    }

    if (!u || !isValidGuestToken(c)) {
      return htmlResponse(renderGuestInvalid('not_found'), 400);
    }

    let token;
    try {
      token = await getAccessToken(env);
    } catch (_) {
      return htmlResponse(renderGuestInvalid('error'), 500);
    }

    // GET → render the page for the current pass state.
    if (request.method !== 'POST') {
      const res = await dbFetch(`guest_passes/${u}/${c}`, token);
      if (!res.ok) return htmlResponse(renderGuestInvalid('error'), 500);
      const pass = await res.json();
      const now = Date.now();
      if (!passIsValid(pass, now)) {
        return htmlResponse(
          renderGuestInvalid(guestInvalidReason(pass, now) || 'not_found'),
          pass ? 200 : 404,
        );
      }
      return htmlResponse(renderGuestValid(u, c, pass), 200);
    }

    // POST → atomic redeem.
    const result = await redeem(u, c, token, env);
    if (result === 'ok') return htmlResponse(renderGuestSuccess(), 200);
    return htmlResponse(renderGuestInvalid(result), 200);
  },
};
