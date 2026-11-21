import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Onde os arquivos de audio sao guardados.
///
/// O Android guarda cada app num diretorio privado
/// (`/data/user/0/<pacote>/app_flutter`) que nenhum gerenciador de
/// arquivos mostra. Por isso o destino e explicito: o usuario escolhe
/// uma pasta visivel e o app grava la.
enum StorageLocation {
  /// Pasta publica do app no armazenamento externo:
  /// `/storage/emulated/0/Android/data/<pacote>/files`.
  ///
  /// Nao pede permissao e sobrevive a limpeza de cache, mas em algumas
  /// versoes do Android o gerenciador de arquivos esconde a pasta
  /// `Android/data`.
  appExternal,

  /// Pasta publica `Download` do aparelho.
  ///
  /// E o lugar onde o usuario espera encontrar os arquivos — aparece
  /// em qualquer gerenciador de arquivos. No Android 10+ a gravacao
  /// passa pelo MediaStore, que dispensa permissao de armazenamento.
  downloads,

  /// Diretorio privado do app.
  ///
  /// Guarda o audio fora da vista do usuario: uteis quando o app e
  /// apenas um gravador temporario e os arquivos nao devem ser
  /// explorados por outros apps.
  private,
}

/// Resolucao de pastas e criacao de arquivos de audio.
class StorageService {
  StorageService();

  /// Pacote do aplicativo — usado para montar o caminho da pasta externa.
  static const String packageName = 'com.scrott.voice';

  /// Nome da pasta criada dentro do destino escolhido.
  static const String folderName = 'Scroatt';

  /// Resolve o diretorio absoluto de [location].
  ///
  /// Retorna `null` quando o destino nao existe no aparelho (por
  /// exemplo, `Download` ausente emalguns aparelhos) — nesse caso o
  /// chamador cai no destino privado.
  Future<Directory?> resolveDirectory(StorageLocation location) async {
    try {
      switch (location) {
        case StorageLocation.appExternal:
          final base = await getExternalStorageDirectory();
          if (base == null) return null;
          return Directory('${base.path}/$folderName');

        case StorageLocation.downloads:
          final base = await getDownloadsDirectory();
          if (base == null) return null;
          return Directory('${base.path}/$folderName');

        case StorageLocation.private:
          final base = await getApplicationDocumentsDirectory();
          return Directory('${base.path}/$folderName');
      }
    } catch (_) {
      return null;
    }
  }

  /// Resolve o destino final, garantindo que a pasta exista.
  ///
  /// Se [location] nao estiver disponivel, cai para o diretorio privado
  /// — gravar em um destino invalido perderia a gravacao inteira.
  Future<Directory> resolveOrFallback(StorageLocation location) async {
    final dir = await resolveDirectory(location);
    if (dir != null) {
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } catch (_) {
        // Sem permissao no destino escolhido: usa o privado.
      }
    }

    final fallback = await getApplicationDocumentsDirectory();
    final safe = Directory('${fallback.path}/$folderName');
    if (!await safe.exists()) {
      await safe.create(recursive: true);
    }
    return safe;
  }

  /// Monta um caminho de arquivo unico dentro de [directory].
  ///
  /// O nome carrega a informacao pedida no item 7 da v3: o nome
  /// escolhido no app, a data e a hora. Exemplo:
  /// `Samuel_2026-11-21_05-25-33.m4a`.
  String buildFileName({
    required String ownerName,
    required DateTime timestamp,
    String extension = 'm4a',
  }) {
    final safeOwner = _sanitize(ownerName.isEmpty ? 'Scroatt' : ownerName);
    final d = timestamp;
    final date =
        '${d.year}-${_two(d.month)}-${_two(d.day)}';
    final time = '${_two(d.hour)}-${_two(d.minute)}-${_two(d.second)}';
    return '${safeOwner}_${date}_$time.$extension';
  }

  /// Caminho completo do arquivo, garantindo que a pasta exista.
  Future<String> buildFilePath({
    required StorageLocation location,
    required String ownerName,
    required DateTime timestamp,
    String extension = 'm4a',
  }) async {
    final dir = await resolveOrFallback(location);
    final name = buildFileName(
      ownerName: ownerName,
      timestamp: timestamp,
      extension: extension,
    );
    return '${dir.path}/$name';
  }

  /// Pasta publica de Download — usada pela acao "abrir no gerenciador".
  Future<Directory?> downloadsDirectory() async {
    try {
      return await getDownloadsDirectory();
    } catch (_) {
      return null;
    }
  }

  /// Remove um arquivo, ignorando o caso de ele ja nao existir.
  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Nada a fazer: o arquivo pode ja ter sumido.
    }
  }

  /// Tamanho em bytes de um arquivo, ou 0 quando ele nao existe.
  Future<int> fileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) return await file.length();
    } catch (_) {
      // Arquivo inacessivel: treat como vazio.
    }
    return 0;
  }

  /// Remove os characteres que nao podem entrar em um nome de arquivo.
  String _sanitize(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'Scroatt' : cleaned;
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
