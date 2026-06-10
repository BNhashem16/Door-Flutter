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
const SCOPE =
  'https://www.googleapis.com/auth/firebase.database ' +
  'https://www.googleapis.com/auth/userinfo.email';

const GUEST_ACCENT = '2563eb'; // app blue
const GUEST_SUCCESS = '059669';
const GUEST_DANGER = 'dc2626';

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

// --- Pure validators (identical semantics to the Cloud Function) -------------
function passIsValid(pass, now) {
  if (!pass || typeof pass !== 'object') return false;
  if (pass.status !== 'active') return false;
  if (typeof pass.expiresAt !== 'number' || now > pass.expiresAt) return false;
  const maxUses = pass.maxUses || 0;
  const used = pass.usedCount || 0;
  if (maxUses > 0 && used >= maxUses) return false;
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
  if (typeof pass.expiresAt !== 'number' || now > pass.expiresAt) {
    return 'expired';
  }
  if (usesLeft(pass) <= 0) return 'used_up';
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

function renderGuestValid(u, c, pass) {
  const usesLine =
    (pass.maxUses || 0) > 0
      ? `<div class="meta">المتبقي <b>${usesLeft(pass)}</b> مرة</div>`
      : `<div class="meta">عدد مرات الفتح: <b>غير محدود</b></div>`;
  const body = `
    <div class="badge">🔓</div>
    <h1>دعوة لفتح البوابة</h1>
    <div class="label">${escapeHtml(pass.label || 'زائر')}</div>
    <div class="meta">صالح حتى <b>${escapeHtml(formatGuestExpiry(pass.expiresAt))}</b></div>
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
    used_up: ['تم استخدام التصريح', 'تم استخدام هذا التصريح بالكامل.'],
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

// Atomic bump via ETag compare-and-swap. Returns 'ok' | reason-string.
async function redeem(u, c, token) {
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

    return 'ok';
  }
  return 'error';
}

// --- Worker entry ------------------------------------------------------------
export default {
  async fetch(request, env) {
    if (!env.SERVICE_ACCOUNT) return htmlResponse(renderGuestInvalid('error'), 500);

    const url = new URL(request.url);
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
    const result = await redeem(u, c, token);
    if (result === 'ok') return htmlResponse(renderGuestSuccess(), 200);
    return htmlResponse(renderGuestInvalid(result), 200);
  },
};
