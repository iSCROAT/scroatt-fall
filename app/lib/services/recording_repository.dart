import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recording.dart';

/// Persistencia das gravacoes e do rascunho de transcricao.
///
/// Usamos `SharedPreferences` para o indice (JSON) e o sistema de arquivos
/// do app para os arquivos de audio. E a abordagem mais simples e confiavel
/// para um MVP, sem banco de dados.
class RecordingRepository {
  static const String _indexKey = 'scroatt.recordings.index';
  static const String _draftKey = 'scroatt.transcription.draft';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  // -------------------------------------------------------------------
  // Indice de gravacoes
  // -------------------------------------------------------------------

  /// Carrega todas as gravacoes do indice.
  Future<List<Recording>> loadAll() async {
    final prefs = await _instance;
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return <Recording>[];
    return Recording.decodeList(raw);
  }

  /// Salva uma gravacao, substituindo a de mesmo id.
  Future<void> save(Recording recording) async {
    final prefs = await _instance;
    final all = await loadAll();

    final index = all.indexWhere((r) => r.id == recording.id);
    if (index >= 0) {
      all[index] = recording;
    } else {
      all.insert(0, recording);
    }

    await prefs.setString(_indexKey, Recording.encodeList(all));
  }

  /// Salva varias gravacoes de uma vez.
  ///
  /// Usado pela sincronizacao com os arquivos ja existentes no disco: uma
  /// unica escrita evita varias chamadas ao armazenamento.
  Future<void> saveAll(List<Recording> recordings) async {
    if (recordings.isEmpty) return;
    final prefs = await _instance;
    final all = await loadAll();
    for (final recording in recordings) {
      final index = all.indexWhere((r) => r.id == recording.id);
      if (index >= 0) {
        all[index] = recording;
      } else {
        all.insert(0, recording);
      }
    }
    await prefs.setString(_indexKey, Recording.encodeList(all));
  }

  /// Remove uma gravacao do indice.
  Future<void> delete(String id) async {
    final prefs = await _instance;
    final all = await loadAll()..removeWhere((r) => r.id == id);
    await prefs.setString(_indexKey, Recording.encodeList(all));
  }

  /// Renomeia uma gravacao.
  Future<void> rename(String id, String title) async {
    final prefs = await _instance;
    final all = await loadAll();
    final index = all.indexWhere((r) => r.id == id);
    if (index < 0) return;
    all[index] = all[index].copyWith(title: title);
    await prefs.setString(_indexKey, Recording.encodeList(all));
  }

  // -------------------------------------------------------------------
  // Rascunho de transcricao
  // -------------------------------------------------------------------

  /// Le o rascunho da transcricao.
  Future<String?> loadDraftTranscript() async {
    final prefs = await _instance;
    return prefs.getString(_draftKey);
  }

  /// Salva o rascunho da transcricao.
  Future<void> saveDraftTranscript(String text) async {
    final prefs = await _instance;
    if (text.trim().isEmpty) {
      await prefs.remove(_draftKey);
    } else {
      await prefs.setString(_draftKey, text);
    }
  }

  /// Limpa o rascunho.
  Future<void> clearDraftTranscript() async {
    final prefs = await _instance;
    await prefs.remove(_draftKey);
  }

  // -------------------------------------------------------------------
  // Estatisticas da biblioteca
  // -------------------------------------------------------------------

  /// Numeros agregados da biblioteca.
  Future<LibraryStats> stats() async {
    final all = await loadAll();
    final totalSeconds = all.fold<double>(0, (sum, r) => sum + r.duration);
    return LibraryStats(
      count: all.length,
      totalDuration: totalSeconds,
    );
  }
}

/// Numeros agregados da biblioteca.
class LibraryStats {
  const LibraryStats({required this.count, required this.totalDuration});

  final int count;
  final double totalDuration;

  static const empty = LibraryStats(count: 0, totalDuration: 0);
}

/// Helper para ler/escrever JSON cru — util para depuracao.
String prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
