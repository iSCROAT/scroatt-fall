import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Fachada sobre o `just_audio` para reproduzir as gravações.
///
/// Mantém o estado de reprodução e expõe streams simples para a UI.
class AudioPlayerService {
  AudioPlayerService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playingSub;

  final _positionController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();

  Stream<Duration> get positionStream => _positionController.stream;

  Stream<bool> get playingStream => _playingController.stream;

  bool get isPlaying => _player.playing;

  Duration? get duration => _player.duration;

  /// Inicia (ou retoma) a reprodução do arquivo em [path].
  Future<void> play(String path) async {
    _bindStreams();
    if (_player.audioSource == null) {
      await _player.setFilePath(path);
    }
    await _player.play();
  }

  Future<void> pause() => _player.pause();

  Future<void> stop() => _player.stop();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  void _bindStreams() {
    _posSub?.cancel();
    _playingSub?.cancel();
    _posSub = _player.positionStream.listen((p) {
      if (!_positionController.isClosed) _positionController.add(p);
    });
    // `playingStream` já entrega um bool; `playerStateStream` emitiria
    // `PlayerState`.
    _playingSub = _player.playingStream.listen((playing) {
      if (!_playingController.isClosed) {
        _playingController.add(playing);
      }
    });
  }

  Future<void> dispose() async {
    await _posSub?.cancel();
    await _playingSub?.cancel();
    await _positionController.close();
    await _playingController.close();
    await _player.dispose();
  }
}
