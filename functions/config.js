'use strict';

// Static (non-secret) configuration for the OTP Cloud Functions.
// The Brevo API key is NOT here — it lives in Secret Manager via
// `firebase functions:secrets:set BREVO_API_KEY` and is read with
// defineSecret('BREVO_API_KEY') in index.js.

module.exports = {
  // Functions region. The Flutter client MUST target the same region
  // (FirebaseFunctions.instanceFor(region: 'us-central1')).
  region: 'us-central1',

  // Brevo single verified sender. Set this to the exact email you verified
  // in Brevo (Senders & IP > Senders). Until verified, sends will fail.
  senderEmail: 'hashem.codes@gmail.com',
  senderName: 'Gate Control',

  // OTP policy (keep in sync with the design spec).
  codeTtlMs: 10 * 60 * 1000, // 10 minutes
  resendCooldownMs: 60 * 1000, // 60 seconds
  maxAttempts: 5,
};
