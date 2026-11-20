import 'package:flutter/foundation.dart';

import '../models/recording.dart';
import 'recording_repository.dart';
import 'user_preferences.dart';

/// Estado compartilhado do aplicativo.
///
/// Mantém em um único lugar o que é comum a várias telas — as gravações
/// salvas, o rascunho da transcrição, o nome do usuário e a preferência de
/// animação — e avisa as telas interessadas quando algo muda.
class AppSettings extends ChangeNotifier {
  AppSettings({RecordingRepository? repository, UserPreferences? preferences})
      : _repository = repository ?? RecordingRepository(),
        _preferences = preferences ?? UserPreferences();

  final RecordingRepository _repository;
  final UserPreferences _preferences;

  List<Recording> _recordings = <Recording>[];
  String _draftTranscript = '';

  /// Gravações salvas, da mais recente para a mais antiga.
  List<Recording> get recordings => List.unmodifiable(_recordings);

  /// Rascunho da transcrição em andamento.
  String get draftTranscript => _draftTranscript;

  /// Preferências do usuário (nome e animações).
  UserPreferences get preferences => _preferences;

  /// Nome de exibição escolhido pelo usuário.
  String get displayName => _preferences.displayName;

  /// Nome pronto para exibir, com o padrão quando nada foi escolhido.
  String get displayNameOrDefault => _preferences.displayNameOrDefault;

  /// Indica se as animações pesadas estão ativas.
  bool get animationsEnabled => _preferences.animationsEnabled;

  /// Carrega as gravações, o rascunho e as preferências.
  Future<void> load() async {
    await _preferences.load();
    _recordings = await _repository.loadAll();
    _draftTranscript = await _repository.loadDraftTranscript() ?? '';
    notifyListeners();
  }

  /// Recarrega as gravações do disco.
  ///
  /// Útil depois de uma edição que pode ter alterado o índice — por
  /// exemplo, quando o usuário renomeia ou apaga uma gravação.
  Future<void> reload() async {
    _recordings = await _repository.loadAll();
    notifyListeners();
  }

  /// Salva uma gravação e recarrega a lista.
  Future<void> saveRecording(Recording recording) async {
    await _repository.save(recording);
    _recordings = await _repository.loadAll();
    notifyListeners();
  }

  /// Remove uma gravação e recarrega a lista.
  Future<void> deleteRecording(String id) async {
    await _repository.delete(id);
    _recordings = await _repository.loadAll();
    notifyListeners();
  }

  /// Renomeia uma gravação e recarrega a lista.
  Future<void> renameRecording(String id, String title) async {
    await _repository.rename(id, title);
    _recordings = await _repository.loadAll();
    notifyListeners();
  }

  /// Atualiza o rascunho da transcrição.
  Future<void> setDraftTranscript(String text) async {
    if (_draftTranscript == text) return;
    _draftTranscript = text;
    await _repository.saveDraftTranscript(text);
    notifyListeners();
  }

  /// Define o nome de exibição do usuário.
  Future<void> setDisplayName(String name) async {
    await _preferences.setDisplayName(name);
    notifyListeners();
  }

  /// Liga ou desliga as animações pesadas.
  Future<void> setAnimationsEnabled(bool enabled) async {
    await _preferences.setAnimationsEnabled(enabled);
    notifyListeners();
  }

  /// Filtra as gravações por um texto livre.
  ///
  /// Procura no título e no conteúdo da transcrição.
  List<Recording> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return recordings;
    return _recordings
        .where(
          (r) =>
              r.displayTitle.toLowerCase().contains(q) ||
              r.transcript.toLowerCase().contains(q),
        )
        .toList();
  }
}
