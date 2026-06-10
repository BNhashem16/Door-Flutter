import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'offline_screen.dart';

/// Wraps the whole app and blocks all interaction whenever the device drops
/// offline.
///
/// Placed inside `MaterialApp.builder` so it sits above the Navigator and its
/// offline overlay covers every route (login, lock, gate, admin, pushed
/// screens). The [child] tree is kept mounted under the overlay, so when the
/// connection returns the user resumes exactly where they were.
///
/// Detection uses `connectivity_plus`: the device is considered offline only
/// when no network interface is up. A platform check failure is treated as
/// online to avoid falsely locking the user out.
class ConnectivityGate extends StatefulWidget {
  const ConnectivityGate({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _subscription = _connectivity.onConnectivityChanged.listen(_apply);
    unawaited(_recheck());
  }

  /// Runs a one-shot connectivity check. Wired to the retry button and used for
  /// the initial state before the stream emits.
  Future<void> _recheck() async {
    try {
      _apply(await _connectivity.checkConnectivity());
    } on Exception {
      // Platform check failed — assume online rather than lock the user out.
      if (mounted && _offline) setState(() => _offline = false);
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (mounted && offline != _offline) {
      setState(() => _offline = offline);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_offline) Positioned.fill(child: OfflineScreen(onRetry: _recheck)),
      ],
    );
  }
}
