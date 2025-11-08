import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class AudioBackgroundService {
  static final AudioBackgroundService _instance =
      AudioBackgroundService._internal();
  factory AudioBackgroundService() => _instance;
  AudioBackgroundService._internal();

  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;

  Future<void> initialize() async {
    _audioPlayer = AudioPlayer();

    // Tải file audio silent (cần file silent.mp3 trong assets)
    await _audioPlayer.setAsset('assets/silent.mp3');
    _audioPlayer.setLoopMode(LoopMode.one);
    _audioPlayer.setVolume(0.0);
  }

  Future<void> startSilentAudio() async {
    if (_isPlaying) return;

    try {
      await _audioPlayer.play();
      _isPlaying = true;
      print('Silent audio started');
    } catch (e) {
      print('Error starting silent audio: $e');
    }
  }

  Future<void> stopSilentAudio() async {
    if (!_isPlaying) return;

    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      print('Silent audio stopped');
    } catch (e) {
      print('Error stopping silent audio: $e');
    }
  }

  bool get isPlaying => _isPlaying;
}
