import 'dart:convert';

/// Representa uma gravacao salva na biblioteca do usuario.
class Recording {
  const Recording({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.duration,
    required this.transcript,
    this.title,
    this.sampleRate = 44100,
    this.amplitudePeaks = const [],
    this.languageCode = 'pt-BR',
    this.ownerName = '',
    this.fileSizeBytes = 0,
    this.folder = '',
  });

  final String id;

  /// Caminho absoluto do arquivo `.m4a` no armazenamento.
  final String filePath;

  final DateTime createdAt;

  /// Duracao total em segundos.
  final double duration;

  /// Texto transcrito/editado pelo usuario.
  final String transcript;

  /// Titulo opcional — quando ausente, geramos a partir da data.
  final String? title;

  final int sampleRate;

  /// Picos de amplitude normalizados (0..1) usados para desenhar a waveform.
  final List<double> amplitudePeaks;

  final String languageCode;

  /// Nome escolhido no app por quem fez a gravacao.
  ///
  /// Vem no nome do arquivo e no cabecalho da gravacao, para que o
  /// usuario reconheca a origem do arquivo mesmo fora do app.
  final String ownerName;

  /// Tamanho do arquivo de audio em bytes.
  ///
  /// Guardamos o valor no momento em que o arquivo e escrito: medir o
  /// arquivo a cada abertura da biblioteca custaria I/O desnecessario.
  final int fileSizeBytes;

  /// Pasta onde o arquivo foi gravado.
  final String folder;

  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!.trim();
    return _defaultTitle;
  }

  String get _defaultTitle {
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '${createdAt.day} ${months[createdAt.month - 1]} · $h:$m';
  }

  /// Data por extenso, no padrao brasileiro: `21/11/2026`.
  String get formattedDate {
    final d = createdAt;
    return '${_two(d.day)}/${_two(d.month)}/${d.year}';
  }

  /// Hora no formato de 24 horas: `05:25`.
  String get formattedTime {
    final d = createdAt;
    return '${_two(d.hour)}:${_two(d.minute)}';
  }

  /// Duracao formatada: `00:16` ou `1:02:33`.
  String get formattedDuration {
    final total = duration.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '$h:${_two(m)}:${_two(s)}';
    }
    return '${_two(m)}:${_two(s)}';
  }

  /// Tamanho do arquivo formatado: `1,4 MB`, `812 KB`, `45 B`.
  String get formattedSize {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = fileSizeBytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = unit == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(value >= 10 ? 1 : 1).replaceAll('.', ',');
    return '$text ${units[unit]}';
  }

  /// Previa de uma linha do texto, usada nos cards da biblioteca.
  String get preview {
    final clean = transcript.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return 'Sem transcrição';
    return clean.length <= 90 ? clean : '${clean.substring(0, 90)}…';
  }

  Recording copyWith({
    String? id,
    String? filePath,
    DateTime? createdAt,
    double? duration,
    String? transcript,
    String? title,
    int? sampleRate,
    List<double>? amplitudePeaks,
    String? languageCode,
    String? ownerName,
    int? fileSizeBytes,
    String? folder,
  }) {
    return Recording(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
      transcript: transcript ?? this.transcript,
      title: title ?? this.title,
      sampleRate: sampleRate ?? this.sampleRate,
      amplitudePeaks: amplitudePeaks ?? this.amplitudePeaks,
      languageCode: languageCode ?? this.languageCode,
      ownerName: ownerName ?? this.ownerName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      folder: folder ?? this.folder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
        'duration': duration,
        'transcript': transcript,
        'title': title,
        'sampleRate': sampleRate,
        'amplitudePeaks': amplitudePeaks,
        'languageCode': languageCode,
        'ownerName': ownerName,
        'fileSizeBytes': fileSizeBytes,
        'folder': folder,
      };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        id: json['id'] as String,
        filePath: json['filePath'] as String,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        duration: (json['duration'] as num?)?.toDouble() ?? 0,
        transcript: json['transcript'] as String? ?? '',
        title: json['title'] as String?,
        sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 44100,
        amplitudePeaks: (json['amplitudePeaks'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            const [],
        languageCode: json['languageCode'] as String? ?? 'pt-BR',
        ownerName: json['ownerName'] as String? ?? '',
        fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
        folder: json['folder'] as String? ?? '',
      );

  /// Serializa a lista inteira para o `SharedPreferences`.
  static String encodeList(List<Recording> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<Recording> decodeList(String raw) {
    if (raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Recording.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
