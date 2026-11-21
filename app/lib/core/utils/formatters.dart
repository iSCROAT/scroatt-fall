/// Formata segundos em `mm:ss` (ou `hh:mm:ss` quando passa de 1 hora).
///
/// Usado nos timers de gravação e na lista da biblioteca.
String formatDuration(double seconds) {
  if (seconds.isNaN || seconds.isInfinite || seconds < 0) seconds = 0;
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$mm:$ss';
}

/// Formata a duração com decimal nos milissegundos — usado no editor
/// para mostrar a posição do cursor de áudio com precisão.
String formatPreciseDuration(double seconds) {
  if (seconds.isNaN || seconds.isInfinite || seconds < 0) seconds = 0;
  final total = seconds.round();
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final cs = ((seconds - seconds.floor()) * 100).floor();
  final centesimos = cs.toString().padLeft(2, '0');
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.$centesimos';
}

/// Formata bytes em uma unidade legível.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final rounded = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$rounded ${units[unit]}';
}
