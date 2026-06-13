import { test } from 'node:test';
import assert from 'node:assert/strict';
import { accessInvalidReason } from '../src/access_validator.mjs';

const future = 10_000;
const okRec = { code: 'k7m2p4qx', expiresAt: future, used: false };
const pending = { status: 'pending' };

test('valid pending redemption returns null', () => {
  assert.equal(accessInvalidReason(okRec, pending, 'k7m2p4qx', 0), null);
});

test('missing record is invalid', () => {
  assert.equal(accessInvalidReason(null, pending, 'k7m2p4qx', 0), 'invalid');
});

test('wrong code is invalid', () => {
  assert.equal(accessInvalidReason(okRec, pending, 'wrong123', 0), 'invalid');
});

test('used code is used', () => {
  assert.equal(
    accessInvalidReason({ ...okRec, used: true }, pending, 'k7m2p4qx', 0),
    'used',
  );
});

test('expired code is expired', () => {
  assert.equal(
    accessInvalidReason({ ...okRec, expiresAt: 5 }, pending, 'k7m2p4qx', 10),
    'expired',
  );
});

test('approved/rejected profile is not_pending', () => {
  assert.equal(
    accessInvalidReason(okRec, { status: 'rejected' }, 'k7m2p4qx', 0),
    'not_pending',
  );
  assert.equal(accessInvalidReason(okRec, null, 'k7m2p4qx', 0), 'not_pending');
});
