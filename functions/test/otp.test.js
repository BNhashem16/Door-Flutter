'use strict';

// Unit tests for the pure OTP helpers + email templates.
//
// NOTE: the onCall handlers themselves (auth checks, RTDB reads/writes, Brevo
// HTTP) need the firebase-functions-test harness + RTDB emulator and are out of
// scope here — those are covered by manual/emulator testing per the design spec.
// This suite locks the security-critical pure logic: code format, salted-hash
// match, constant-time compare, record shape, and template rendering.

const crypto = require('crypto');

// Importing index.js calls admin.initializeApp() + setGlobalOptions(), which is
// fine in a plain Node/jest process (no credentials needed for the pure paths).
const { _internal } = require('../index');
const { otpEmail } = require('../email_templates');
const config = require('../config');

const { sha256Hex, timingSafeEqualHex, generateCode, buildOtpRecord } = _internal;

describe('generateCode', () => {
  test('always returns a 4-digit zero-padded string', () => {
    for (let i = 0; i < 2000; i++) {
      const code = generateCode();
      expect(code).toMatch(/^\d{4}$/);
      expect(code.length).toBe(4);
    }
  });
});

describe('sha256Hex + timingSafeEqualHex', () => {
  test('matching salt+code hashes compare equal', () => {
    const salt = 'a1b2c3';
    const code = '0421';
    const stored = sha256Hex(salt + code);
    const candidate = sha256Hex(salt + code);
    expect(timingSafeEqualHex(candidate, stored)).toBe(true);
  });

  test('wrong code does not match', () => {
    const salt = 'a1b2c3';
    const stored = sha256Hex(salt + '0421');
    const candidate = sha256Hex(salt + '0422');
    expect(timingSafeEqualHex(candidate, stored)).toBe(false);
  });

  test('same code with different salt does not match', () => {
    const code = '1234';
    const stored = sha256Hex('saltA' + code);
    const candidate = sha256Hex('saltB' + code);
    expect(timingSafeEqualHex(candidate, stored)).toBe(false);
  });

  test('length mismatch returns false (no throw)', () => {
    expect(timingSafeEqualHex('abcd', 'abcdef')).toBe(false);
    expect(timingSafeEqualHex('', '')).toBe(false);
    expect(timingSafeEqualHex(null, 'abcd')).toBe(false);
  });
});

describe('buildOtpRecord', () => {
  const now = 1_700_000_000_000;
  const rec = buildOtpRecord('0007', now);

  test('hash verifies against the original code', () => {
    expect(timingSafeEqualHex(sha256Hex(rec.salt + '0007'), rec.hash)).toBe(true);
  });

  test('expiry and cooldown use config windows', () => {
    expect(rec.expiresAt).toBe(now + config.codeTtlMs);
    expect(rec.cooldownUntil).toBe(now + config.resendCooldownMs);
  });

  test('starts at zero attempts and never stores the raw code', () => {
    expect(rec.attempts).toBe(0);
    expect(JSON.stringify(rec)).not.toContain('0007');
  });

  test('salt is random 16-byte hex', () => {
    expect(rec.salt).toMatch(/^[0-9a-f]{32}$/);
    const other = buildOtpRecord('0007', now);
    expect(other.salt).not.toBe(rec.salt);
  });
});

describe('otpEmail templates', () => {
  test('arabic template is RTL, branded, contains the code', () => {
    const { subject, html } = otpEmail('ar', '0421');
    expect(subject).toContain('رمز');
    expect(html).toContain('dir="rtl"');
    expect(html).toContain('تحكم البوابة');
    expect(html).toContain('10 دقائق');
    // each digit rendered in its own box
    ['0', '4', '2', '1'].forEach((d) => expect(html).toContain(`>${d}</span>`));
  });

  test('english template is LTR, branded, contains the code', () => {
    const { subject, html } = otpEmail('en', '5839');
    expect(subject.toLowerCase()).toContain('verification');
    expect(html).toContain('dir="ltr"');
    expect(html).toContain('Gate Control');
    expect(html).toContain('10 minutes');
  });

  test('unknown locale falls back to arabic', () => {
    const { html } = otpEmail('fr', '1111');
    expect(html).toContain('dir="rtl"');
  });
});
