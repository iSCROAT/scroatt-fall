import 'package:flutter/material.dart';

/// Paleta extraída do protótipo de referência.
///
/// O design original é um "dark glass" azul profundo com acentos em ciano
/// elétrico. Todas as cores abaixo foram amostradas do mockup para manter a
/// fidelidade visual.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------
  // Fundos — do quase-preto azulado ao gradiente profundo da home.
  // ---------------------------------------------------------------------
  static const Color background = Color(0xFF05070D);
  static const Color backgroundElevated = Color(0xFF0B1020);
  static const Color surface = Color(0xFF10172A);
  static const Color surfaceHigh = Color(0xFF17203A);
  static const Color surfaceGlass = Color(0x66131B33);

  // ---------------------------------------------------------------------
  // Azuis da onda sonora (gradiente do traço).
  // ---------------------------------------------------------------------
  static const Color waveDeep = Color(0xFF1B4DFF);
  static const Color waveMid = Color(0xFF2E8BFF);
  static const Color waveBright = Color(0xFF46E0FF);
  static const Color waveCyan = Color(0xFF7AF3FF);
  static const Color waveGlow = Color(0xFF9BF6FF);

  // ---------------------------------------------------------------------
  // Acentos.
  // ---------------------------------------------------------------------
  static const Color accent = Color(0xFF2F6BFF);
  static const Color accentBright = Color(0xFF46E0FF);
  static const Color record = Color(0xFFFF3B5C);
  static const Color success = Color(0xFF2BD98A);
  static const Color warning = Color(0xFFFFB020);

  // ---------------------------------------------------------------------
  // Texto.
  // ---------------------------------------------------------------------
  static const Color textPrimary = Color(0xFFF4F7FF);
  static const Color textSecondary = Color(0xFFA7B2CC);
  static const Color textTertiary = Color(0xFF6B7794);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------
  // Estruturas / linhas.
  // ---------------------------------------------------------------------
  static const Color divider = Color(0x1AFFFFFF);
  static const Color dividerStrong = Color(0x33FFFFFF);
  static const Color keyboardKey = Color(0xFF1E2436);
  static const Color keyboardKeyAlt = Color(0xFF2A3247);

  /// Gradiente principal da onda / fundo do botão de gravação.
  static const LinearGradient waveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B4DFF), Color(0xFF2E8BFF), Color(0xFF46E0FF)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Gradiente do botão de gradiente da home ("Start Now").
  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF24304A), Color(0xFF1A2033)],
  );

  /// Gradiente de fundo do app.
  static const LinearGradient appBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF070B16), Color(0xFF05070D)],
  );
}
