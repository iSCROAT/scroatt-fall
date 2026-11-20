import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recording.dart';

/// Persistência das gravações e do rascunho de transcrição.
///
/// Usamos `SharedPreferences` para o índice (JSON) e o sistema de arquivos
/// do app para os arquivos `.m4a`. É a abordagem mais simples e confiável
/// para um MVP, sem banco de dados.
class RecordingRepository {
  static const String _indexKey = 'scroatt.recordings.index';
  static const String _draftKey = 'scroatt.transcription.draft';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  // -------------------------------------------------------------------
  // Índice de gravações
  // -------------------------------------------------------------------

  Future<List<Recording>> loadAll() async {
    final prefs = await _instance;
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return <Recording>[];
    return Recording.decodeList(raw);
  }

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

  Future<void> delete(String id) async {
    final prefs = await _instance;
    final all = await loadAll()..removeWhere((r) => r.id == id);
    await prefs.setString(_indexKey, Recording.encodeList(all));
  }

  Future<void> rename(String id, String title) async {
    final prefs = await _instance;
    final all = await loadAll();
    final index = all.indexWhere((r) => r.id == id);
    if (index < 0) return;
    all[index] = all[index].copyWith(title: title);
    await prefs.setString(_indexKey, Recording.encodeList(all));
  }

  // -------------------------------------------------------------------
  // Rascunho da transcrição
  // -------------------------------------------------------------------

  Future<String?> loadDraftTranscript() async {
    final prefs = await _instance;
    return prefs.getString(_draftKey);
  }

  Future<void> saveDraftTranscript(String text) async {
    final prefs = await _instance;
    if (text.trim().isEmpty) {
      await prefs.remove(_draftKey);
    } else {
      await prefs.setString(_draftKey, text);
    }
  }

  Future<void> clearDraftTranscript() async {
    final prefs = await _instance;
    await prefs.remove(_draftKey);
  }

  // -------------------------------------------------------------------
  // Estatísticas da biblioteca
  // -------------------------------------------------------------------

  Future<LibraryStats> stats() async {
    final all = await loadAll();
    final totalSeconds = all.fold<double>(0, (sum, r) => sum + r.duration);
    return LibraryStats(
      count: all.length,
      totalDuration: totalSeconds,
    );
  }
}

/// Números agregados da biblioteca.
class LibraryStats {
  const LibraryStats({required this.count, required this.totalDuration});

  final int count;
  final double totalDuration;

  static const empty = LibraryStats(count: 0, totalDuration: 0);
}

/// Helper para ler/escrever JSON cru — útil para depuração.
String prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
