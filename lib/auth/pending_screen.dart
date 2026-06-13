import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';
import '../widgets/language_toggle_button.dart';
import '../widgets/section_card.dart';
import 'auth_service.dart';

/// Shown to authenticated users whose account is not yet approved.
///
/// `rejected` users see a terminal message. `pending` users get an access-code
/// redeem form: enter the admin-issued code → Worker flips status to approved →
/// [AuthGate]'s profile stream routes onward automatically.
class PendingScreen extends StatefulWidget {
  const PendingScreen({
    super.key,
    required this.authService,
    required this.rejected,
  });

  final AuthService authService;
  final bool rejected;

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  final _codeCtrl = TextEditingController();
  bool _redeeming = false;
  bool _requesting = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  String _errorText(AppStrings s, AccessRedeemResult r) => switch (r) {
        AccessRedeemResult.expired => s.codeExpired,
        AccessRedeemResult.used => s.codeUsed,
        AccessRedeemResult.networkError => s.codeNetworkError,
        AccessRedeemResult.notPending ||
        AccessRedeemResult.invalid =>
          s.codeInvalid,
        AccessRedeemResult.ok => '',
      };

  Future<void> _redeem() async {
    final s = AppStrings.of(context);
    final uid = widget.authService.currentUser?.uid;
    final code = _codeCtrl.text.trim();
    if (uid == null || code.isEmpty) return;
    setState(() => _redeeming = true);
    try {
      final result =
          await widget.authService.redeemAccessCode(uid: uid, code: code);
      if (!mounted) return;
      // On success the AuthGate stream routes away; just toast on failure.
      if (result != AccessRedeemResult.ok) {
        showToast(context, _errorText(s, result));
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  Future<void> _requestCode() async {
    final s = AppStrings.of(context);
    setState(() => _requesting = true);
    try {
      await widget.authService.requestAccessCode();
      if (!mounted) return;
      showToast(context, s.codeRequested);
    } on Exception {
      if (!mounted) return;
      showToast(context, s.codeRequestError);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final rejected = widget.rejected;
    final icon = rejected ? Icons.block : Icons.hourglass_top;
    final color = rejected ? Colors.red : Colors.orange;
    final title = rejected ? s.rejectedTitle : s.pendingTitle;
    final body = rejected ? s.rejectedBody : s.pendingBody;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 96, color: color),
                    const SizedBox(height: AppSpacing.lg),
                    Text(title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(body, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xl),
                    if (!rejected) ...[
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.pendingStepsTitle,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _StepRow(number: 1, text: s.pendingStep1),
                            _StepRow(number: 2, text: s.pendingStep2),
                            _StepRow(number: 3, text: s.pendingStep3),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _codeCtrl,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: 8,
                        decoration: InputDecoration(
                          labelText: s.accessCodeLabel,
                          counterText: '',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _redeeming ? null : _redeem,
                          child: _redeeming
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(s.activateCodeButton),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: _requesting ? null : _requestCode,
                        child: Text(s.requestCodeButton),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
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

/// Numbered instruction row used in the pending-screen activation guide.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
