/// Outcome of an OTP send/verify call. A closed, UI-friendly set of cases so
/// screens can `switch` exhaustively over the result.
sealed class OtpResult {
  const OtpResult();
}

/// Code sent, or verified successfully.
final class OtpOk extends OtpResult {
  const OtpOk();
}

/// Wrong code; [attemptsLeft] tries remain before lockout.
final class OtpWrong extends OtpResult {
  const OtpWrong(this.attemptsLeft);
  final int attemptsLeft;
}

/// No active code, or it expired — the user must request a new one.
final class OtpExpired extends OtpResult {
  const OtpExpired();
}

/// Too many wrong attempts; the code is locked until a new one is requested.
final class OtpTooMany extends OtpResult {
  const OtpTooMany();
}

/// Resend rejected by the cooldown; [seconds] left until allowed.
final class OtpCooldown extends OtpResult {
  const OtpCooldown(this.seconds);
  final int seconds;
}

/// Network/unexpected failure (e.g. the email could not be sent, or EmailJS
/// is not configured).
final class OtpError extends OtpResult {
  const OtpError();
}
