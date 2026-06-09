import 'package:flutter/material.dart';
import 'dart:async';

import '../admin/admin_screen.dart';
import '../auth/auth_service.dart';
import '../gate/gate_service.dart';
import '../l10n/app_strings.dart';
import '../logs/gate_log.dart';
import '../profile/profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';

/// Connection state of the live gate stream (locale-independent).
enum _Conn { connecting, connected, disconnected }

class FirebaseUpdateScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final VoidCallback onLocaleToggle;
  final AuthService authService;
  final bool isAdmin;
  final String userName;

  const FirebaseUpdateScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.onLocaleToggle,
    required this.authService,
    this.isAdmin = false,
    this.userName = '',
  });

  @override
  State<FirebaseUpdateScreen> createState() => _FirebaseUpdateScreenState();
}

class _FirebaseUpdateScreenState extends State<FirebaseUpdateScreen> {
  bool _gateStatus = false; // false = closed, true = open
  bool _isLoading = false;
  bool _hasState = false; // first snapshot received?
  _Conn _conn = _Conn.connecting;

  final GateService _gate = GateService();
  StreamSubscription<bool>? _stateSub;

  @override
  void initState() {
    super.initState();
    _listenToGate();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _gate.dispose();
    super.dispose();
  }

  /// Continuously mirror the database: every gate change pushes here live.
  void _listenToGate() {
    _stateSub = _gate.watchState().listen(
      (open) {
        if (!mounted) return;
        setState(() {
          _gateStatus = open;
          _hasState = true;
          _conn = _Conn.connected;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _conn = _Conn.disconnected;
        });
      },
    );
  }

  Future<void> _toggleGate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Write only — the live stream reflects the new state back to the UI.
      final newOpen = await _gate.setOpen(!_gateStatus);
      final uid = widget.authService.currentUser?.uid;
      if (uid != null) {
        unawaited(widget.authService.logGateAction(
          uid: uid,
          name: widget.userName,
          action: newOpen ? GateAction.open : GateAction.close,
          source: GateSource.app,
        ));
      }
      if (!mounted) return;
      final s = AppStrings.of(context);
      _showSuccessSnackBar(newOpen ? s.gateOpened : s.gateClosedMsg);
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackBar(AppStrings.of(context).connectionError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.gateTitle),
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
          child: IconButton(
            tooltip: s.profileTooltip,
            icon: InitialsAvatar(
              name: widget.userName,
              seed: widget.authService.currentUser?.uid ?? '',
              size: 34,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(authService: widget.authService),
              ),
            ),
          ),
        ),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: s.adminTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminScreen(authService: widget.authService),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.translate),
            onPressed: widget.onLocaleToggle,
            tooltip: s.languageToggleTooltip,
          ),
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: widget.onThemeToggle,
            tooltip: widget.isDarkMode ? s.lightMode : s.darkMode,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: s.signOut,
            onPressed: widget.authService.signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            children: [
              _connectionPill(colors),
              const SizedBox(height: AppSpacing.xl),
              _heroRing(colors),
              const SizedBox(height: AppSpacing.lg),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 350),
                style: theme.textTheme.titleLarge!.copyWith(
                  color: _gateStatus ? colors.success : colors.danger,
                  fontWeight: FontWeight.bold,
                ),
                child: Text(_gateStatus ? s.gateOpen : s.gateClosed),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _gateStatus ? s.tapToClose : s.tapToOpen,
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              _toggleButton(colors),
              const SizedBox(height: AppSpacing.lg),
              _infoCard(theme, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  String _connLabel(AppStrings s) => switch (_conn) {
        _Conn.connecting => s.connecting,
        _Conn.connected => s.connected,
        _Conn.disconnected => s.disconnected,
      };

  Widget _connectionPill(AppColors colors) {
    final s = AppStrings.of(context);
    final connected = _conn == _Conn.connected;
    final c = connected ? colors.success : colors.danger;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _connLabel(s),
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroRing(AppColors colors) {
    final main = _gateStatus ? colors.success : colors.danger;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      width: 210,
      height: 210,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            main.withValues(alpha: 0.20),
            main.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: main.withValues(alpha: 0.55), width: 2),
        boxShadow: [
          BoxShadow(
            color: main.withValues(alpha: _gateStatus ? 0.35 : 0.15),
            blurRadius: _gateStatus ? 44 : 20,
            spreadRadius: _gateStatus ? 2 : 0,
          ),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            _gateStatus ? Icons.lock_open_rounded : Icons.lock_rounded,
            key: ValueKey(_gateStatus),
            size: 80,
            color: main,
          ),
        ),
      ),
    );
  }

  Widget _toggleButton(AppColors colors) {
    // Button reflects the ACTION: close when open, open when closed.
    final action = _gateStatus ? colors.danger : colors.success;
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: _isLoading
            ? null
            : [
                BoxShadow(
                  color: action.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: (_isLoading || !_hasState) ? null : _toggleGate,
        style: ElevatedButton.styleFrom(
          backgroundColor: action,
          foregroundColor: Colors.white,
          disabledBackgroundColor: action.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      _gateStatus
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      size: 24),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Text(
                    _gateStatus
                        ? AppStrings.of(context).closeGate
                        : AppStrings.of(context).openGate,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _infoCard(ThemeData theme, ColorScheme colorScheme) {
    final s = AppStrings.of(context);
    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                s.systemInfo,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InfoRow(label: s.connectionStatusLabel, value: _connLabel(s)),
          InfoRow(
              label: s.gateStatusLabel,
              value: _gateStatus ? s.stateOpen : s.stateClosed),
          InfoRow(label: s.syncLabel, value: s.syncLive),
        ],
      ),
    );
  }
}
