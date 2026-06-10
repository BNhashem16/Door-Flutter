# Door — Guest-pass redeem Worker (free, Cloudflare)

Replaces the `guestPass` Firebase Cloud Function so guest redeem links work on
the **free Firebase Spark plan** (no Blaze required). Renders the same Arabic
page and opens the gate via the RTDB REST API.

## Why

Firebase Cloud Functions need the paid Blaze plan. This Worker runs on
Cloudflare's free tier (100k requests/day) and talks to Realtime Database over
its REST API, authenticated with a **service account** — the same Admin
credential Firebase recommends (legacy database secrets are deprecated).

The Worker signs an RS256 JWT with the service-account key (Web Crypto),
exchanges it for a short-lived Google OAuth2 access token, and calls RTDB with
`Authorization: Bearer`. Authenticated as the service account, REST writes
bypass security rules exactly like the Admin SDK. The token is cached in the
isolate and auto-refreshed.

## One-time setup

### 1. Get the service-account key

Firebase Console → ⚙ Project settings → **Service accounts** →
**Generate new private key** → downloads a JSON file. It contains
`client_email` and `private_key`. Treat as a credential — never commit it.

### 2. Install Wrangler + log in (free account, no card)

```bash
npm install -g wrangler
wrangler login          # opens browser, free Cloudflare signup
```

### 3. Deploy

```bash
cd cloudflare/guest-worker
wrangler secret put SERVICE_ACCOUNT   # paste the ENTIRE JSON file contents, then Enter
wrangler deploy
```

Paste the whole JSON (one shot — the value can be multi-line; finish with
Enter). Wrangler prints the URL, e.g.
`https://door-gate.<your-subdomain>.workers.dev`.

### 4. Point the app at the Worker

In `lib/guest/guest_service.dart` set `_redeemBase` to the Worker URL:

```dart
static const String _redeemBase =
    'https://door-gate.<your-subdomain>.workers.dev';
```

Rebuild the app. New guest links resolve to the Worker and open the gate.

## Local test

```bash
# put the JSON at .dev.vars as SERVICE_ACCOUNT='{...}' for local dev, then:
wrangler dev
# open http://127.0.0.1:8787/?u=<ownerUid>&c=<token>
```

## Notes

- Reuses the exact validators + HTML from the original Cloud Function.
- `usedCount` bump is atomic via RTDB REST **ETag compare-and-swap** (retries on
  412), so double-spend is prevented without `firebase-admin` transactions.
- Gate write shape mirrors `functions/config.js` / `gate_service.dart`.
- No deprecated legacy database secret — uses the recommended service-account
  OAuth2 flow.
