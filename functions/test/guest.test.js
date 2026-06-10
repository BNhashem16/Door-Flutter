'use strict';

// Unit tests for the pure guest-pass validators.
//
// The onRequest handler itself (RTDB transaction, gate write, HTML render)
// needs the firebase-functions-test harness + RTDB emulator and is out of
// scope here — covered by manual/emulator testing per the design spec. This
// suite locks the security-critical pure logic: validity window, use limits,
// token format, and the reason-code mapping that drives the visitor page.

const { _internal } = require('../index');

const { passIsValid, usesLeft, isValidGuestToken, guestInvalidReason } =
  _internal;

const NOW = 1_749_500_000_000;

function pass(overrides) {
  return {
    token: 'abc23xyz45',
    label: 'أخويا',
    createdBy: 'owner1',
    createdAt: NOW - 1000,
    expiresAt: NOW + 60_000,
    maxUses: 1,
    usedCount: 0,
    status: 'active',
    ...overrides,
  };
}

describe('passIsValid', () => {
  test('active, unexpired, with a use left → valid', () => {
    expect(passIsValid(pass(), NOW)).toBe(true);
  });

  test('null / non-object → invalid', () => {
    expect(passIsValid(null, NOW)).toBe(false);
    expect(passIsValid(undefined, NOW)).toBe(false);
    expect(passIsValid('nope', NOW)).toBe(false);
  });

  test('revoked → invalid', () => {
    expect(passIsValid(pass({ status: 'revoked' }), NOW)).toBe(false);
  });

  test('expired (now > expiresAt) → invalid', () => {
    expect(passIsValid(pass({ expiresAt: NOW - 1 }), NOW)).toBe(false);
  });

  test('exactly at expiry boundary is still valid', () => {
    expect(passIsValid(pass({ expiresAt: NOW }), NOW)).toBe(true);
  });

  test('used up (usedCount >= maxUses) → invalid', () => {
    expect(passIsValid(pass({ maxUses: 1, usedCount: 1 }), NOW)).toBe(false);
    expect(passIsValid(pass({ maxUses: 3, usedCount: 3 }), NOW)).toBe(false);
  });

  test('unlimited (maxUses 0) ignores usedCount', () => {
    expect(passIsValid(pass({ maxUses: 0, usedCount: 999 }), NOW)).toBe(true);
  });

  test('missing expiresAt → invalid', () => {
    expect(passIsValid(pass({ expiresAt: undefined }), NOW)).toBe(false);
  });
});

describe('usesLeft', () => {
  test('limited pass reports the remainder', () => {
    expect(usesLeft(pass({ maxUses: 5, usedCount: 2 }))).toBe(3);
  });

  test('never negative', () => {
    expect(usesLeft(pass({ maxUses: 1, usedCount: 4 }))).toBe(0);
  });

  test('unlimited → Infinity', () => {
    expect(usesLeft(pass({ maxUses: 0, usedCount: 10 }))).toBe(Infinity);
  });

  test('null pass → Infinity (no limit defined)', () => {
    expect(usesLeft(null)).toBe(Infinity);
  });
});

describe('isValidGuestToken', () => {
  test('accepts lowercase base32, 8–16 chars', () => {
    expect(isValidGuestToken('abc23xyz')).toBe(true);
    expect(isValidGuestToken('a2b3c4d5e6f7g2h3')).toBe(true);
  });

  test('rejects wrong length', () => {
    expect(isValidGuestToken('abc23')).toBe(false);
    expect(isValidGuestToken('a2b3c4d5e6f7g2h3x')).toBe(false);
  });

  test('rejects out-of-alphabet chars (0,1,8,9, uppercase, path sep)', () => {
    expect(isValidGuestToken('abc01890')).toBe(false);
    expect(isValidGuestToken('ABC23XYZ')).toBe(false);
    expect(isValidGuestToken('abc/../xy')).toBe(false);
  });

  test('rejects non-strings', () => {
    expect(isValidGuestToken(null)).toBe(false);
    expect(isValidGuestToken(12345678)).toBe(false);
  });
});

describe('guestInvalidReason', () => {
  test('valid pass → null (no reason)', () => {
    expect(guestInvalidReason(pass(), NOW)).toBe(null);
  });

  test('missing → not_found', () => {
    expect(guestInvalidReason(null, NOW)).toBe('not_found');
  });

  test('revoked → revoked (takes priority over expiry)', () => {
    expect(guestInvalidReason(pass({ status: 'revoked' }), NOW)).toBe('revoked');
  });

  test('past window → expired', () => {
    expect(guestInvalidReason(pass({ expiresAt: NOW - 1 }), NOW)).toBe('expired');
  });

  test('limit reached → used_up', () => {
    expect(guestInvalidReason(pass({ maxUses: 1, usedCount: 1 }), NOW)).toBe(
      'used_up',
    );
  });
});
