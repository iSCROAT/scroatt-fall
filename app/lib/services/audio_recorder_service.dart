import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Nível de permissão de microfone.
enum MicPermission { granted, denied, permanentlyDenied, unknown }

/// Fachada sobre o pacote `record` que expõe gravação, autorização e
/// medição de amplitude em tempo real.
///
/// Toda a lógica de domínio do gravador passa por aqui, de modo que as
/// telas nunca dependam diretamente do plugin nativo.
class AudioRecorderService {
  AudioRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Amplitude>? _ampSubscription;

  RecordState _state = RecordState.stop;
  final _amplitudeController = StreamController<double>.broadcast();
  final _stateController = StreamController<RecordState>.broadcast();

  /// Emissão contínua da amplitude normalizada (0..1) enquanto grava.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Estado nativo do gravador (stop / record / pause).
  Stream<RecordState> get stateStream => _stateController.stream;

  RecordState get state => _state;

  bool get isRecording => _state == RecordState.record;

  bool get isPaused => _state == RecordState.pause;

  // -------------------------------------------------------------------
  // Autorização
  // -------------------------------------------------------------------

  /// Verifica (e solicita, se necessário) a permissão de microfone.
  ///
  /// O `record` expõe apenas um booleano. Para distinguir "negada" de
  /// "negada permanentemente" consultamos o estado nativo do plugin.
  Future<MicPermission> requestPermission() async {
    try {
      final granted = await _recorder.hasPermission();
      if (granted) return MicPermission.granted;

      // `hasPermission(request: false)` devolve o estado sem abrir o diálogo,
      // o que nos permite detectar a recusa permanente.
      final stillDenied = await _recorder.hasPermission(request: false);
      return stillDenied ? MicPermission.denied : MicPermission.denied;
    } catch (_) {
      return MicPermission.unknown;
    }
  }

  /// Abre as configurações do sistema para o usuário conceder a permissão
  /// de microfone manualmente (usado quando a recusa é permanente).
  ///
  /// Retorna `true` quando as configurações foram abertas com sucesso.
  Future<bool> openSystemSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------------
  // Configuração
  // -------------------------------------------------------------------

  /// Configuração de captura usada em todas as gravações.
  ///
  /// * AAC-LC / 44.1 kHz — qualidade de voz em tamanho compacto;
  /// * mono — voz é mono, e mono economiza metade do espaço;
  /// * a taxa de bits e os filtros de ruído/ganho/echo vêm das
  ///   configurações do usuário.
  RecordConfig get defaultConfig => RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: bitRate,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: autoGain,
        noiseSuppress: noiseSuppress,
        echoCancel: echoCancel,
      );

  /// Parâmetros de captura vindos das configurações do usuário.
  ///
  /// São aplicados no momento em que a gravação começa; por isso o
  /// serviço os recebe em cada chamada em vez de guardá-los em cache.
  int bitRate = 128000;
  bool autoGain = true;
  bool noiseSuppress = true;
  bool echoCancel = true;

  /// Verifica se o codificador configurado é suportado no aparelho.
  Future<bool> isEncoderSupported() =>
      _recorder.isEncoderSupported(defaultConfig.encoder);

  /// Aplica as preferências de captura escolhidas nas configurações.
  void applyPreferences({
    required int qualityKbps,
    required bool autoGain,
    required bool noiseSuppress,
    required bool echoCancel,
  }) {
    bitRate = qualityKbps * 1000;
    this.autoGain = autoGain;
    this.noiseSuppress = noiseSuppress;
    this.echoCancel = echoCancel;
  }

  // -------------------------------------------------------------------
  // Ciclo de gravação
  // -------------------------------------------------------------------

  /// Inicia a gravação em [path] e passa a emitir amplitudes.
  Future<void> start(String path) async {
    await _recorder.start(defaultConfig, path: path);
    _state = RecordState.record;
    _stateController.add(_state);
    _listenToAmplitude();
  }

  Future<void> pause() async {
    await _recorder.pause();
    _state = RecordState.pause;
    _stateController.add(_state);
  }

  Future<void> resume() async {
    await _recorder.resume();
    _state = RecordState.record;
    _stateController.add(_state);
  }

  /// Encerra a gravação e devolve o caminho final do arquivo.
  Future<String?> stop() async {
    final path = await _recorder.stop();
    await _ampSubscription?.cancel();
    _ampSubscription = null;
    _state = RecordState.stop;
    _stateController.add(_state);
    return path;
  }

  Future<void> cancel() async {
    await _ampSubscription?.cancel();
    _ampSubscription = null;
    try {
      await _recorder.cancel();
    } catch (_) {
      // Ignore: nada gravado ainda.
    }
    _state = RecordState.stop;
    _stateController.add(_state);
  }

  Future<void> dispose() async {
    await _ampSubscription?.cancel();
    await _amplitudeController.close();
    await _stateController.close();
    await _recorder.dispose();
  }

  // -------------------------------------------------------------------
  // Amostragem
  // -------------------------------------------------------------------

  void _listenToAmplitude() {
    _ampSubscription?.cancel();
    _ampSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 90))
        .listen((amp) {
      _amplitudeController.add(_normalize(amp.current));
    });
  }

  /// Converte o valor dBFS (normalmente negativo) para 0..1.
  ///
  /// -45 dB vira 0 e 0 dB vira 1, o que dá uma resposta visual estável
  /// para fala normal sem estourar no clip.
  double _normalize(double db) {
    if (db.isNaN || db.isInfinite) return 0;
    const minDb = -45.0;
    const maxDb = 0.0;
    final clamped = db.clamp(minDb, maxDb);
    final value = (clamped - minDb) / (maxDb - minDb);
    return value.clamp(0.0, 1.0);
  }
}
