import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

import '../admin/admin_screen.dart';
import '../auth/auth_service.dart';
import '../profile/profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';

class FirebaseUpdateScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final AuthService authService;
  final bool isAdmin;
  final String userName;

  const FirebaseUpdateScreen({
    Key? key,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.authService,
    this.isAdmin = false,
    this.userName = '',
  }) : super(key: key);

  @override
  _FirebaseUpdateScreenState createState() => _FirebaseUpdateScreenState();
}

class _FirebaseUpdateScreenState extends State<FirebaseUpdateScreen> {
  bool _gateStatus = false; // false = مغلق, true = مفتوح
  bool _isLoading = false;
  String _connectionStatus = 'متصل';
  Timer? _statusCheckTimer;

  final String _firebaseUrl = 'https://microiot.firebaseio.com/users/1BEy97EhEObAeP7U6s4CFM66IPr2/devices/D.json?auth=VSV5R6QkmXOT12rrR6fuawILTpJdM8GjUQhiyShM';

  @override
  void initState() {
    super.initState();
    _fetchInitialStatus();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener() {
    // فحص حالة البوابة كل 3 ثواني للحصول على تحديث شبه فوري
    _statusCheckTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      _fetchCurrentStatus();
    });
  }

  Future<void> _fetchInitialStatus() async {
    await _fetchCurrentStatus();
  }

  Future<void> _fetchCurrentStatus() async {
    try {
      final response = await http.get(Uri.parse(_firebaseUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['state'] != null) {
          setState(() {
            // تحويل ON إلى true (مفتوح) و OFF إلى false (مغلق)
            _gateStatus = data['state'] == 'ON';
            _connectionStatus = 'متصل';
          });
        }
      } else {
        setState(() {
          _connectionStatus = 'غير متصل';
        });
      }
    } catch (error) {
      setState(() {
        _connectionStatus = 'غير متصل';
      });
    }
  }

  Future<void> _toggleGate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // إرسال العكس: إذا كانت البوابة مفتوحة نرسل OFF وإذا كانت مغلقة نرسل ON
      String newState = _gateStatus ? "OFF" : "ON";

      final response = await http.put(
        Uri.parse(_firebaseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'apikey': "D",
          'changedby': "ahmed hashem",
          'state': newState,
          'name': "Door",
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'type': "Motor",
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar(newState == 'ON' ? 'تم فتح البوابة' : 'تم إغلاق البوابة');
        // تحديث الحالة المحلية فوراً
        setState(() {
          _gateStatus = newState == 'ON';
        });
      } else {
        _showErrorSnackBar('فشل في تغيير حالة البوابة');
      }
    } catch (error) {
      _showErrorSnackBar('خطأ في الاتصال: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحكم البوابة'),
        leading: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: IconButton(
            tooltip: 'الملف الشخصي',
            icon: InitialsAvatar(
              name: widget.userName,
              seed: widget.authService.currentUser?.uid ?? '',
              size: 34,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ProfileScreen(authService: widget.authService),
              ),
            ),
          ),
        ),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'إدارة المستخدمين',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AdminScreen(authService: widget.authService),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: widget.onThemeToggle,
            tooltip: widget.isDarkMode ? 'الوضع المضيء' : 'الوضع المظلم',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
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
                child: Text(_gateStatus ? 'البوابة مفتوحة' : 'البوابة مغلقة'),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _gateStatus
                    ? 'اضغط للإغلاق'
                    : 'اضغط للفتح',
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

  Widget _connectionPill(AppColors colors) {
    final connected = _connectionStatus == 'متصل';
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
            _connectionStatus,
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
        onPressed: _isLoading ? null : _toggleGate,
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
                  Icon(_gateStatus ? Icons.lock_rounded
                      : Icons.lock_open_rounded, size: 24),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Text(
                    _gateStatus ? 'إغلاق البوابة' : 'فتح البوابة',
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
                'معلومات النظام',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InfoRow(label: 'حالة الاتصال', value: _connectionStatus),
          InfoRow(
              label: 'حالة البوابة',
              value: _gateStatus ? 'مفتوحة' : 'مغلقة'),
          const InfoRow(label: 'تحديث تلقائي', value: 'كل 3 ثواني'),
        ],
      ),
    );
  }
}