import 'package:flutter_test/flutter_test.dart';
import 'package:scrott_voice/core/utils/formatters.dart';

void main() {
  group('formatDuration', () {
    test('formata segundos abaixo de um minuto', () {
      expect(formatDuration(0), '00:00');
      expect(formatDuration(5), '00:05');
      expect(formatDuration(59), '00:59');
    });

    test('formata minutos e segundos', () {
      expect(formatDuration(60), '01:00');
      expect(formatDuration(78), '01:18');
      expect(formatDuration(599), '09:59');
    });

    test('formata horas quando passa de 3600s', () {
      expect(formatDuration(3600), '1:00:00');
      expect(formatDuration(3661), '1:01:01');
    });

    test('trata valores inválidos como zero', () {
      expect(formatDuration(-5), '00:00');
      expect(formatDuration(double.nan), '00:00');
      expect(formatDuration(double.infinity), '00:00');
    });
  });

  group('formatPreciseDuration', () {
    test('mostra centésimos de segundo', () {
      expect(formatPreciseDuration(78), '01:18.00');
      expect(formatPreciseDuration(78.5), '01:18.50');
    });
  });

  group('formatBytes', () {
    test('escala as unidades', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2.0 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    });
  });
}
