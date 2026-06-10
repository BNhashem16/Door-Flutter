'use strict';

// Locale-matched OTP email templates. Inline CSS only — no external
// stylesheet, no JS — for maximum email-client compatibility. Every send is
// multipart: a styled HTML part PLUS a plain-text part (improves deliverability
// and spam score; HTML-only mail scores worse).
//
// otpEmail(locale, code) -> { subject, html, text }
//   locale: 'ar' (RTL) | 'en' (LTR); anything else falls back to 'ar'.
//   code:   4-digit string, e.g. "0421".

const BRAND = {
  ar: 'تحكم البوابة',
  en: 'Gate Control',
};

const COLORS = {
  pageBg: '#eef2f6', // soft neutral page backdrop
  card: '#ffffff',
  headerBg: '#1d4ed8', // blue-700
  text: '#0f172a',
  muted: '#64748b',
  accent: '#2563eb',
  codeBg: '#f1f5f9',
  codeText: '#1d4ed8',
  border: '#e2e8f0',
  footerBg: '#f8fafc',
};

// Hidden preview text shown by inbox clients before the email is opened.
// A meaningful preheader avoids the "empty preview" spam signal.
function preheader(text) {
  return (
    `<div style="display:none;max-height:0;overflow:hidden;opacity:0;` +
    `mso-hide:all;font-size:1px;line-height:1px;color:${COLORS.pageBg};">` +
    `${text}</div>`
  );
}

// Single centered code block: spaced large digits, monospace, copy-friendly.
function codeBlock(code) {
  const spaced = String(code).split('').join('&nbsp;&nbsp;');
  return (
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0">` +
    `<tr><td align="center" style="padding:8px 0 4px;">` +
    `<div style="display:inline-block;padding:18px 32px;background:${COLORS.codeBg};` +
    `border:1px solid ${COLORS.border};border-radius:14px;direction:ltr;">` +
    `<span style="font-family:'Courier New',Consolas,monospace;font-size:40px;` +
    `font-weight:700;letter-spacing:4px;color:${COLORS.codeText};">${spaced}</span>` +
    `</div></td></tr></table>`
  );
}

function shell({ dir, lang, brand, pre, body }) {
  const align = dir === 'rtl' ? 'right' : 'left';
  return (
    `<!DOCTYPE html><html lang="${lang}" dir="${dir}">` +
    `<head><meta charset="utf-8">` +
    `<meta name="viewport" content="width=device-width,initial-scale=1">` +
    `<meta name="color-scheme" content="light only">` +
    `</head>` +
    `<body style="margin:0;padding:0;background:${COLORS.pageBg};">` +
    preheader(pre) +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" ` +
    `style="background:${COLORS.pageBg};padding:32px 12px;">` +
    `<tr><td align="center">` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" ` +
    `style="max-width:480px;background:${COLORS.card};border:1px solid ${COLORS.border};` +
    `border-radius:18px;overflow:hidden;` +
    `font-family:'Segoe UI',Tahoma,Arial,sans-serif;">` +
    // header
    `<tr><td style="background:${COLORS.headerBg};padding:22px 24px;text-align:center;">` +
    `<span style="color:#ffffff;font-size:21px;font-weight:700;letter-spacing:0.3px;">` +
    `🔐&nbsp;&nbsp;${brand}</span></td></tr>` +
    // body
    `<tr><td style="padding:30px 28px 24px;color:${COLORS.text};` +
    `direction:${dir};text-align:${align};">${body}</td></tr>` +
    // footer
    `<tr><td style="background:${COLORS.footerBg};border-top:1px solid ${COLORS.border};` +
    `padding:16px 24px;text-align:center;">` +
    `<span style="font-size:12px;color:${COLORS.muted};">${brand}</span>` +
    `</td></tr>` +
    `</table></td></tr></table></body></html>`
  );
}

function arabicHtml(code) {
  const body =
    `<p style="margin:0 0 6px;font-size:20px;font-weight:700;">رمز التحقق</p>` +
    `<p style="margin:0 0 4px;font-size:15px;color:${COLORS.muted};line-height:1.8;">` +
    `استخدم الرمز التالي لتأكيد بريدك الإلكتروني داخل التطبيق:</p>` +
    codeBlock(code) +
    `<p style="margin:6px 0 0;font-size:14px;color:${COLORS.muted};line-height:1.8;text-align:center;">` +
    `ينتهي هذا الرمز خلال <strong style="color:${COLORS.text};">10 دقائق</strong>.</p>` +
    `<hr style="border:none;border-top:1px solid ${COLORS.border};margin:24px 0;">` +
    `<p style="margin:0;font-size:13px;color:${COLORS.muted};line-height:1.8;">` +
    `لم تطلب هذا الرمز؟ يمكنك تجاهل هذه الرسالة بأمان — لن يتغيّر أي شيء في حسابك.</p>`;
  return shell({
    dir: 'rtl',
    lang: 'ar',
    brand: BRAND.ar,
    pre: `رمز التحقق الخاص بك من ${BRAND.ar}`,
    body,
  });
}

function englishHtml(code) {
  const body =
    `<p style="margin:0 0 6px;font-size:20px;font-weight:700;">Verification code</p>` +
    `<p style="margin:0 0 4px;font-size:15px;color:${COLORS.muted};line-height:1.8;">` +
    `Use the code below to confirm your email address in the app:</p>` +
    codeBlock(code) +
    `<p style="margin:6px 0 0;font-size:14px;color:${COLORS.muted};line-height:1.8;text-align:center;">` +
    `This code expires in <strong style="color:${COLORS.text};">10 minutes</strong>.</p>` +
    `<hr style="border:none;border-top:1px solid ${COLORS.border};margin:24px 0;">` +
    `<p style="margin:0;font-size:13px;color:${COLORS.muted};line-height:1.8;">` +
    `Didn't request this code? You can safely ignore this email — nothing will change.</p>`;
  return shell({
    dir: 'ltr',
    lang: 'en',
    brand: BRAND.en,
    pre: `Your ${BRAND.en} verification code`,
    body,
  });
}

function arabicText(code) {
  return (
    `${BRAND.ar}\n\n` +
    `رمز التحقق الخاص بك: ${code}\n\n` +
    `استخدم هذا الرمز لتأكيد بريدك الإلكتروني داخل التطبيق.\n` +
    `ينتهي الرمز خلال 10 دقائق.\n\n` +
    `إذا لم تطلب هذا الرمز، تجاهل هذه الرسالة بأمان.`
  );
}

function englishText(code) {
  return (
    `${BRAND.en}\n\n` +
    `Your verification code: ${code}\n\n` +
    `Use this code to confirm your email address in the app.\n` +
    `The code expires in 10 minutes.\n\n` +
    `If you didn't request this code, you can safely ignore this email.`
  );
}

function otpEmail(locale, code) {
  if (locale === 'en') {
    return {
      subject: `${BRAND.en} verification code`,
      html: englishHtml(code),
      text: englishText(code),
    };
  }
  return {
    subject: `رمز التحقق — ${BRAND.ar}`,
    html: arabicHtml(code),
    text: arabicText(code),
  };
}

module.exports = { otpEmail };
