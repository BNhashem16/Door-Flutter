import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../toast/toast_service.dart';
import '../widgets/language_toggle_button.dart';
import 'auth_service.dart';

/// Shown to a signed-in but unverified user. Collects the 4-digit OTP emailed
/// by the `sendEmailOtp` Cloud Function and verifies it via `verifyEmailOtp`.
/// On success the Function flips `/app_users/{uid}/emailVerified`, and the
/// profile stream in [AuthGate] re-routes the user forward — no polling, no
/// `onVerified` callback needed here.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.authService,
    required this.email,
  });

  final AuthService authService;
  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _codeLength = 4;
  static const _resendCooldown = 60;

  final _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final _focusNodes = List.generate(_codeLength, (_) => FocusNode());

  Timer? _cooldownTimer;
  int _cooldown = _resendCooldown;
  bool _verifying = false;

  String get _code => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    // register() already sent the first code, so start on cooldown.
    _startResendCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendCooldown([int seconds = _resendCooldown]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldown = 0);
      } else if (mounted) {
        setState(() => _cooldown--);
      }
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_code.length == _codeLength && !_code.contains(' ')) {
      _verify();
    } else {
      setState(() {}); // refresh the Verify button enabled state
    }
  }

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) {
      _focusNodes.first.requestFocus();
      setState(() {});
    }
  }

  Future<void> _verify() async {
    if (_verifying || _code.length != _codeLength) return;
    FocusScope.of(context).unfocus();
    setState(() => _verifying = true);
    try {
      final result = await widget.authService.verifyEmailOtp(_code);
      if (!mounted) return;
      final s = AppStrings.of(context);
      switch (result) {
        case OtpOk():
          showToast(context, s.verifyEmailVerified);
        // AuthGate's profile stream re-routes once emailVerified flips.
        case OtpWrong(:final attemptsLeft):
          showToast(context, s.otpWrong(attemptsLeft));
          _clearCode();
        case OtpExpired():
          showToast(context, s.otpExpired);
          _clearCode();
        case OtpTooMany():
          showToast(context, s.otpTooManyAttempts);
          _clearCode();
        case OtpCooldown(:final seconds):
          _startResendCooldown(seconds);
        case OtpError():
          showToast(context, s.unexpectedError);
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    final locale = Localizations.localeOf(context).languageCode;
    final result = await widget.authService.sendEmailOtp(locale);
    if (!mounted) return;
    final s = AppStrings.of(context);
    switch (result) {
      case OtpOk():
        showToast(context, s.otpSentToast);
        _startResendCooldown();
      case OtpCooldown(:final seconds):
        showToast(context, s.otpCooldown(seconds));
        _startResendCooldown(seconds);
      case OtpWrong() || OtpExpired() || OtpTooMany() || OtpError():
        showToast(context, s.unexpectedError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final canResend = _cooldown == 0;
    final codeComplete = _code.length == _codeLength;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mark_email_unread_outlined,
                        size: 96, color: theme.colorScheme.primary),
                    const SizedBox(height: 24),
                    Text(
                      s.verifyEmailTitle,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.verifyEmailBody(widget.email),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _codeLength; i++)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: _OtpBox(
                                controller: _controllers[i],
                                focusNode: _focusNodes[i],
                                onChanged: (v) => _onDigitChanged(i, v),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            (_verifying || !codeComplete) ? null : _verify,
                        child: _verifying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(s.verifyCodeButton,
                                style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: canResend ? _resend : null,
                        icon: const Icon(Icons.refresh),
                        label: Text(canResend
                            ? s.verifyEmailResend
                            : s.verifyEmailResendIn(_cooldown)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: widget.authService.signOut,
                      icon: const Icon(Icons.logout),
                      label: Text(s.signOut),
                    ),
                  ],
                ),
              ),
            ),
            const PositionedDirectional(
              top: 8,
              end: 8,
              child: LanguageToggleButton(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single auto-advancing digit box for the OTP code.
class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: theme.textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
        ),
        onChanged: onChanged,
      ),
    );
  }
}
