import 'dart:convert';

/// Representa uma gravação salva na biblioteca do usuário.
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
    this.languageCode = 'en-US',
  });

  final String id;

  /// Caminho absoluto do arquivo `.m4a` no armazenamento do app.
  final String filePath;

  final DateTime createdAt;

  /// Duração total em segundos.
  final double duration;

  /// Texto transcrito/editado pelo usuário.
  final String transcript;

  /// Título opcional — quando ausente, geramos a partir da data.
  final String? title;

  final int sampleRate;

  /// Picos de amplitude normalizados (0..1) usados para desenhar a waveform.
  final List<double> amplitudePeaks;

  final String languageCode;

  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!.trim();
    return _defaultTitle;
  }

  String get _defaultTitle {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '${createdAt.day} ${months[createdAt.month - 1]} · $h:$m';
  }

  /// Prévia de uma linha do texto, usada nos cards da biblioteca.
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
        languageCode: json['languageCode'] as String? ?? 'en-US',
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
}
