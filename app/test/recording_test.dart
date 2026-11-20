import 'package:flutter_test/flutter_test.dart';
import 'package:scrott_voice/models/recording.dart';

Recording build({
  String id = '1',
  String transcript = 'Hello Alex, how are you today?',
  String? title,
  DateTime? createdAt,
  double duration = 28,
  List<double> amplitudePeaks = const [],
}) {
  return Recording(
    id: id,
    filePath: '/tmp/rec_1.m4a',
    createdAt: createdAt ?? DateTime(2026, 3, 14, 9, 5),
    duration: duration,
    transcript: transcript,
    title: title,
    amplitudePeaks: amplitudePeaks,
  );
}

void main() {
  group('Recording', () {
    test('usa o título informado quando existe', () {
      expect(build(title: 'Weekly sync').displayTitle, 'Weekly sync');
    });

    test('gera um título padrão a partir da data', () {
      final r = build();
      expect(r.displayTitle, '14 Mar · 09:05');
    });

    test('a prévia normaliza espaços e aplica reticências', () {
      final r = build(transcript: '  Hello   world  ');
      expect(r.preview, 'Hello world');

      final long = build(transcript: 'x' * 200);
      expect(long.preview.length, 91); // 90 caracteres + reticências
      expect(long.preview.endsWith('…'), isTrue);
    });

    test('a prévia de uma transcrição vazia avisa o usuário', () {
      expect(build(transcript: '   ').preview, 'Sem transcrição');
    });

    test('copyWith preserva os campos não alterados', () {
      final original = build(title: 'Original');
      final updated = original.copyWith(transcript: 'Novo texto');

      expect(updated.transcript, 'Novo texto');
      expect(updated.title, 'Original');
      expect(updated.filePath, original.filePath);
      expect(updated.duration, original.duration);
    });

    test('serializa e desserializa preservando todos os campos', () {
      final original = build(
        title: 'Reunião',
        amplitudePeaks: const [0.1, 0.5, 0.9],
      );

      final decoded = Recording.fromJson(original.toJson());

      expect(decoded.id, original.id);
      expect(decoded.filePath, original.filePath);
      expect(decoded.title, original.title);
      expect(decoded.transcript, original.transcript);
      expect(decoded.duration, original.duration);
      expect(decoded.createdAt, original.createdAt);
      expect(decoded.amplitudePeaks, original.amplitudePeaks);
    });

    test('codifica e decodifica uma lista completa', () {
      final items = [
        build(id: 'a', title: 'A'),
        build(id: 'b', title: 'B', duration: 12),
      ];

      final restored = Recording.decodeList(Recording.encodeList(items));

      expect(restored.length, 2);
      expect(restored[0].title, 'A');
      expect(restored[1].duration, 12);
    });

    test('devolve lista vazia para conteúdo inválido', () {
      expect(Recording.decodeList(''), isEmpty);
      expect(Recording.decodeList('lixo'), isEmpty);
    });
  });
}
