import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/waveform_view.dart';
import '../../models/recording.dart';
import '../../services/audio_player_service.dart';
import '../../services/recording_repository.dart';

/// Tela de edição — a terceira do protótipo.
///
/// Topo:    back, "Editing", menu "...".
/// Corpo:   texto transcrito, tempo selecionado, waveform com cursor
///          arrastável e a barra de ferramentas (Texto / Trim / Volume /
///          Enhance).
/// Base:    teclado do sistema com a barra de ferramentas acima dele.
class EditingScreen extends StatefulWidget {
  const EditingScreen({super.key, required this.recording});

  final Recording recording;

  @override
  State<EditingScreen> createState() => _EditingScreenState();
}

class _EditingScreenState extends State<EditingScreen> {
  final AudioPlayerService _player = AudioPlayerService();
  final RecordingRepository _repository = RecordingRepository();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  late Recording _recording = widget.recording;
  late double _duration = widget.recording.duration;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;

  double _position = 0;
  bool _playing = false;
  bool _dirty = false;

  /// Estado de cada ferramenta da barra.
  bool _toolText = true;
  bool _toolTrim = false;
  bool _toolVolume = false;
  bool _toolEnhance = false;

  /// Fatores aplicados pelas ferramentas de volume/enhance.
  double _volumeGain = 1.0;
  double _enhanceAmount = 0.5;

  /// Faixa selecionada para corte (início/fim em segundos).
  double? _trimStart;
  double? _trimEnd;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.recording.transcript;
    _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _position = pos.inMilliseconds / 1000;
        if (_position > _duration) _duration = _position;
      });
    });
    _player.playingStream.listen((playing) {
      if (!mounted) return;
      setState(() => _playing = playing);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Reprodução
  // -------------------------------------------------------------------
  Future<void> _togglePlay() async {
    HapticFeedback.selectionClick();
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(_recording.filePath);
    }
  }

  Future<void> _seek(double seconds) async {
    await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
    if (mounted) {
      setState(() => _position = seconds.clamp(0, _duration));
    }
  }

  // -------------------------------------------------------------------
  // Edição
  // -------------------------------------------------------------------
  Future<void> _save() async {
    _recording = _recording.copyWith(
      transcript: _textController.text.trim(),
      duration: _duration,
    );
    await _repository.save(_recording);
    await _repository.saveDraftTranscript(_recording.transcript);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transcription saved')),
    );
  }

  Future<void> _showMoreMenu() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _MenuItem(
              icon: AppIcons.fileText,
              label: 'Rename',
              onTap: () {
                Navigator.of(context).pop();
                _renameRecording();
              },
            ),
            _MenuItem(
              icon: AppIcons.share,
              label: 'Share text',
              onTap: () {
                Navigator.of(context).pop();
                Clipboard.setData(
                  ClipboardData(text: _textController.text),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Text copied to clipboard')),
                );
              },
            ),
            _MenuItem(
              icon: AppIcons.trash,
              label: 'Delete recording',
              destructive: true,
              onTap: () {
                Navigator.of(context).pop();
                _confirmDelete();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _renameRecording() async {
    final controller =
        TextEditingController(text: _recording.displayTitle);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Rename recording',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          cursorColor: AppColors.accentBright,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await _repository.rename(_recording.id, name);
      setState(() => _recording = _recording.copyWith(title: name));
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete recording?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'This removes the audio file and its transcription from your device.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.record,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await _repository.delete(_recording.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  // -------------------------------------------------------------------
  // Widgets
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = viewInsets > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBackground),
          child: SafeArea(
            bottom: !keyboardOpen,
            child: Column(
              children: [
                _TopBar(
                  onBack: () => Navigator.of(context).maybePop(),
                  onMore: _showMoreMenu,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TranscriptField(
                          controller: _textController,
                          focusNode: _textFocus,
                          onChanged: () => setState(() => _dirty = true),
                        ),
                        const SizedBox(height: 18),
                        _TimeSelector(
                          position: _position,
                          duration: _duration,
                          onSeek: _seek,
                        ),
                        const SizedBox(height: 6),
                        _WaveformEditor(
                          peaks: _recording.amplitudePeaks,
                          progress: _duration == 0
                              ? 0
                              : (_position / _duration).clamp(0.0, 1.0),
                          trimStart: _trimStart,
                          trimEnd: _trimEnd,
                          trimActive: _toolTrim,
                          onSeek: _seek,
                          onTrimChanged: (start, end) {
                            setState(() {
                              _trimStart = start;
                              _trimEnd = end;
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        _PlaybackRow(
                          playing: _playing,
                          position: _position,
                          duration: _duration,
                          onPlay: _togglePlay,
                          onSeek: _seek,
                        ),
                        const SizedBox(height: 14),
                        _ToolBar(
                          toolText: _toolText,
                          toolTrim: _toolTrim,
                          toolVolume: _toolVolume,
                          toolEnhance: _toolEnhance,
                          onText: () => setState(() {
                            _toolText = true;
                            _toolTrim = false;
                            _toolVolume = false;
                            _toolEnhance = false;
                          }),
                          onTrim: () => setState(() {
                            _toolTrim = !_toolTrim;
                            _toolText = false;
                            _toolVolume = false;
                            _toolEnhance = false;
                          }),
                          onVolume: () => setState(() {
                            _toolVolume = !_toolVolume;
                            _toolText = false;
                            _toolTrim = false;
                            _toolEnhance = false;
                          }),
                          onEnhance: () => setState(() {
                            _toolEnhance = !_toolEnhance;
                            _toolText = false;
                            _toolTrim = false;
                            _toolVolume = false;
                          }),
                        ),
                        if (_toolVolume || _toolEnhance) ...[
                          const SizedBox(height: 14),
                          _AdjustPanel(
                            title: _toolVolume ? 'Volume' : 'Enhance voice',
                            value: _toolVolume ? _volumeGain : _enhanceAmount,
                            min: _toolVolume ? 0.5 : 0.0,
                            max: _toolVolume ? 2.0 : 1.0,
                            onChanged: (v) => setState(() {
                              if (_toolVolume) {
                                _volumeGain = v;
                              } else {
                                _enhanceAmount = v;
                              }
                            }),
                          ),
                        ],
                        if (_toolTrim) ...[
                          const SizedBox(height: 14),
                          _TrimPanel(
                            duration: _duration,
                            start: _trimStart,
                            end: _trimEnd,
                            onChanged: (s, e) => setState(() {
                              _trimStart = s;
                              _trimEnd = e;
                            }),
                            onApply: () {
                              final s = _trimStart;
                              final e = _trimEnd;
                              if (s != null && e != null && e > s) {
                                setState(() {
                                  _duration = e - s;
                                  _position = 0;
                                });
                                _seek(0);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Trimmed to '
                                      '${formatDuration(_duration)}',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _dirty ? _save : null,
                            icon: const AppIcon(
                              AppIcons.check,
                              size: 17,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Save transcription',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// Barra superior
// ==========================================================================
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onMore});

  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          _IconButton(icon: AppIcons.chevronLeft, onTap: onBack),
          const Expanded(
            child: Text(
              'Editing',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _IconButton(icon: AppIcons.more, onTap: onMore),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: AppIcon(icon, size: 21, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.record : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        child: Row(
          children: [
            AppIcon(icon, size: 19, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// Campo de transcrição
// ==========================================================================
class _TranscriptField extends StatelessWidget {
  const _TranscriptField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: null,
      minLines: 2,
      onChanged: (_) => onChanged(),
      style: const TextStyle(
        fontSize: 16,
        height: 1.45,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w400,
      ),
      cursorColor: AppColors.accentBright,
      cursorWidth: 2,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintText: 'Add a transcription…',
        hintStyle: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 16,
          height: 1.45,
        ),
      ),
    );
  }
}

// ==========================================================================
// Seletor de tempo
// ==========================================================================
class _TimeSelector extends StatelessWidget {
  const _TimeSelector({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final double position;
  final double duration;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final label = formatDuration(position);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.accentBright,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: AppColors.accentBright,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// Editor de waveform com cursor
// ==========================================================================
class _WaveformEditor extends StatelessWidget {
  const _WaveformEditor({
    required this.peaks,
    required this.progress,
    required this.onSeek,
    required this.onTrimChanged,
    this.trimStart,
    this.trimEnd,
    this.trimActive = false,
  });

  final List<double> peaks;
  final double progress;
  final ValueChanged<double> onSeek;
  final ValueChanged<double?> Function(double? start, double? end) onTrimChanged;
  final double? trimStart;
  final double? trimEnd;
  final bool trimActive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = 96.0;

        void handle(Offset local) {
          final ratio = (local.dx / width).clamp(0.0, 1.0);
          onSeek(ratio * (trimActive ? (trimEnd ?? 1.0) - (trimStart ?? 0.0) : 1.0) +
              (trimActive ? (trimStart ?? 0.0) : 0.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => handle(d.localPosition),
          onHorizontalDragUpdate: (d) => handle(d.localPosition),
          onHorizontalDragEnd: (_) {
            if (trimActive) {
              onTrimChanged(trimStart, trimEnd);
            }
          },
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.divider,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: WaveformView(
                    peaks: peaks,
                    style: WaveformStyle.bars,
                    progress: progress,
                    barWidth: 3,
                    barGap: 2.4,
                    height: height - 20,
                  ),
                ),
                // Cursor arrastável
                Positioned(
                  left: (width * progress).clamp(0.0, width - 1.5),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: AppColors.accentBright,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentBright.withValues(alpha: 0.7),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: (width * progress - 4).clamp(0.0, width - 8),
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accentBright,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Faixa de trim
                if (trimActive && trimStart != null && trimEnd != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TrimOverlayPainter(
                        width: width,
                        height: height,
                        start: trimStart!,
                        end: trimEnd!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrimOverlayPainter extends CustomPainter {
  _TrimOverlayPainter({
    required this.width,
    required this.height,
    required this.start,
    required this.end,
  });

  final double width;
  final double height;
  final double start;
  final double end;

  @override
  void paint(Canvas canvas, Size size) {
    final s = (start.clamp(0.0, 1.0)) * width;
    final e = (end.clamp(0.0, 1.0)) * width;

    final shade = Paint()..color = Colors.black.withValues(alpha: 0.62);
    canvas.drawRect(Rect.fromLTWH(0, 0, s, height), shade);
    canvas.drawRect(Rect.fromLTWH(e, 0, width - e, height), shade);

    final handle = Paint()
      ..color = AppColors.accentBright
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(s - 1.5, 0, 3, height), handle);
    canvas.drawRect(Rect.fromLTWH(e - 1.5, 0, 3, height), handle);
  }

  @override
  bool shouldRepaint(covariant _TrimOverlayPainter old) =>
      old.start != start || old.end != end;
}

// ==========================================================================
// Reprodução
// ==========================================================================
class _PlaybackRow extends StatelessWidget {
  const _PlaybackRow({
    required this.playing,
    required this.position,
    required this.duration,
    required this.onPlay,
    required this.onSeek,
  });

  final bool playing;
  final double position;
  final double duration;
  final VoidCallback onPlay;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final ratio = duration <= 0 ? 0.0 : (position / duration).clamp(0.0, 1.0);
    return Row(
      children: [
        _IconButton(icon: AppIcons.rotate, onTap: () => onSeek(0)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: ratio,
              onChanged: (v) => onSeek(v * duration),
            ),
          ),
        ),
        Text(
          formatDuration(duration),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.accent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPlay,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: AppIcon(
                  playing ? AppIcons.pause : AppIcons.play,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// Barra de ferramentas (Texto / Trim / Volume / Enhance)
// ==========================================================================
class _ToolBar extends StatelessWidget {
  const _ToolBar({
    required this.toolText,
    required this.toolTrim,
    required this.toolVolume,
    required this.toolEnhance,
    required this.onText,
    required this.onTrim,
    required this.onVolume,
    required this.onEnhance,
  });

  final bool toolText;
  final bool toolTrim;
  final bool toolVolume;
  final bool toolEnhance;
  final VoidCallback onText;
  final VoidCallback onTrim;
  final VoidCallback onVolume;
  final VoidCallback onEnhance;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ToolButton(
            icon: AppIcons.text,
            label: 'Text',
            active: toolText,
            onTap: onText,
          ),
          _ToolButton(
            icon: AppIcons.trim,
            label: 'Trim',
            active: toolTrim,
            onTap: onTrim,
          ),
          _ToolButton(
            icon: AppIcons.volume,
            label: 'Volume',
            active: toolVolume,
            onTap: onVolume,
          ),
          _ToolButton(
            icon: AppIcons.enhance,
            label: 'Enhance',
            active: toolEnhance,
            onTap: onEnhance,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accentBright : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 19, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// Painel de ajuste (volume / enhance)
// ==========================================================================
class _AdjustPanel extends StatelessWidget {
  const _AdjustPanel({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = ((value - min) / (max - min) * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentBright,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// Painel de trim
// ==========================================================================
class _TrimPanel extends StatelessWidget {
  const _TrimPanel({
    required this.duration,
    required this.start,
    required this.end,
    required this.onChanged,
    required this.onApply,
  });

  final double duration;
  final double? start;
  final double? end;
  final void Function(double? start, double? end) onChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final s = start ?? 0.0;
    final e = end ?? duration;
    final label = duration <= 0
        ? '0.0s'
        : '${((s / duration) * 100).round()}% – ${((e / duration) * 100).round()}%';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const AppIcon(
                AppIcons.trim,
                size: 17,
                color: AppColors.accentBright,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Trim range',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.accentBright,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Start',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'End',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          RangeSlider(
            values: RangeValues(
              s.clamp(0.0, math.max(0.0, duration)),
              e.clamp(0.0, math.max(0.0, duration)),
            ),
            min: 0,
            max: duration <= 0 ? 1 : duration,
            activeColor: AppColors.accentBright,
            inactiveColor: AppColors.dividerStrong,
            onChanged: (range) => onChanged(range.start, range.end),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onApply,
              child: const Text(
                'Apply trim',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
