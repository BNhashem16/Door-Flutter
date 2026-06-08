import 'package:home_widget/home_widget.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_store.dart';
import 'gate_service.dart';

/// Android provider class name (package + class). Must match the Kotlin
/// AppWidgetProvider registered in AndroidManifest.xml.
const String _androidWidgetName = 'GateWidgetProvider';

/// Shared-data keys read by the native RemoteViews provider.
const String keyGateOpen = 'gate_open';
const String keyGateStatus = 'gate_status';
const String keyGateState = 'gate_state'; // localized "Gate open/closed"
const String keyGateAction = 'gate_action'; // localized "Tap to open/close"
const String keyLoggedIn = 'widget_logged_in'; // gate the widget on auth

/// Persists whether a user is signed in, so the headless widget callback —
/// which has no Firebase Auth — can decide if the gate may be controlled.
/// Call `true` on sign-in, `false` on sign-out. Also redraws the widget so it
/// reflects the new locked/unlocked state immediately.
Future<void> setWidgetLoggedIn(bool loggedIn) async {
  await HomeWidget.saveWidgetData<bool>(keyLoggedIn, loggedIn);
  if (!loggedIn) {
    // Clear last-known gate state so a signed-out widget shows nothing stale.
    final s = await _strings();
    await HomeWidget.saveWidgetData<String>(keyGateStatus, s.widgetLoginRequired);
  }
  await _update();
}

Future<bool> _isLoggedIn() async =>
    await HomeWidget.getWidgetData<bool>(keyLoggedIn, defaultValue: false) ??
    false;

/// Background entry point fired when the home-screen widget button is tapped.
///
/// Runs headless (no app UI). Toggles the gate, persists the new state for the
/// native provider to render, then asks Android to redraw the widget.
@pragma('vm:entry-point')
Future<void> gateWidgetTapped(Uri? uri) async {
  // Block all widget actions until a user signs in.
  if (!await _isLoggedIn()) {
    final s = await _strings();
    await _save(open: null, status: s.widgetLoginRequired, strings: s);
    await _update();
    return;
  }

  if (uri?.host != 'toggle') {
    // Unknown action — just refresh current state.
    await _refreshState();
    return;
  }

  final s = await _strings();
  final service = GateService();
  try {
    final current = await service.fetchState();
    final newOpen = await service.toggle(currentOpen: current);
    await _save(open: newOpen, status: s.connected, strings: s);
  } catch (_) {
    await _save(open: null, status: s.disconnected, strings: s);
  } finally {
    service.dispose();
  }
  await _update();
}

/// Reads state without toggling (used on widget add / unknown action).
Future<void> _refreshState() async {
  final s = await _strings();
  final service = GateService();
  try {
    final open = await service.fetchState();
    await _save(open: open, status: s.connected, strings: s);
  } catch (_) {
    await _save(open: null, status: s.disconnected, strings: s);
  } finally {
    service.dispose();
  }
  await _update();
}

/// Resolves localized strings using the user's saved app language (falling
/// back to the device locale), since this callback runs without a context.
Future<AppStrings> _strings() async {
  final locale = await LocaleStore.initial();
  return AppStrings.forLanguageCode(locale.languageCode);
}

Future<void> _save({
  required bool? open,
  required String status,
  required AppStrings strings,
}) async {
  if (open != null) {
    await HomeWidget.saveWidgetData<bool>(keyGateOpen, open);
    await HomeWidget.saveWidgetData<String>(
        keyGateState, open ? strings.gateOpen : strings.gateClosed);
    await HomeWidget.saveWidgetData<String>(
        keyGateAction, open ? strings.tapToClose : strings.tapToOpen);
  }
  await HomeWidget.saveWidgetData<String>(keyGateStatus, status);
}

Future<void> _update() => HomeWidget.updateWidget(
    name: _androidWidgetName, androidName: _androidWidgetName);
