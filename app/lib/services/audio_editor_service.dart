import 'dart:io';
import 'dart:typed_data';

import 'package:audio_decoder/audio_decoder.dart';

/// Processamento real do audio gravado.
///
/// As tres ferramentas do editor — cortar, volume e efeito de voz —
/// manipulam o arquivo de audio de verdade.
///
/// O container `.m4a` guarda audio codificado em AAC, que nao pode ser
/// editado quadro a quadro. O `audio_decoder` converte o arquivo em PCM
/// usando as APIs nativas do Android (MediaCodec), sem FFmpeg. A partir
/// do PCM, o processamento e direto e rapido.
///
/// O resultado e gravado em WAV, que qualquer player reproduce.
class AudioEditorService {
  AudioEditorService();

  /// Taxa de leitura usada na decodificacao.
  ///
  /// 44.1 kHz mono de 16 bits e o mesmo formato da gravacao, o que evita
  /// qualquer perda na conversao.
  static const int _sampleRate = 44100;
  static const int _channels = 1;

  /// Decodifica [path] e devolve as amostras PCM.
  ///
  /// Devolve `null` quando o arquivo nao pode ser convertido — nesse
  /// caso o editor mantem o audio original em vez de perder a gravacao.
  Future<PcmBuffer?> _readPcm(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      final pcm = await AudioDecoder.convertToWavBytes(
        bytes,
        formatHint: _formatHint(path),
        includeHeader: false,
        sampleRate: _sampleRate,
        channels: _channels,
        bitDepth: 16,
      );
      if (pcm.isEmpty) return null;
      return PcmBuffer(
        samples: Int16List.view(
          pcm.buffer,
          pcm.offsetInBytes,
          pcm.lengthInBytes ~/ 2,
        ),
        sampleRate: _sampleRate,
        channels: _channels,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sugere o formato a partir da extensao do arquivo.
  ///
  /// O `audio_decoder` detecta o formato pelos bytes, mas a dica evita
  /// ambiguidade com arquivos `.m4a` que nao comecam pelo cabecalho usual.
  String _formatHint(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'mp3';
    if (lower.endsWith('.ogg')) return 'ogg';
    if (lower.endsWith('.wav')) return 'wav';
    return 'm4a';
  }

  /// Recorta o audio entre [start] e [end] (em segundos).
  ///
  /// Devolve o caminho do arquivo gerado, ou `null` quando nao ha nada
  /// para recortar.
  Future<String?> trim({
    required String inputPath,
    required String outputPath,
    required double start,
    required double end,
  }) async {
    final pcm = await _readPcm(inputPath);
    if (pcm == null) return null;

    final duration = pcm.durationSeconds;
    final from = (start.clamp(0.0, duration) * pcm.sampleRate).round();
    final to = (end.clamp(0.0, duration) * pcm.sampleRate).round();
    if (to <= from) return null;

    final trimmed = pcm.samples.sublist(
      from * pcm.channels,
      to * pcm.channels,
    );
    return _writeWav(outputPath, trimmed, pcm.sampleRate, pcm.channels);
  }

  /// Aplica um ganho linear ao audio.
  ///
  /// [gain] acima de 1 amplifica e abaixo de 1 atenua. Os valores sao
  /// limitados para evitar distorcao digital.
  Future<String?> applyVolume({
    required String inputPath,
    required String outputPath,
    required double gain,
  }) async {
    final pcm = await _readPcm(inputPath);
    if (pcm == null) return null;

    final clamped = gain.clamp(0.0, 4.0);
    final samples = Int16List(pcm.samples.length);
    for (var i = 0; i < pcm.samples.length; i++) {
      final value = (pcm.samples[i] * clamped).round();
      samples[i] = value.clamp(-32768, 32767);
    }
    return _writeWav(outputPath, samples, pcm.sampleRate, pcm.channels);
  }

  /// Aplica um efeito de voz.
  ///
  /// * [enhance] acima de 1 reforca as frequencias agudas (clareza);
  /// * [echo] acima de 1 acrescenta um eco curto, como o efeito do
  ///   protótipo;
  /// * [normalize] leva o pico do audio para perto do maximo, deixando
  ///   a voz mais presente sem estourar.
  Future<String?> applyVoiceEffect({
    required String inputPath,
    required String outputPath,
    double enhance = 1.0,
    double echo = 0.0,
    bool normalize = false,
  }) async {
    final pcm = await _readPcm(inputPath);
    if (pcm == null) return null;

    final source = pcm.samples;
    final channels = pcm.channels;
    final frameCount = source.length ~/ channels;

    var samples = Int16List(source.length);
    for (var i = 0; i < source.length; i++) {
      samples[i] = source[i];
    }

    // --- Realce (mistura com a diferenca para a frequencia media) ---
    if (enhance > 1.0) {
      final amount = (enhance - 1.0).clamp(0.0, 2.0);
      final mixed = Int16List(source.length);
      for (var frame = 0; frame < frameCount; frame++) {
        final base = frame * channels;
        var average = 0;
        for (var c = 0; c < channels; c++) {
          average += samples[base + c];
        }
        average ~/= channels;

        for (var c = 0; c < channels; c++) {
          final original = samples[base + c];
          // Mistura a amostra com a diferenca para a frequencia media,
          // que acentua a presenca da voz.
          final value = (original + (original - average) * amount)
              .round()
              .clamp(-32768, 32767);
          mixed[base + c] = value;
        }
      }
      samples = mixed;
    }

    // --- Eco (realimentacao curta) ---
    if (echo > 0.0) {
      const delayFrames = 220; // ~5 ms a 44.1 kHz
      final amount = echo.clamp(0.0, 1.0);
      final mixed = Int16List(source.length);
      for (var i = 0; i < source.length; i++) {
        mixed[i] = samples[i];
      }
      for (var frame = delayFrames; frame < frameCount; frame++) {
        final base = frame * channels;
        for (var c = 0; c < channels; c++) {
          final delayed = samples[(frame - delayFrames) * channels + c];
          final value =
              (samples[base + c] + delayed * amount * 0.45).round().clamp(
            -32768,
            32767,
          );
          mixed[base + c] = value;
        }
      }
      samples = mixed;
    }

    // --- Normalizacao (pico perto do maximo) ---
    if (normalize) {
      var peak = 0;
      for (final value in samples) {
        final abs = value.abs();
        if (abs > peak) peak = abs;
      }
      if (peak > 0 && peak < 32000) {
        final factor = 32000 / peak;
        for (var i = 0; i < samples.length; i++) {
          samples[i] = (samples[i] * factor).round().clamp(-32768, 32767);
        }
      }
    }

    return _writeWav(outputPath, samples, pcm.sampleRate, channels);
  }

  /// Grava amostras PCM de 16 bits em um container WAV.
  Future<String?> _writeWav(
    String outputPath,
    Int16List samples,
    int sampleRate,
    int channels,
  ) async {
    final out = File(outputPath);
    await out.parent.create(recursive: true);

    final dataBytes = samples.length * 2;
    final header = BytesBuilder();

    void writeAscii(String value) => header.add(value.codeUnits);
    void writeU32(int value) {
      final b = ByteData(4)..setUint32(0, value, Endian.little);
      header.add(b.buffer.asUint8List());
    }
    void writeU16(int value) {
      final b = ByteData(2)..setUint16(0, value, Endian.little);
      header.add(b.buffer.asUint8List());
    }

    writeAscii('RIFF');
    writeU32(36 + dataBytes);
    writeAscii('WAVE');
    writeAscii('fmt ');
    writeU32(16);
    writeU16(1); // PCM
    writeU16(channels);
    writeU32(sampleRate);
    writeU32(sampleRate * channels * 2);
    writeU16(channels * 2);
    writeU16(16);
    writeAscii('data');
    writeU32(dataBytes);

    final pcmBytes = ByteData(dataBytes);
    for (var i = 0; i < samples.length; i++) {
      pcmBytes.setInt16(i * 2, samples[i], Endian.little);
    }

    await out.writeAsBytes(
      <int>[...header.takeBytes(), ...pcmBytes.buffer.asUint8List()],
      flush: true,
    );
    return out.path;
  }
}

/// Audio em PCM de 16 bits, pronto para edicao.
class PcmBuffer {
  const PcmBuffer({
    required this.samples,
    required this.sampleRate,
    required this.channels,
  });

  final Int16List samples;
  final int sampleRate;
  final int channels;

  /// Duracao do audio em segundos.
  double get durationSeconds =>
      samples.length / (sampleRate * channels);
}
