import 'package:flutter/material.dart';
import 'dart:async';

import '../admin/admin_screen.dart';
import '../auth/auth_service.dart';
import '../gate/gate_service.dart';
import '../gate/gate_sound.dart';
import '../guest/guest_passes_screen.dart';
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

  /// Most recent OPEN action by this user (null = never opened).
  GateLog? _lastOpen;

  /// Count of OPEN actions by this user since local midnight.
  int _opensToday = 0;

  final GateService _gate = GateService();
  final GateSound _sound = GateSound();
  StreamSubscription<bool>? _stateSub;
  StreamSubscription<List<GateLog>>? _logsSub;

  @override
  void initState() {
    super.initState();
    _listenToGate();
    _listenToLogs();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _logsSub?.cancel();
    _gate.dispose();
    _sound.dispose();
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

  /// Live-derive the last-open record and today's open count from this user's
  /// own gate logs (owner-readable). Logs arrive newest-first.
  void _listenToLogs() {
    final uid = widget.authService.currentUser?.uid;
    if (uid == null) return;
    _logsSub = widget.authService.watchUserLogs(uid).listen((logs) {
      if (!mounted) return;
      final opens = logs.where((l) => l.action == GateAction.open).toList();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      setState(() {
        _lastOpen = opens.isEmpty ? null : opens.first;
        _opensToday = opens
            .where((l) => DateTime.fromMillisecondsSinceEpoch(l.timestamp)
                .isAfter(midnight))
            .length;
      });
    }, onError: (_) {/* non-fatal: activity card just stays empty */});
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
      // Audible + haptic feedback matching the new state (fire-and-forget).
      unawaited(_sound.play(open: newOpen));
      if (!mounted) return;
      _showGateSnack(open: newOpen);
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

  /// Designed result toast for a successful open/close.
  void _showGateSnack({required bool open}) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final s = AppStrings.of(context);
    _showStyledSnack(
      accent: open ? colors.success : colors.danger,
      icon: open ? Icons.lock_open_rounded : Icons.lock_rounded,
      title: open ? s.gateOpened : s.gateClosedMsg,
      subtitle: open ? s.tapToClose : s.tapToOpen,
    );
  }

  void _showErrorSnackBar(String message) {
    final colors = Theme.of(context).extension<AppColors>()!;
    _showStyledSnack(
      accent: colors.danger,
      icon: Icons.error_outline_rounded,
      title: message,
    );
  }

  /// Shared card-style floating snackbar: accent rail + icon badge + text.
  /// Adapts to light/dark via the theme surface tokens.
  void _showStyledSnack({
    required Color accent,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: const Duration(milliseconds: 2200),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        content: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(width: 5, color: accent),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: AppSpacing.md,
                        top: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
              if (widget.userName.trim().isNotEmpty) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    s.greeting(widget.userName.trim()),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
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
              _activityCard(theme, colorScheme, colors),
              const SizedBox(height: AppSpacing.md),
              _guestPassEntry(theme, colorScheme),
              const SizedBox(height: AppSpacing.md),
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

  /// Activity card: last gate opening (relative + absolute) and today's count.
  Widget _activityCard(
      ThemeData theme, ColorScheme colorScheme, AppColors colors) {
    final s = AppStrings.of(context);
    final last = _lastOpen;
    final lastValue =
        last == null ? s.neverOpened : _relativeTime(last.timestamp, s);

    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(s.activityTitle, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _statTile(
                    theme: theme,
                    colors: colors,
                    icon: Icons.lock_open_rounded,
                    accent: colors.success,
                    label: s.lastOpenLabel,
                    value: lastValue,
                    caption:
                        last == null ? null : _formatTimestamp(last.timestamp),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _statTile(
                    theme: theme,
                    colors: colors,
                    icon: Icons.today_rounded,
                    accent: colorScheme.primary,
                    label: s.opensTodayLabel,
                    value: '$_opensToday',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required ThemeData theme,
    required AppColors colors,
    required IconData icon,
    required Color accent,
    required String label,
    required String value,
    String? caption,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelSmall),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption,
              style: theme.textTheme.labelSmall,
              textDirection: TextDirection.ltr,
            ),
          ],
        ],
      ),
    );
  }

  /// Coarse relative time ("Just now", "5m ago", "3h ago", "2d ago").
  String _relativeTime(int ms, AppStrings s) {
    if (ms == 0) return s.neverOpened;
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return s.timeJustNow;
    if (diff.inMinutes < 60) return s.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return s.timeHoursAgo(diff.inHours);
    return s.timeDaysAgo(diff.inDays);
  }

  /// Locale-neutral `yyyy/MM/dd HH:mm` from epoch ms.
  String _formatTimestamp(int ms) {
    if (ms == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  /// Tappable entry to the resident's guest-pass manager. Visible to every
  /// approved user (only approved users reach this screen).
  Widget _guestPassEntry(ThemeData theme, ColorScheme colorScheme) {
    final s = AppStrings.of(context);
    return SectionCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GuestPassesScreen(
              authService: widget.authService,
              userName: widget.userName,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.qr_code_2_rounded,
                    color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.guestPassesTitle,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(s.guestPassesSubtitle,
                        style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
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
