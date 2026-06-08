import 'package:home_widget/home_widget.dart';

import 'gate_service.dart';

/// Android provider class name (package + class). Must match the Kotlin
/// AppWidgetProvider registered in AndroidManifest.xml.
const String _androidWidgetName = 'GateWidgetProvider';

/// Shared-data keys read by the native RemoteViews provider.
const String keyGateOpen = 'gate_open';
const String keyGateStatus = 'gate_status';

/// Background entry point fired when the home-screen widget button is tapped.
///
/// Runs headless (no app UI). Toggles the gate, persists the new state for the
/// native provider to render, then asks Android to redraw the widget.
@pragma('vm:entry-point')
Future<void> gateWidgetTapped(Uri? uri) async {
  if (uri?.host != 'toggle') {
    // Unknown action — just refresh current state.
    await _refreshState();
    return;
  }

  final service = GateService();
  try {
    final current = await service.fetchState();
    final newOpen = await service.toggle(currentOpen: current);
    await _save(open: newOpen, status: 'متصل');
  } catch (_) {
    await _save(open: null, status: 'خطأ');
  } finally {
    service.dispose();
  }
  await _update();
}

/// Reads state without toggling (used on widget add / unknown action).
Future<void> _refreshState() async {
  final service = GateService();
  try {
    final open = await service.fetchState();
    await _save(open: open, status: 'متصل');
  } catch (_) {
    await _save(open: null, status: 'خطأ');
  } finally {
    service.dispose();
  }
  await _update();
}

Future<void> _save({required bool? open, required String status}) async {
  if (open != null) {
    await HomeWidget.saveWidgetData<bool>(keyGateOpen, open);
  }
  await HomeWidget.saveWidgetData<String>(keyGateStatus, status);
}

Future<void> _update() =>
    HomeWidget.updateWidget(name: _androidWidgetName, androidName: _androidWidgetName);
