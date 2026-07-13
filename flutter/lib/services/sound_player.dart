import 'package:audioplayers/audioplayers.dart';

/// Plays the pre-generated "Happy Birthday" chime (assets/birthday.wav).
class SoundPlayer {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playBirthdayChime() async {
    try {
      await _player.play(AssetSource('birthday.wav'));
    } catch (_) {
      // Non-fatal — a failed chime shouldn't block the celebration screen.
    }
  }
}
