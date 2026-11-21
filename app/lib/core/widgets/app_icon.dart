import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

/// Catálogo central de ícones do aplicativo.
///
/// Os ícones vêm do set **Feather Icons** (MIT License, © Cole Bemis),
/// convertido para assets SVG e empacotado em `assets/icons/`.
///
/// A escolha do Feather se dá porque o protótipo de referência usa traço
/// fino e uniforme (2px, cantos arredondados) — exatamente o DNA do Feather.
/// Cada ícone aqui foi selecionado pelo seu encaixe semântico no fluxo do
/// gravador de voz, e não porsimilaridade visual genérica.
class AppIcons {
  AppIcons._();

  // ------------------------------------------------------------------
  // Gravação
  // ------------------------------------------------------------------
  /// Microfone — ação principal de gravar.
  static const String mic = 'assets/icons/mic.svg';

  /// Microfone cortado — microfone desativado / erro de permissão.
  static const String micOff = 'assets/icons/mic-off.svg';

  /// Parar — interrompe a gravação em andamento.
  static const String square = 'assets/icons/square.svg';

  // ------------------------------------------------------------------
  // Navegação
  // ------------------------------------------------------------------
  static const String chevronLeft = 'assets/icons/chevron-left.svg';
  static const String chevronRight = 'assets/icons/chevron-right.svg';
  static const String arrowLeft = 'assets/icons/arrow-left.svg';

  /// Menu "..." — ações secundárias da tela de edição.
  static const String more = 'assets/icons/more-horizontal.svg';

  /// Configurações.
  static const String settings = 'assets/icons/settings.svg';

  // ------------------------------------------------------------------
  // Edição / texto
  // ------------------------------------------------------------------
  /// "Tt" — ferramenta de texto e refinamento da transcrição.
  static const String text = 'assets/icons/type.svg';

  /// "X✂" — corte / trim da gravação.
  static const String trim = 'assets/icons/sliders.svg';

  /// Volume / enhancement.
  static const String volume = 'assets/icons/volume-2.svg';

  /// Enhancer de voz.
  static const String enhance = 'assets/icons/zap.svg';

  /// Editar texto.
  static const String edit = 'assets/icons/edit-3.svg';

  // ------------------------------------------------------------------
  // Mídia / biblioteca
  // ------------------------------------------------------------------
  static const String play = 'assets/icons/play.svg';
  static const String pause = 'assets/icons/pause.svg';
  static const String folderPlus = 'assets/icons/folder-plus.svg';
  static const String fileText = 'assets/icons/file-text.svg';
  static const String trash = 'assets/icons/trash-2.svg';
  static const String share = 'assets/icons/share-2.svg';
  static const String download = 'assets/icons/download.svg';

  // ------------------------------------------------------------------
  // Utilidades
  // ------------------------------------------------------------------
  static const String clock = 'assets/icons/clock.svg';
  static const String check = 'assets/icons/check.svg';
  static const String checkCircle = 'assets/icons/check-circle.svg';
  static const String close = 'assets/icons/x.svg';
  static const String search = 'assets/icons/search.svg';
  static const String plus = 'assets/icons/plus.svg';
  static const String globe = 'assets/icons/globe.svg';
  static const String sun = 'assets/icons/sun.svg';
  static const String headphones = 'assets/icons/headphones.svg';
  static const String radio = 'assets/icons/radio.svg';
  static const String activity = 'assets/icons/activity.svg';
  static const String returnKey = 'assets/icons/corner-down-left.svg';
  static const String rotate = 'assets/icons/rotate-ccw.svg';

  /// Marcador de momento dentro da gravação.
  static const String bookmark = 'assets/icons/bookmark.svg';

  // ------------------------------------------------------------------
  // Biblioteca e armazenamento
  // ------------------------------------------------------------------

  /// Sincronizar — recarrega a biblioteca com os arquivos ja salvos.
  static const String refresh = 'assets/icons/refresh-cw.svg';

  /// Pasta — destino dos arquivos de audio.
  static const String folder = 'assets/icons/folder.svg';

  /// Disco — armazenamento do aparelho.
  static const String hardDrive = 'assets/icons/hard-drive.svg';

  /// Salvar — confirmar gravacao.
  static const String save = 'assets/icons/save.svg';
}

/// Renderiza um ícone SVG do catálogo [AppIcons].
///
/// `size` é a caixa quadrada do ícone. `color` aplica `currentColor`
/// sobre o traço original do Feather.
///
/// `strokeWidth` é opcional: quando informado, o SVG é carregado como
/// texto e o atributo `stroke-width` é substituído em tempo de
/// execução — o `flutter_svg` 2.x não expõe uma forma nativa de
/// sobrescrever a espessura do traço.
class AppIcon extends StatefulWidget {
  const AppIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth,
  });

  final String asset;
  final double size;
  final Color? color;

  /// Sobrescreve a espessura do traço (padrão do Feather: 2).
  final double? strokeWidth;

  @override
  State<AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<AppIcon> {
  String? _svgText;

  @override
  void initState() {
    super.initState();
    if (widget.strokeWidth != null) _loadWithStrokeWidth();
  }

  @override
  void didUpdateWidget(covariant AppIcon old) {
    super.didUpdateWidget(old);
    if (widget.strokeWidth != null && _svgText == null) {
      _loadWithStrokeWidth();
    }
  }

  Future<void> _loadWithStrokeWidth() async {
    final raw = await rootBundle.loadString(widget.asset);
    final replaced = raw.replaceAll(
      RegExp(r'stroke-width="[^"]*"'),
      'stroke-width="${widget.strokeWidth}"',
    );
    if (!mounted) return;
    setState(() => _svgText = replaced);
  }

  @override
  Widget build(BuildContext context) {
    final colorFilter = widget.color == null
        ? null
        : ColorFilter.mode(widget.color!, BlendMode.srcIn);

    final picture = _svgText != null
        ? SvgPicture.string(
            _svgText!,
            width: widget.size,
            height: widget.size,
            colorFilter: colorFilter,
          )
        : SvgPicture.asset(
            widget.asset,
            width: widget.size,
            height: widget.size,
            colorFilter: colorFilter,
          );

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: picture,
    );
  }
}
