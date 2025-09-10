import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class FirebaseUpdateScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const FirebaseUpdateScreen({
    Key? key,
    required this.onThemeToggle,
    required this.isDarkMode,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تحكم البوابة',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
          ),
        ),
        backgroundColor: colorScheme.primary,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: colorScheme.onPrimary,
            ),
            onPressed: widget.onThemeToggle,
            tooltip: widget.isDarkMode ? 'الوضع المضيء' : 'الوضع المظلم',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // حالة الاتصال
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _connectionStatus == 'متصل'
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _connectionStatus == 'متصل'
                      ? Colors.green
                      : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _connectionStatus == 'متصل'
                        ? Icons.wifi
                        : Icons.wifi_off,
                    color: _connectionStatus == 'متصل'
                        ? Colors.green
                        : Colors.red,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _connectionStatus,
                    style: TextStyle(
                      color: _connectionStatus == 'متصل'
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 40),

            // أيقونة البوابة
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: _gateStatus
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _gateStatus ? Colors.green : Colors.red,
                  width: 3,
                ),
              ),
              child: Icon(
                _gateStatus ? Icons.lock_open : Icons.lock,
                size: 80,
                color: _gateStatus ? Colors.green : Colors.red,
              ),
            ),

            SizedBox(height: 30),

            // حالة البوابة
            Text(
              _gateStatus ? 'البوابة مفتوحة' : 'البوابة مغلقة',
              style: theme.textTheme.titleLarge?.copyWith(
                color: _gateStatus ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 50),

            // زر التحكم
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _toggleGate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gateStatus
                      ? Colors.red
                      : Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
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
                      _gateStatus ? Icons.lock : Icons.lock_open,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      _gateStatus ? 'إغلاق البوابة' : 'فتح البوابة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 30),

            // معلومات إضافية
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: colorScheme.primary),
                        SizedBox(width: 8),
                        Text(
                          'معلومات النظام',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildInfoRow('حالة الاتصال', _connectionStatus),
                    _buildInfoRow('حالة البوابة', _gateStatus ? 'مفتوحة' : 'مغلقة'),
                    _buildInfoRow('تحديث تلقائي', 'كل 3 ثواني'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}