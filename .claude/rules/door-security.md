# Door — Security Rules (project)

Extends `~/.claude/rules/dart/security.md` + `common/security.md` with Door specifics.
The RTDB security rules in `database.rules.json` are the source of truth — client code must
not attempt writes the rules reject.

## Firebase RTDB write constraints (`/app_users/{uid}`)

- **Owner update may change only** `name`, `apartment`, `bio`, `activeDevice`.
- **Owner must NOT write** `role`, `status`, `email`, `createdAt` on update — rules reject the
  entire update if these differ from stored values.
- `role`/`status` changes are **admin-only** (admin path in rules).
- On owner **create**: must be `role=user`, `status=pending`. Don't let a client self-register
  as admin or pre-approved.
- Reads: whole `/app_users` list is admin-only; a single `/app_users/$uid` is owner-or-admin.

## Single-device session

- `activeDevice` is owner-writable, stamped only in `AuthService.signIn`. Don't expose it as an
  editable profile field.

## Secrets / config

- No hardcoded API keys/tokens in Dart. `firebase_options.dart` is generated config (Firebase
  client keys are not secrets, but never add server secrets to the client).
- RTDB URL `https://microiot.firebaseio.com` is intentional config, kept in `AuthService`.

## General mobile

- Enforce HTTPS for any gate-control HTTP calls (`http` package) — no cleartext in release.
- Validate user input before write (email/password/profile fields).
- Don't log tokens/passwords/PII (`print`/`debugPrint`).
- Run `flutter analyze` clean before any commit touching auth, rules, or data writes.

## Changing the rules

- Edit `database.rules.json`, then `firebase deploy --only database`.
- After loosening any rule, re-check no privilege-escalation path opens (owner writing role/status).
