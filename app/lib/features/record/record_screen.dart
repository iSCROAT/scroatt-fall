import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/waveform_view.dart';
import '../../models/recording.dart';
import '../../services/audio_recorder_service.dart';
import '../../services/recording_repository.dart';
import '../editing/editing_screen.dart';

/// Tela de gravação — a segunda do protótipo.
///
/// Topo: back, título "Record", ícone de settings.
/// Centro: malha de onda luminosa + frase transcrita + duração.
/// Base: controles de filtro (esquerda), botão de gravar (centro),
/// botão de marcar momento (direita).
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with TickerProviderStateMixin {
  final AudioRecorderService _recorder = AudioRecorderService();
  final RecordingRepository _repository = RecordingRepository();

  late final AnimationController _orbController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  StreamSubscription<double>? _ampSub;
  Timer? _ticker;

  final List<double> _livePeaks = <double>[];
  final List<double> _savedPeaks = <double>[];

  double _amplitude = 0;
  double _elapsed = 0;
  bool _recording = false;
  bool _paused = false;
  bool _permissionDenied = false;
  String _transcript = 'Hello Alex,\nHow are you today?';
  bool _hasSpeech = true;

  /// Marcadores de "momentos" adicionados pelo usuário durante a gravação.
  final List<double> _bookmarks = <double>[];

  @override
  void initState() {
    super.initState();
    _restoreTranscript();
  }

  Future<void> _restoreTranscript() async {
    final draft = await _repository.loadDraftTranscript();
    if (!mounted) return;
    if (draft != null && draft.trim().isNotEmpty) {
      setState(() {
        _transcript = draft;
        _hasSpeech = true;
      });
    }
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _ticker?.cancel();
    _recorder.dispose();
    _orbController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Amostragem de amplitude
  // -------------------------------------------------------------------
  void _onAmplitude(double value) {
    if (!mounted) return;
    setState(() {
      _amplitude = value;
      _livePeaks.add(value);
      if (_livePeaks.length > 160) _livePeaks.removeAt(0);
      _savedPeaks.add(value);
      if (_savedPeaks.length > 4000) _savedPeaks.removeAt(0);
    });
  }

  // -------------------------------------------------------------------
  // Permissão
  // -------------------------------------------------------------------
  Future<bool> _ensurePermission() async {
    final status = await _recorder.requestPermission();
    if (status == MicPermission.granted) return true;
    if (mounted) {
      setState(() => _permissionDenied = true);
      _showPermissionSheet(status);
    }
    return false;
  }

  void _showPermissionSheet(MicPermission status) {
    final permanent = status == MicPermission.permanentlyDenied;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(
              AppIcons.micOff,
              size: 40,
              color: AppColors.accentBright,
            ),
            const SizedBox(height: 18),
            Text(
              permanent
                  ? 'Microphone blocked'
                  : 'Microphone access needed',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              permanent
                  ? 'Scroatt needs the microphone to record audio. The '
                      'permission was blocked, so you have to enable it in '
                      'the system Settings.'
                  : 'Scroatt needs the microphone to record audio. Enable it '
                      'in Settings to start capturing your voice.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (permanent)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _recorder.openSystemSettings();
                  },
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Gravar / parar
  // -------------------------------------------------------------------
  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!await _ensurePermission()) return;

    unawaited(HapticFeedback.mediumImpact());
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

      setState(() {
        _livePeaks.clear();
        _savedPeaks.clear();
        _bookmarks.clear();
        _elapsed = 0;
        _recording = true;
        _paused = false;
        _permissionDenied = false;
      });

      await _recorder.start(path);
      _ampSub = _recorder.amplitudeStream.listen(_onAmplitude);
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        setState(() => _elapsed += 0.1);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _permissionDenied = true;
      });
      _showError('Could not start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    unawaited(HapticFeedback.heavyImpact());
    final path = await _recorder.stop();
    await _ampSub?.cancel();
    _ticker?.cancel();

    if (!mounted) return;

    final duration = _elapsed;
    final peaks = List<double>.from(_savedPeaks);

    setState(() {
      _recording = false;
      _paused = false;
    });

    if (path == null) {
      _showError('Nothing was recorded.');
      return;
    }

    final recording = Recording(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filePath: path,
      createdAt: DateTime.now(),
      duration: duration,
      transcript: _transcript,
      amplitudePeaks: peaks,
    );

    await _repository.save(recording);

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditingScreen(recording: recording),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // -------------------------------------------------------------------
  // Ações
  // -------------------------------------------------------------------
  void _addBookmark() {
    if (!_recording) {
      _showError('Start a recording to mark a moment.');
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    setState(() => _bookmarks.add(_elapsed));
  }

  Future<void> _openSettings() async {
    unawaited(HapticFeedback.selectionClick());
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      isScrollControlled: true,
      builder: (_) => const _SettingsSheet(),
    );
  }

  /// Leva o usuário às configurações do sistema para liberar o microfone.
  Future<void> _openSystemSettings() async {
    unawaited(HapticFeedback.selectionClick());
    await _recorder.openSystemSettings();
    if (!mounted) return;
    // Ao voltar das configurações, reavaliamos a permissão.
    final status = await _recorder.requestPermission();
    if (!mounted) return;
    setState(() {
      _permissionDenied = status != MicPermission.granted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final meshPeaks = _recording
        ? _livePeaks
        : (_livePeaks.isNotEmpty ? _livePeaks : const <double>[]);

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
          decoration: const BoxDecoration(gradient: AppColors.appBackground),
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(onSettings: _openSettings, recording: _recording),
                if (_permissionDenied)
                  _PermissionBanner(onOpenSettings: _openSystemSettings),
                Expanded(
                  child: Stack(
                    children: [
                      // ------------------------------------------------
                      // Onda em malha (fundo)
                      // ------------------------------------------------
                      Positioned.fill(
                        child: Opacity(
                          opacity: _recording ? 0.95 : 0.55,
                          child: WaveformView(
                            peaks: meshPeaks,
                            style: WaveformStyle.mesh,
                            animate: true,
                            height: MediaQuery.of(context).size.height * 0.62,
                            color: AppColors.waveBright,
                          ),
                        ),
                      ),
                      // ------------------------------------------------
                      // Conteúdo central
                      // ------------------------------------------------
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 34),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: _orbController,
                                builder: (_, __) => Transform.scale(
                                  scale: 1 +
                                      math.sin(
                                        _orbController.value * 2 * math.pi,
                                      ) *
                                          0.012,
                                  child: _LiveOrb(
                                    amplitude: _amplitude,
                                    recording: _recording,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              _TranscriptBlock(
                                transcript: _transcript,
                                hasSpeech: _hasSpeech,
                                onEdit: _editTranscript,
                              ),
                              const SizedBox(height: 16),
                              _DurationLabel(
                                seconds: _elapsed,
                                recording: _recording,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _BottomControls(
                  recording: _recording,
                  paused: _paused,
                  onRecordTap: _toggleRecording,
                  onBookmarkTap: _addBookmark,
                  bookmarks: _bookmarks,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editTranscript() async {
    final controller = TextEditingController(text: _transcript);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundElevated,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 26,
          bottom: MediaQuery.of(context).viewInsets.bottom + 26,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transcription',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.4,
              ),
              cursorColor: AppColors.accentBright,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                hintText: 'Type what was said…',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(controller.text.trim()),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _transcript = result;
        _hasSpeech = result.isNotEmpty;
      });
      await _repository.saveDraftTranscript(result);
    }
  }
}

// ==========================================================================
// Barra superior
// ==========================================================================
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings, this.recording = false});

  final VoidCallback onSettings;

  /// Indica que há uma gravação em andamento (ainda não salva).
  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        children: [
          _CircleButton(
            icon: AppIcons.chevronLeft,
            onTap: () => Navigator.of(context).maybePop(),
            size: 40,
            iconSize: 22,
          ),
          const Expanded(
            child: Text(
              'Record',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _CircleButton(
            icon: AppIcons.settings,
            onTap: onSettings,
            size: 40,
            iconSize: 21,
            badge: recording,
          ),
        ],
      ),
    );
  }
}

// Aviso exibido quando o acesso ao microfone está bloqueado
// ==========================================================================
class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onOpenSettings});

  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.record.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.record.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const AppIcon(
              AppIcons.micOff,
              size: 20,
              color: AppColors.record,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Microphone access blocked',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentBright,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 20,
    this.badge = false,
  });

  final String icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AppIcon(icon, size: iconSize, color: AppColors.textPrimary),
              if (badge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accentBright,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// Orbe central reativo à amplitude
// ==========================================================================
class _LiveOrb extends StatelessWidget {
  const _LiveOrb({required this.amplitude, required this.recording});

  final double amplitude;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: recording
              ? [
                  AppColors.waveBright.withValues(alpha: 0.26 + amplitude * 0.30),
                  AppColors.waveDeep.withValues(alpha: 0.14),
                  Colors.transparent,
                ]
              : [
                  AppColors.waveMid.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
        ),
      ),
      child: Center(
        child: Container(
          width: 54 + amplitude * 16,
          height: 54 + amplitude * 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.waveGlow.withValues(alpha: 0.55),
                AppColors.waveBright.withValues(alpha: 0.16),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// Bloco de transcrição
// ==========================================================================
class _TranscriptBlock extends StatelessWidget {
  const _TranscriptBlock({
    required this.transcript,
    required this.hasSpeech,
    required this.onEdit,
  });

  final String transcript;
  final bool hasSpeech;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (!hasSpeech) {
      return GestureDetector(
        onTap: onEdit,
        child: Column(
          children: [
            const Text(
              'Listening…',
              style: TextStyle(
                fontSize: 25,
                height: 1.24,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon(
                  AppIcons.edit,
                  size: 15,
                  color: AppColors.accentBright,
                ),
                const SizedBox(width: 7),
                Text(
                  'Tap to add a transcript',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.accentBright.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onEdit,
      child: Text(
        transcript,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 25,
          height: 1.24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

// ==========================================================================
// Duração
// ==========================================================================
class _DurationLabel extends StatelessWidget {
  const _DurationLabel({required this.seconds, required this.recording});

  final double seconds;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording ? AppColors.record : AppColors.textTertiary,
            boxShadow: recording
                ? [
                    BoxShadow(
                      color: AppColors.record.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          formatDuration(seconds),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: recording
                ? AppColors.textPrimary
                : AppColors.textTertiary,
            letterSpacing: 0.4,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// Controles inferiores
// ==========================================================================
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.recording,
    required this.paused,
    required this.onRecordTap,
    required this.onBookmarkTap,
    required this.bookmarks,
  });

  final bool recording;
  final bool paused;
  final VoidCallback onRecordTap;
  final VoidCallback onBookmarkTap;
  final List<double> bookmarks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0005070D), Color(0xE605070D)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AuxButton(
            icon: AppIcons.trim,
            label: 'Filters',
            active: recording,
            onTap: () => _showFilters(context),
          ),
          _RecordButton(
            recording: recording,
            onTap: onRecordTap,
          ),
          _AuxButton(
            icon: AppIcons.bookmark,
            label: bookmarks.isEmpty
                ? 'Mark'
                : '${bookmarks.length}',
            active: bookmarks.isNotEmpty,
            onTap: onBookmarkTap,
          ),
        ],
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      builder: (context) => const _FiltersSheet(),
    );
  }
}

/// Botão deakah auxiliar (filtros / marcar momento).
class _AuxButton extends StatelessWidget {
  const _AuxButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.active,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.accent.withValues(alpha: 0.20)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? AppColors.accentBright.withValues(alpha: 0.55)
                      : AppColors.dividerStrong,
                ),
              ),
              child: Center(
                child: AppIcon(
                  icon,
                  size: 20,
                  color: active
                      ? AppColors.accentBright
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: active
                    ? AppColors.accentBright
                    : AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão principal de gravação: microcone quando ocioso, quadrado quando
/// gravando — anel pulsante com gradiente azul.
class _RecordButton extends StatefulWidget {
  const _RecordButton({required this.recording, required this.onTap});

  final bool recording;
  final VoidCallback onTap;

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.recording) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _RecordButton old) {
    super.didUpdateWidget(old);
    if (widget.recording && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.recording && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 92,
        height: 92,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = widget.recording ? _pulse.value : 0.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                if (widget.recording)
                  Container(
                    width: 92 - 22 * t,
                    height: 92 - 22 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentBright
                            .withValues(alpha: 0.55 * (1 - t)),
                        width: 1.6,
                      ),
                    ),
                  ),
                child!,
              ],
            );
          },
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.waveDeep, AppColors.waveBright],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.55),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: widget.recording
                    ? Container(
                        key: const ValueKey('stop'),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : const AppIcon(
                        AppIcons.mic,
                        key: ValueKey('mic'),
                        size: 28,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// Sheet de filtros
// ==========================================================================
class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet();

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  bool _noiseReduction = true;
  bool _autoGain = true;
  bool _echoCancel = false;
  double _enhance = 0.62;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recording quality',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 18),
            _FilterToggle(
              icon: AppIcons.enhance,
              title: 'Noise reduction',
              subtitle: 'Suppress background hiss and rumble',
              value: _noiseReduction,
              onChanged: (v) => setState(() => _noiseReduction = v),
            ),
            _FilterToggle(
              icon: AppIcons.activity,
              title: 'Auto gain',
              subtitle: 'Level the microphone automatically',
              value: _autoGain,
              onChanged: (v) => setState(() => _autoGain = v),
            ),
            _FilterToggle(
              icon: AppIcons.radio,
              title: 'Echo cancellation',
              subtitle: 'Remove speaker feedback on calls',
              value: _echoCancel,
              onChanged: (v) => setState(() => _echoCancel = v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const AppIcon(
                  AppIcons.volume,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Enhance',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${(_enhance * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.accentBright,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Slider(
              value: _enhance,
              onChanged: (v) => setState(() => _enhance = v),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Apply',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: AppIcon(icon, size: 18, color: AppColors.accentBright),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ==========================================================================
// Sheet de configurações
// ==========================================================================
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  String _language = 'en-US';
  bool _saveToDevice = true;
  double _quality = 128;

  static const _languages = {
    'en-US': 'English (US)',
    'en-GB': 'English (UK)',
    'pt-BR': 'Português (Brasil)',
    'es-ES': 'Español',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'TRANSCRIPTION LANGUAGE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 10),
            ..._languages.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _LanguageOption(
                  label: entry.value,
                  code: entry.key,
                  selected: _language == entry.key,
                  onTap: () => setState(() => _language = entry.key),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'AUDIO QUALITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _quality,
                    min: 64,
                    max: 256,
                    divisions: 3,
                    onChanged: (v) => setState(() => _quality = v),
                  ),
                ),
                SizedBox(
                  width: 62,
                  child: Text(
                    '${_quality.round()}k',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.accentBright,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _FilterToggle(
              icon: AppIcons.download,
              title: 'Keep recordings on device',
              subtitle: 'Store every take in local storage',
              value: _saveToDevice,
              onChanged: (v) => setState(() => _saveToDevice = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const AppIcon(
              AppIcons.globe,
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              code,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textTertiary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 22,
              child: selected
                  ? const AppIcon(
                      AppIcons.check,
                      size: 17,
                      color: AppColors.accentBright,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
