import 'package:flutter/foundation.dart';

import '../models/recording.dart';
import 'recording_repository.dart';
import 'storage_service.dart';
import 'user_preferences.dart';

/// Estado compartilhado do aplicativo.
///
/// Mantem em um unico lugar o que e comum a varias telas — as gravacoes
/// salvas, o rascunho da transcricao, o nome do usuario, o idioma e as
/// preferencias de audio e animacao — e avisa as telas interessadas
/// quando algo muda.
class AppSettings extends ChangeNotifier {
  AppSettings({
    RecordingRepository? repository,
    UserPreferences? preferences,
    StorageService? storage,
  })  : _repository = repository ?? RecordingRepository(),
        _preferences = preferences ?? UserPreferences(),
        _storage = storage ?? StorageService();

  final RecordingRepository _repository;
  final UserPreferences _preferences;
  final StorageService _storage;

  List<Recording> _recordings = <Recording>[];
  String _draftTranscript = '';

  /// Gravacoes salvas, da mais recente para a mais antiga.
  List<Recording> get recordings => List.unmodifiable(_recordings);

  /// Rascunho da transcricao em andamento.
  String get draftTranscript => _draftTranscript;

  /// Preferencias do usuario.
  UserPreferences get preferences => _preferences;

  /// Servico de armazenamento — resolve pastas e cria arquivos.
  StorageService get storage => _storage;

  /// Nome de exibicao escolhido pelo usuario.
  String get displayName => _preferences.displayName;

  /// Nome pronto para exibir, com o padrao quando nada foi escolhido.
  String get displayNameOrDefault => _preferences.displayNameOrDefault;

  /// Indica se as animacoes pesadas estao ativas.
  bool get animationsEnabled => _preferences.animationsEnabled;

  /// Idioma de transcricao escolhido.
  String get transcriptionLanguage => _preferences.transcriptionLanguage;

  /// Destino dos arquivos de audio.
  StorageLocation get storageLocation => _preferences.storageLocation;

  /// Pasta personalizada escolhida pelo usuario (vazia quando nao ha).
  String get customFolder => _preferences.customFolder;

  /// Qualidade do audio em kbps.
  int get audioQuality => _preferences.audioQuality;

  /// Mantem as gravacoes no aparelho apos salvar.
  bool get keepOnDevice => _preferences.keepOnDevice;

  /// Supressao de ruido na captura.
  bool get noiseSuppress => _preferences.noiseSuppress;

  /// Ganho automatico na captura.
  bool get autoGain => _preferences.autoGain;

  /// Cancelamento de eco na captura.
  bool get echoCancel => _preferences.echoCancel;

  /// Carrega as gravacoes, o rascunho e as preferencias.
  Future<void> load() async {
    await _preferences.load();
    _recordings = await _repository.loadAll();
    _draftTranscript = await _repository.loadDraftTranscript() ?? '';
    notifyListeners();
  }

  /// Recarrega as gravacoes do disco.
  Future<void> reload() async {
    _recordings = await _repository.loadAll();
    notifyListeners();
  }

  /// Salva uma gravacao e recarrega a lista.
  Future<void> saveRecording(Recording recording) async {
    await _repository.save(recording);
    _recordings = await _repository.loadAll();
    notifyListeners();
  }

  /// Remove uma gravacao e recarrega a lista.
  Future<void> deleteRecording(String id) async {
    Recording? target;
    for (final r in _recordings) {
      if (r.id == id) {
        target = r;
        break;
      }
    }
    await _repository.delete(id);
    // O arquivo de audio tambem sai do disco — a gravacao e apagada de
    // vez, nao apenas escondida da lista.
    if (target != null) {
      await _storage.deleteFile(target.filePath);
    }
    _recordings = await _repository.loadAll();
    notifyListeners();
  }

  /// Renomeia uma gravacao e recarrega a lista.
  Future<void> renameRecording(String id, String title) async {
    await _repository.rename(id, title);
    _recordings = await _repository.loadAll();
    notifyListeners();
  }

  /// Atualiza o rascunho da transcricao.
  Future<void> setDraftTranscript(String text) async {
    if (_draftTranscript == text) return;
    _draftTranscript = text;
    await _repository.saveDraftTranscript(text);
    notifyListeners();
  }

  /// Define o nome de exibicao do usuario.
  Future<void> setDisplayName(String name) async {
    await _preferences.setDisplayName(name);
    notifyListeners();
  }

  /// Liga ou desliga as animacoes pesadas.
  Future<void> setAnimationsEnabled(bool enabled) async {
    await _preferences.setAnimationsEnabled(enabled);
    notifyListeners();
  }

  /// Define o idioma de transcricao.
  Future<void> setTranscriptionLanguage(String code) async {
    await _preferences.setTranscriptionLanguage(code);
    notifyListeners();
  }

  /// Define o destino dos arquivos de audio.
  Future<void> setStorageLocation(StorageLocation location) async {
    await _preferences.setStorageLocation(location);
    notifyListeners();
  }

  /// Define a pasta personalizada dentro do destino escolhido.
  Future<void> setCustomFolder(String folder) async {
    await _preferences.setCustomFolder(folder);
    notifyListeners();
  }

  /// Define a qualidade do audio.
  Future<void> setAudioQuality(int kbps) async {
    await _preferences.setAudioQuality(kbps);
    notifyListeners();
  }

  /// Define se as gravacoes permanecem no aparelho.
  Future<void> setKeepOnDevice(bool value) async {
    await _preferences.setKeepOnDevice(value);
    notifyListeners();
  }

  /// Define a supressao de ruido na captura.
  Future<void> setNoiseSuppress(bool value) async {
    await _preferences.setNoiseSuppress(value);
    notifyListeners();
  }

  /// Define o ganho automatico na captura.
  Future<void> setAutoGain(bool value) async {
    await _preferences.setAutoGain(value);
    notifyListeners();
  }

  /// Define o cancelamento de eco na captura.
  Future<void> setEchoCancel(bool value) async {
    await _preferences.setEchoCancel(value);
    notifyListeners();
  }

  /// Filtra as gravacoes por um texto livre.
  ///
  /// Procura no titulo, no nome do dono e no conteudo da transcricao.
  List<Recording> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return recordings;
    return _recordings
        .where(
          (r) =>
              r.displayTitle.toLowerCase().contains(q) ||
              r.ownerName.toLowerCase().contains(q) ||
              r.transcript.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Sincroniza a biblioteca com os arquivos que ja estavam no destino.
  ///
  /// Varre a pasta configurada em busca de arquivos de audio que nao
  /// estão no indice — por exemplo, gravacoes copiadas para o aparelho
  /// pelo cabo USB ou por outro app — e as registra na biblioteca.
  ///
  /// Devolve quantas gravacoes foram adicionadas.
  Future<int> syncWithExistingFiles() async {
    final dir = await _storage.resolveOrFallback(storageLocation);
    final known = <String>{
      for (final r in _recordings) r.filePath,
    };

    final added = <Recording>[];
    try {
      if (!await dir.exists()) return 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final path = entity.path;
        if (known.contains(path)) continue;
        if (!_isAudioFile(path)) continue;

        final stat = await entity.stat();
        added.add(
          Recording(
            id: stat.modified.millisecondsSinceEpoch.toString(),
            filePath: path,
            createdAt: stat.modified,
            duration: 0,
            transcript: '',
            ownerName: _ownerFromFileName(entity.uri.pathSegments.last),
            fileSizeBytes: stat.size,
            folder: dir.path,
          ),
        );
      }
    } catch (_) {
      return 0;
    }

    if (added.isEmpty) return 0;

    // As mais recentes primeiro, como no resto da biblioteca.
    added.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final r in added) {
      await _repository.save(r);
    }
    _recordings = await _repository.loadAll();
    notifyListeners();
    return added.length;
  }

  /// Extrai o nome do dono do nome do arquivo.
  ///
  /// Os arquivos sao gravados como `Nome_AAAA-MM-DD_HH-MM-SS.m4a`; quando o
  /// nome nao segue o padrao, devolve vazio.
  String _ownerFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    final parts = stem.split('_');
    if (parts.length < 3) return '';
    return parts.take(parts.length - 2).join('_');
  }

  /// Indica se o arquivo tem extensao de audio suportada.
  bool _isAudioFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.m4a') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.flac');
  }
}
