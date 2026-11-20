import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Modo de renderização da waveform.
enum WaveformStyle {
  /// Malha de linhas ondulantes com brilho — visual da tela de gravação.
  mesh,

  /// Barras verticais arredondadas — visual da tela de edição.
  bars,
}

/// Widget que desenha a forma de onda do áudio.
///
/// O visual do protótipo usa "fitas" de onda em gradiente ciano→azul com
/// glow. Aqui isso é reproduzido com uma `CustomPainter` que:
///
/// 1. amostra a amplitude em várias camadas (fase deslocada), formando a
///    textura entrelaçada do mockup;
/// 2. pinta cada camada com um `Shader` de gradiente azul→ciano;
/// 3. aplica um `MaskFilter.blur` para produzir o halo luminoso.
class WaveformView extends StatelessWidget {
  const WaveformView({
    super.key,
    required this.peaks,
    this.style = WaveformStyle.bars,
    this.progress = 0,
    this.color,
    this.inactiveColor,
    this.glow = true,
    this.barWidth = 3,
    this.barGap = 2.5,
    this.height = 76,
    this.animate = false,
  });

  /// Amplitudes normalizadas (0..1). Lista vazia desenha uma linha reta.
  final List<double> peaks;

  final WaveformStyle style;

  /// Progresso da reprodução (0..1) — highlighta a parte já tocada.
  final double progress;

  /// Cor da parte já reproduzida (padrão: gradiente da onda).
  final Color? color;

  /// Cor da parte ainda não reproduzida.
  final Color? inactiveColor;

  /// Aplica o halo luminoso.
  final bool glow;

  final double barWidth;
  final double barGap;
  final double height;

  /// Quando true, a onda "respira" continuamente (usado na gravação).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (animate) {
      return _AnimatedWaveform(
        peaks: peaks,
        style: style,
        progress: progress,
        color: color,
        inactiveColor: inactiveColor,
        glow: glow,
        barWidth: barWidth,
        barGap: barGap,
        height: height,
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          peaks: peaks,
          style: style,
          progress: progress,
          color: color,
          inactiveColor: inactiveColor,
          glow: glow,
          barWidth: barWidth,
          barGap: barGap,
        ),
      ),
    );
  }
}

class _AnimatedWaveform extends StatefulWidget {
  const _AnimatedWaveform({
    required this.peaks,
    required this.style,
    required this.progress,
    required this.color,
    required this.inactiveColor,
    required this.glow,
    required this.barWidth,
    required this.barGap,
    required this.height,
  });

  final List<double> peaks;
  final WaveformStyle style;
  final double progress;
  final Color? color;
  final Color? inactiveColor;
  final bool glow;
  final double barWidth;
  final double barGap;
  final double height;

  @override
  State<_AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<_AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _WaveformPainter(
            peaks: widget.peaks,
            style: widget.style,
            progress: widget.progress,
            color: widget.color,
            inactiveColor: widget.inactiveColor,
            glow: widget.glow,
            barWidth: widget.barWidth,
            barGap: widget.barGap,
            phase: _controller.value,
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.style,
    required this.progress,
    required this.color,
    required this.inactiveColor,
    required this.glow,
    required this.barWidth,
    required this.barGap,
    this.phase = 0,
  });

  final List<double> peaks;
  final WaveformStyle style;
  final double progress;
  final Color? color;
  final Color? inactiveColor;
  final bool glow;
  final double barWidth;
  final double barGap;
  final double phase;

  static const List<Color> _meshGradient = [
    AppColors.waveDeep,
    AppColors.waveMid,
    AppColors.waveBright,
    AppColors.waveCyan,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (style == WaveformStyle.mesh) {
      _paintMesh(canvas, size);
    } else {
      _paintBars(canvas, size);
    }
  }

  // -----------------------------------------------------------------
  // Estilo "bars" — tela de edição.
  // -----------------------------------------------------------------
  void _paintBars(Canvas canvas, Size size) {
    final step = barWidth + barGap;
    final count = math.max(1, (size.width / step).floor());
    final centerY = size.height / 2;
    final maxHeight = size.height;

    final playedPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: color == null
            ? const [AppColors.waveBright, AppColors.waveDeep]
            : [color!, color!],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    playedPaint.style = PaintingStyle.fill;

    final pendingPaint = Paint()
      ..color = inactiveColor ?? const Color(0x33FFFFFF)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = (color ?? AppColors.waveBright).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..style = PaintingStyle.fill;

    final playedX = size.width * progress.clamp(0.0, 1.0);

    for (var i = 0; i < count; i++) {
      final x = i * step + barWidth / 2;
      final amp = _amplitudeAt(i, count);
      final h = math.max(3.0, amp * maxHeight);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - h / 2, barWidth, h),
        Radius.circular(barWidth),
      );

      final isPlayed = x <= playedX;
      if (isPlayed) {
        if (glow) canvas.drawRRect(rect, glowPaint);
        canvas.drawRRect(rect, playedPaint);
      } else {
        canvas.drawRRect(rect, pendingPaint);
      }
    }
  }

  double _amplitudeAt(int index, int count) {
    if (peaks.isEmpty) return 0.18;
    if (peaks.length == count) return peaks[index];
    // Reamostra a lista de picos para o número de barras desejado.
    final pos = (index / count) * peaks.length;
    final i0 = pos.floor() % peaks.length;
    final i1 = (i0 + 1) % peaks.length;
    final t = pos - pos.floor();
    final v = peaks[i0] * (1 - t) + peaks[i1] * t;
    return v.clamp(0.05, 1.0);
  }

  // -----------------------------------------------------------------
  // Estilo "mesh" — tela de gravação.
  // -----------------------------------------------------------------
  void _paintMesh(Canvas canvas, Size size) {
    const layers = 7;
    final centerY = size.height / 2;
    final amplitude = size.height * 0.40;

    // A amplitude vem da gravação real quando disponível; caso contrário
    // usamos uma forma de onda sintética suave para o protótipo.
    final basePeaks = peaks.isEmpty
        ? List<double>.generate(120, (i) => _synthetic(i))
        : peaks;

    for (var layer = 0; layer < layers; layer++) {
      final layerPhase = phase * 2 * math.pi + layer * 0.55;
      final layerAmp = amplitude * (1 - layer * 0.075);
      final path = Path();

      const segments = 150;
      for (var s = 0; s <= segments; s++) {
        final t = s / segments;
        final x = t * size.width;
        final idx = (t * (basePeaks.length - 1)).round().clamp(
              0,
              basePeaks.length - 1,
            );
        final sample = basePeaks[idx];

        // Deslocamento de fase por camada cria o entrelaçamento do mockup.
        final wobble = math.sin(t * 6.0 + layerPhase) * 0.22 +
            math.sin(t * 11.0 - layerPhase * 1.3) * 0.11;

        final y = centerY +
            (wobble + (sample - 0.45) * 0.55) * layerAmp *
                (0.55 + 0.45 * math.sin(t * math.pi));

        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _meshGradient[layer % _meshGradient.length]
              .withValues(alpha: 0.55 + layer * 0.05),
          AppColors.waveCyan.withValues(alpha: 0.30),
          _meshGradient[(layer + 1) % _meshGradient.length]
              .withValues(alpha: 0.60),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);

      if (glow) {
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawPath(path, glowPaint);
      }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = shader
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, paint);
    }
  }

  double _synthetic(int i) {
    final a = math.sin(i * 0.19) * 0.30;
    final b = math.sin(i * 0.51 + 1.3) * 0.22;
    final c = math.sin(i * 0.93 + 2.6) * 0.12;
    return (0.5 + a + b + c).clamp(0.06, 1.0);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) {
    return old.peaks != peaks ||
        old.progress != progress ||
        old.style != style ||
        old.phase != phase ||
        old.color != color ||
        old.inactiveColor != inactiveColor;
  }
}
