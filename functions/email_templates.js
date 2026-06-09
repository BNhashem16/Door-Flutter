'use strict';

// Locale-matched OTP email templates. Inline CSS only — no external
// stylesheet, no JS — for maximum email-client compatibility.
//
// otpEmail(locale, code) -> { subject, html }
//   locale: 'ar' (RTL) | 'en' (LTR); anything else falls back to 'ar'.
//   code:   4-digit string, e.g. "0421".

const BRAND = {
  ar: 'تحكم البوابة',
  en: 'Gate Control',
};

const COLORS = {
  bg: '#0f172a', // slate-900 page backdrop
  card: '#ffffff',
  text: '#0f172a',
  muted: '#64748b',
  accent: '#2563eb',
  codeBg: '#eff6ff',
  border: '#e2e8f0',
};

function codeBlock(code) {
  const digits = String(code)
    .split('')
    .map(
      (d) =>
        `<span style="display:inline-block;min-width:48px;margin:0 6px;padding:14px 0;` +
        `font-size:34px;font-weight:700;letter-spacing:2px;color:${COLORS.accent};` +
        `background:${COLORS.codeBg};border:1px solid ${COLORS.border};border-radius:12px;` +
        `text-align:center;font-family:'Courier New',monospace;">${d}</span>`,
    )
    .join('');
  return `<div style="margin:28px 0;text-align:center;direction:ltr;">${digits}</div>`;
}

function shell({ dir, lang, brand, body }) {
  return (
    `<!DOCTYPE html><html lang="${lang}" dir="${dir}">` +
    `<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>` +
    `<body style="margin:0;padding:0;background:${COLORS.bg};">` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${COLORS.bg};padding:32px 12px;">` +
    `<tr><td align="center">` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:${COLORS.card};` +
    `border-radius:16px;overflow:hidden;font-family:Segoe UI,Tahoma,Arial,sans-serif;">` +
    `<tr><td style="background:${COLORS.accent};padding:20px 24px;text-align:center;">` +
    `<span style="color:#ffffff;font-size:20px;font-weight:700;">${brand}</span></td></tr>` +
    `<tr><td style="padding:28px 24px;color:${COLORS.text};direction:${dir};text-align:${dir === 'rtl' ? 'right' : 'left'};">` +
    `${body}</td></tr>` +
    `</table></td></tr></table></body></html>`
  );
}

function arabicHtml(code) {
  const body =
    `<p style="margin:0 0 8px;font-size:18px;font-weight:600;">رمز التحقق</p>` +
    `<p style="margin:0;font-size:15px;color:${COLORS.muted};line-height:1.7;">` +
    `استخدم الرمز التالي لتأكيد بريدك الإلكتروني داخل التطبيق.</p>` +
    codeBlock(code) +
    `<p style="margin:0;font-size:14px;color:${COLORS.muted};line-height:1.7;">` +
    `ينتهي هذا الرمز خلال <strong>10 دقائق</strong>.</p>` +
    `<hr style="border:none;border-top:1px solid ${COLORS.border};margin:24px 0;">` +
    `<p style="margin:0;font-size:13px;color:${COLORS.muted};line-height:1.7;">` +
    `إذا لم تطلب هذا الرمز، تجاهل هذه الرسالة بأمان.</p>`;
  return shell({ dir: 'rtl', lang: 'ar', brand: BRAND.ar, body });
}

function englishHtml(code) {
  const body =
    `<p style="margin:0 0 8px;font-size:18px;font-weight:600;">Verification code</p>` +
    `<p style="margin:0;font-size:15px;color:${COLORS.muted};line-height:1.7;">` +
    `Use the code below to confirm your email address in the app.</p>` +
    codeBlock(code) +
    `<p style="margin:0;font-size:14px;color:${COLORS.muted};line-height:1.7;">` +
    `This code expires in <strong>10 minutes</strong>.</p>` +
    `<hr style="border:none;border-top:1px solid ${COLORS.border};margin:24px 0;">` +
    `<p style="margin:0;font-size:13px;color:${COLORS.muted};line-height:1.7;">` +
    `If you didn't request this code, you can safely ignore this email.</p>`;
  return shell({ dir: 'ltr', lang: 'en', brand: BRAND.en, body });
}

function otpEmail(locale, code) {
  if (locale === 'en') {
    return { subject: `${BRAND.en} — your verification code`, html: englishHtml(code) };
  }
  return { subject: `${BRAND.ar} — رمز التحقق`, html: arabicHtml(code) };
}

module.exports = { otpEmail };
