import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/glow_orb.dart';
import '../../core/widgets/waveform_view.dart';
import '../../services/app_scope.dart';
import '../record/record_screen.dart';

/// Tela de boas-vindas — a primeira do protótipo.
///
/// Estrutura vertical:
///  * título grande em duas linhas ("Speech / Recognition");
///  * subtítulo curto em cinza;
///  * orbe luminoso central (o "nó" azul do mockup);
///  * rodapé com pílula "Start Now" entre chevrons.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  /// Indica se as animacoes pesadas estao ativas.
  ///
  /// Vem desligado por padrao: o orbe luminoso da tela inicial redesenha
  /// dezenas de curvas a cada quadro e pesa em aparelhos modestos. Com a
  /// preferencia desligada, desenhamos um unico quadro estatico.
  bool get _animationsEnabled =>
      AppScope.maybeOf(context)?.animationsEnabled ?? false;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  late final Animation<double> _orbFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _orbScale = Tween<double>(
    begin: 0.72,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.15, 0.95, curve: Curves.easeOutBack),
    ),
  );

  late final Animation<double> _textFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
  );

  late final Animation<Offset> _ctaSlide = Tween<Offset>(
    begin: const Offset(0, 0.35),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
    ),
  );

  /// Opacidade do CTA, derivada da mesma animação de entrada do botão.
  late final Animation<double> _ctaOpacity = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _startNow() async {
    unawaited(HapticFeedback.mediumImpact());
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => const RecordScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final keyboard = media.viewInsets.bottom > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBackground,
          ),
          child: Stack(
            children: [
              // Brilho difuso no topo, como a luz de estúdio do mockup.
              Positioned(
                top: -140,
                left: -60,
                right: -60,
                height: 420,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppColors.waveDeep.withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(26, 26, 26, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FadeTransition(
                                opacity: _textFade,
                                child: const Text(
                                  'Speech\nRecognition',
                                  style: TextStyle(
                                    fontSize: 31,
                                    height: 1.16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FadeTransition(
                                opacity: _textFade,
                                child: const SizedBox(
                                  width: 220,
                                  child: Text(
                                    'Save time with smart\nvoice transcription.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.42,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FadeTransition(
                                opacity: _orbFade,
                                child: Center(
                                  child: ScaleTransition(
                                    scale: _orbScale,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // O orbe so fica animado quando o
                                        // usuario liga as animacoes nas
                                        // configuracoes — por padrao a tela
                                        // inicial desenha um quadro estatico
                                        // e o app nao gasta bateria.
                                        GlowOrb(
                                          size: 268,
                                          animate: _animationsEnabled,
                                        ),
                                        // Faixa de onda sobreposta, como no mockup.
                                        IgnorePointer(
                                          child: Opacity(
                                            opacity: 0.34,
                                            child: Container(
                                              height: 118,
                                              width: 220,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.waveBright
                                                      .withValues(alpha: 0.35),
                                                  width: 0.8,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // --------------------------------------------------
                      // Rodapé: pílula "Start Now"
                      // --------------------------------------------------
                      SlideTransition(
                        position: _ctaSlide,
                        child: AnimatedBuilder(
                          animation: _ctaOpacity,
                          builder: (context, child) => Opacity(
                            opacity: _ctaOpacity.value,
                            child: child,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(26, 12, 26, 26),
                            child: _StartPill(onTap: _startNow),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (keyboard)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(height: bottomInset),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pílula "Start Now" com os chevrons laterais do protótipo.
class _StartPill extends StatefulWidget {
  const _StartPill({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_StartPill> createState() => _StartPillState();
}

class _StartPillState extends State<_StartPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.ctaGradient,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.divider, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 18),
              const AppIcon(
                AppIcons.chevronLeft,
                size: 22,
                color: AppColors.textPrimary,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Start Now',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: _hovered
                          ? AppColors.waveBright
                          : AppColors.textSecondary,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
              const AppIcon(
                AppIcons.chevronRight,
                size: 22,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador reutilizável da onda viva na home (não usado na home atual,
/// mantido para a tela de gravação importar).
class LiveWavePreview extends StatelessWidget {
  const LiveWavePreview({super.key, this.peaks = const []});

  final List<double> peaks;

  @override
  Widget build(BuildContext context) {
    return WaveformView(peaks: peaks, style: WaveformStyle.mesh, height: 90);
  }
}
