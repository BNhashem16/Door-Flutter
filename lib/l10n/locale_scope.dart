import 'package:flutter/widgets.dart';

/// Exposes the active [Locale] and a toggle callback to the whole widget tree.
///
/// Wrapped around `home:` in `MyApp.build` so any screen — including the
/// pre-login auth screens — can flip the language via
/// `LocaleScope.of(context).onToggle` without prop-drilling the callback.
class LocaleScope extends InheritedWidget {
  const LocaleScope({
    super.key,
    required this.locale,
    required this.onToggle,
    required super.child,
  });

  final Locale locale;

  /// Switches AR <-> EN (and persists the choice). Provided by `MyApp`.
  final VoidCallback onToggle;

  static LocaleScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'No LocaleScope found in the widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(LocaleScope oldWidget) => oldWidget.locale != locale;
}
