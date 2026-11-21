import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_icon.dart';
import '../../models/recording.dart';
import '../../services/app_scope.dart';
import '../../services/app_settings.dart';
import '../editing/editing_screen.dart';

/// Biblioteca de gravações — lista de todas as takes salvas.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  /// Estado compartilhado — a biblioteca acompanha as mudanças de nome,
  /// animação e gravações sem manter uma cópia paralela.
  AppSettings? _settings;

  bool _loading = true;
  String _query = '';

  /// Indica que a sincronizacao com os arquivos existentes esta em curso.
  bool _syncing = false;

  /// Procura arquivos de audio na pasta configurada e adiciona os que
  /// ainda nao estao no indice.
  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final added = await _settings?.syncWithExistingFiles() ?? 0;
    if (!mounted) return;
    setState(() => _syncing = false);
    if (added == 0) {
      _showMessage('Nenhum audio novo encontrado.');
      return;
    }
    _showMessage(
      added == 1
          ? '1 gravacao adicionada.'
          : '$added gravacoes adicionadas.',
    );
  }

  /// Mostra uma mensagem breve no rodape da tela.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A lista vem pronta do estado compartilhado — não há carregamento
    // próprio para esperar.
    _settings ??= AppScope.of(context);
    _loading = false;
  }

  List<Recording> get _recordings => _settings?.recordings ?? const [];

  List<Recording> get _filtered => _settings?.search(_query) ?? const [];

  /// Recarrega as gravações ao puxar a lista para baixo.
  Future<void> _refresh() async {
    await _settings?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final totalDuration =
        _recordings.fold<double>(0, (sum, r) => sum + r.duration);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.appBackground),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recordings',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    // Sincroniza a biblioteca com os arquivos de audio que
                    // ja estavam salvos na pasta escolhida — gravacoes
                    // copiadas para o aparelho por fora do app entram
                    // na lista sem precisao de regravar.
                    _SyncButton(
                      busy: _syncing,
                      onPressed: _sync,
                    ),
                    if (_recordings.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon(
                              AppIcons.clock,
                              size: 13,
                              color: AppColors.accentBright,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatDuration(totalDuration),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_recordings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _SearchField(
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentBright,
                          strokeWidth: 2.4,
                        ),
                      )
                    : items.isEmpty
                        ? _EmptyState(hasQuery: _query.isNotEmpty)
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            color: AppColors.accentBright,
                            backgroundColor: AppColors.surface,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) => _RecordingCard(
                                recording: items[i],
                                onOpen: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          EditingScreen(recording: items[i]),
                                    ),
                                  );
                                  await _settings?.reload();
                                },
                              ),
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const AppIcon(
            AppIcons.search,
            size: 16,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              cursorColor: AppColors.accentBright,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Search recordings…',
                hintStyle: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.recording, required this.onOpen});

  final Recording recording;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.waveDeep.withValues(alpha: 0.85),
                    AppColors.waveBright.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: const Center(
                child: AppIcon(
                  AppIcons.mic,
                  size: 17,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recording.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatDuration(recording.duration),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    recording.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.38,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Data, hora e tamanho do arquivo — as tres informacoes
                  // que a biblioteca precisa mostrar para a gravacao ser
                  // reconhecida sem abrir o editor.
                  _MetaRow(recording: recording),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botao que sincroniza a biblioteca com os arquivos ja salvos.
class _SyncButton extends StatelessWidget {
  const _SyncButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        onPressed: busy ? null : onPressed,
        tooltip: 'Sincronizar com os arquivos salvos',
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentBright,
                ),
              )
            : const AppIcon(
                AppIcons.refresh,
                size: 18,
                color: AppColors.textSecondary,
              ),
      ),
    );
  }
}

/// Linha de metadados do card: data, hora, tamanho e dono.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      recording.formattedDate,
      recording.formattedTime,
      recording.formattedSize,
    ];
    if (recording.ownerName.isNotEmpty) {
      parts.add(recording.ownerName);
    }

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final part in parts)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.circle,
                size: 3,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 5),
              Text(
                part,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.waveDeep.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: AppIcon(
                  hasQuery ? AppIcons.search : AppIcons.mic,
                  size: 30,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery ? 'No matches found' : 'No recordings yet',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term.'
                  : 'Record your first take and it will show up here with '
                      'its transcription.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
