import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Plays the gate feedback cues: a rising chime on open, a falling chime on
/// close, each paired with a light haptic. Fire-and-forget — audio/haptic
/// failures never break the gate toggle.
class GateSound {
  GateSound() : _player = AudioPlayer(playerId: 'gate_sound') {
    // Low latency mode: cues are short and must feel instant.
    unawaited(_player.setPlayerMode(PlayerMode.lowLatency));
    unawaited(_player.setReleaseMode(ReleaseMode.stop));
  }

  final AudioPlayer _player;

  static const _openAsset = 'sounds/gate_open.wav';
  static const _closeAsset = 'sounds/gate_close.wav';

  /// Play the cue matching the new gate state. [open] true = opening.
  Future<void> play({required bool open}) async {
    unawaited(HapticFeedback.mediumImpact());
    try {
      await _player.stop();
      await _player.play(AssetSource(open ? _openAsset : _closeAsset));
    } on Object {
      // Best-effort: a missing codec or muted device must not block the gate.
    }
  }

  void dispose() => unawaited(_player.dispose());
}
