import 'package:audioplayers/audioplayers.dart';

class SoundService {
  SoundService._();
  static final instance = SoundService._();

  final _player = AudioPlayer();

  /// Call once at app startup to configure the audio context.
  /// Uses AVAudioSessionCategory.ambient on iOS so the silent switch is respected,
  /// and AndroidAudioFocus.none so music / other apps are never interrupted.
  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notificationEvent,
          audioFocus: AndroidAudioFocus.none,
        ),
      ));
    } catch (_) {
      // Non-fatal — continue without custom audio context
    }
  }

  /// Plays the popup chime. Stops any in-progress chime first so rapid
  /// successive popups always restart the sound rather than stacking.
  /// Errors are swallowed — audio failure must never block the UI.
  Future<void> playPopupSound() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/popup_chime.wav'));
    } catch (_) {}
  }

  void dispose() => _player.dispose();
}
