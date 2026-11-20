import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Orbe de fita luminoso — o elemento gráfico central da tela inicial.
///
/// O protótipo mostra uma "fita" azul tridimensional que se dobra sobre si
/// mesma formando um nó orgânico. Reproduzimos isso com um conjunto de
/// curvas Bézier em múltiplas camadas, cada uma com gradiente ciano→azul e
/// um desfoque luminoso por trás.
class GlowOrb extends StatefulWidget {
  const GlowOrb({
    super.key,
    this.size = 260,
    this.animate = true,
    this.intensity = 1.0,
  });

  final double size;
  final bool animate;

  /// Multiplicador do brilho (0.5 = discreto, 1.5 = intenso).
  final double intensity;

  @override
  State<GlowOrb> createState() => _GlowOrbState();
}

class _GlowOrbState extends State<GlowOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant GlowOrb old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _OrbPainter(
            phase: _controller.value * 2 * math.pi,
            intensity: widget.intensity,
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.phase, required this.intensity});

  final double phase;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // ---- Halo de fundo -------------------------------------------------
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.waveDeep.withValues(alpha: 0.32 * intensity),
          AppColors.waveMid.withValues(alpha: 0.12 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius * 0.98, haloPaint);

    // ---- Fitas ---------------------------------------------------------
    const ribbons = 7;
    for (var r = 0; r < ribbons; r++) {
      final spin = phase + r * 0.82;
      final path = _ribbonPath(center, radius, spin, r);

      final shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.waveDeep.withValues(alpha: 0.20 + 0.55 * intensity),
          AppColors.waveBright.withValues(alpha: 0.30 + 0.45 * intensity),
          AppColors.waveCyan.withValues(alpha: 0.16 + 0.30 * intensity),
          AppColors.waveDeep.withValues(alpha: 0.22),
        ],
        stops: const [0.0, 0.38, 0.72, 1.0],
      ).createShader(Offset.zero & size);

      // Glow
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawPath(path, glowPaint);

      // Traço principal
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = shader
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, paint);

      // Fio interno mais fino, deslocado — cria a "trança" do original.
      final innerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..shader = shader
        ..color = AppColors.waveGlow.withValues(alpha: 0.30 * intensity);
      canvas.drawPath(
        _ribbonPath(center, radius * 0.94, spin + 0.18, r),
        innerPaint,
      );
    }
  }

  /// Constrói uma fita fechada que se auto-intersecta, lembrando o nó
  /// tridimensional da referência.
  Path _ribbonPath(Offset center, double radius, double spin, int index) {
    final path = Path();
    const points = 9;
    final offset = index * 0.42;

    for (var i = 0; i <= points; i++) {
      final a = spin + i * (2 * math.pi / points) * 1.0;
      final wobble = 1 + 0.30 * math.sin(a * 2.3 + offset);
      final r = radius * 0.58 * wobble;
      final p = Offset(
        center.dx + math.cos(a) * r,
        center.dy + math.sin(a) * r * 0.92,
      );

      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        // Curva suave entre os pontos, gerando o dobramento da fita.
        final prevAngle = spin + (i - 1) * (2 * math.pi / points);
        final prevWobble = 1 + 0.30 * math.sin(prevAngle * 2.3 + offset);
        final prev = Offset(
          center.dx + math.cos(prevAngle) * radius * 0.58 * prevWobble,
          center.dy + math.sin(prevAngle) * radius * 0.58 * prevWobble * 0.92,
        );
        final mid = Offset(
          (prev.dx + p.dx) / 2 + math.cos(a + 1.2) * radius * 0.13,
          (prev.dy + p.dy) / 2 + math.sin(a + 1.2) * radius * 0.13,
        );
        path.quadraticBezierTo(mid.dx, mid.dy, p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.phase != phase || old.intensity != intensity;
}
