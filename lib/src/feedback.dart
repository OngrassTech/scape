import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'models.dart';

AudioContext buildUiSoundAudioContext() {
  return AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();
}

abstract class FeedbackController {
  Future<void> playSound(SoundCue cue);

  Future<void> playHaptic(HapticCue cue);

  void dispose() {}
}

class SystemFeedbackController implements FeedbackController {
  @override
  void dispose() {}

  @override
  Future<void> playSound(SoundCue cue) async {}

  @override
  Future<void> playHaptic(HapticCue cue) async {
    switch (cue) {
      case HapticCue.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticCue.heavy:
        await HapticFeedback.heavyImpact();
        break;
      case HapticCue.success:
        await HapticFeedback.mediumImpact();
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 60),
            HapticFeedback.lightImpact,
          ),
        );
        break;
      case HapticCue.failure:
        await HapticFeedback.heavyImpact();
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 80),
            HapticFeedback.heavyImpact,
          ),
        );
        break;
    }
  }
}

class AudioFeedbackController implements FeedbackController {
  AudioFeedbackController({
    FeedbackController? fallback,
  })  : _fallback = fallback ?? SystemFeedbackController(),
        _players = <SoundCue, AudioPlayer>{
          for (final SoundCue cue in SoundCue.values)
            cue: AudioPlayer(playerId: 'maze-${cue.name}-feedback'),
        },
        _audioContext = buildUiSoundAudioContext() {
    for (final AudioPlayer player in _players.values) {
      unawaited(player.setReleaseMode(ReleaseMode.stop));
    }
  }

  final FeedbackController _fallback;
  final Map<SoundCue, AudioPlayer> _players;
  final AudioContext _audioContext;

  @override
  void dispose() {
    for (final AudioPlayer player in _players.values) {
      unawaited(player.dispose());
    }
    _fallback.dispose();
  }

  @override
  Future<void> playSound(SoundCue cue) async {
    final AudioPlayer? player = _players[cue];
    if (player == null) {
      await _fallback.playSound(cue);
      return;
    }

    try {
      await player.stop();
      await player.play(
        AssetSource(_assetFor(cue)),
        ctx: _audioContext,
        mode: PlayerMode.lowLatency,
        volume: _volumeFor(cue),
      );
    } catch (_) {
      await _fallback.playSound(cue);
    }
  }

  @override
  Future<void> playHaptic(HapticCue cue) {
    return _fallback.playHaptic(cue);
  }

  String _assetFor(SoundCue cue) {
    switch (cue) {
      case SoundCue.swipe:
        return 'audio/button.wav';
      case SoundCue.toggle:
        return 'audio/toggle.wav';
      case SoundCue.move:
        return 'audio/movement.wav';
      case SoundCue.success:
        return 'audio/success.wav';
      case SoundCue.failure:
        return 'audio/error.wav';
    }
  }

  double _volumeFor(SoundCue cue) {
    switch (cue) {
      case SoundCue.swipe:
        return 0.34;
      case SoundCue.toggle:
        return 0.34;
      case SoundCue.move:
        return 0.32;
      case SoundCue.success:
        return 0.54;
      case SoundCue.failure:
        return 0.50;
    }
  }
}

class NoopFeedbackController implements FeedbackController {
  @override
  void dispose() {}

  @override
  Future<void> playHaptic(HapticCue cue) async {}

  @override
  Future<void> playSound(SoundCue cue) async {}
}
