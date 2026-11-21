import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  Timer? _stopTimer;

  Future<void> playAlarm(String soundPath, String durationMode) async {
    await stop();
    await _player.setReleaseMode(ReleaseMode.loop);

    try {
      if (soundPath.isNotEmpty && File(soundPath).existsSync()) {
        await _player.play(DeviceFileSource(soundPath));
      } else {
        // Lit assets/Sonneries/Flute.mp3 (AssetSource préfixe automatiquement par 'assets/')
        final assetName = soundPath.startsWith('Sonneries/') ? soundPath : 'Sonneries/Flute.mp3';
        await _player.play(AssetSource(assetName));
      }

      if (durationMode == 'Arrêt après 20 sec') {
        _stopTimer = Timer(const Duration(seconds: 20), () {
          stop();
        });
      }
    } catch (_) {}
  }

  Future<void> stop() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    _stopTimer?.cancel();
    _player.dispose();
  }
}
