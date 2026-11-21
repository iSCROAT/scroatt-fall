import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrott_voice/models/recording.dart';
import 'package:scrott_voice/services/storage_service.dart';
import 'package:scrott_voice/services/user_preferences.dart';

Recording buildRecording({
  String id = '1',
  String ownerName = 'Samuel',
  DateTime? createdAt,
  double duration = 16,
  int fileSizeBytes = 1492992,
  String title,
  String transcript = 'Hello Samuel, how are you today?',
}) {
  return Recording(
    id: id,
    filePath: '/tmp/Samuel_2026-11-21_05-25-33.m4a',
    createdAt: createdAt ?? DateTime(2026, 11, 21, 5, 25, 33),
    duration: duration,
    transcript: transcript,
    title: title,
    ownerName: ownerName,
    fileSizeBytes: fileSizeBytes,
    folder: '/storage/emulated/0/Download/Scroatt',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('UserPreferences — v3', () {
    test('o idioma padrao e o portugues do Brasil', () async {
      final prefs = UserPreferences();
      await prefs.load();

      expect(prefs.transcriptionLanguage, 'pt-BR');
      expect(UserPreferences.defaultLanguage, 'pt-BR');
    });

    test('a troca de idioma e persistida', () async {
      final prefs = UserPreferences();
      await prefs.load();

      await prefs.setTranscriptionLanguage('en-US');

      final reloaded = UserPreferences();
      await reloaded.load();
      expect(reloaded.transcriptionLanguage, 'en-US');
    });

    test('o destino padrao e a pasta Download', () async {
      final prefs = UserPreferences();
      await prefs.load();

      expect(prefs.storageLocation, StorageLocation.downloads);
    });

    test('a troca de destino e persistida', () async {
      final prefs = UserPreferences();
      await prefs.load();

      await prefs.setStorageLocation(StorageLocation.appExternal);

      final reloaded = UserPreferences();
      await reloaded.load();
      expect(reloaded.storageLocation, StorageLocation.appExternal);
    });

    test('a pasta personalizada e sanitizada', () async {
      final prefs = UserPreferences();
      await prefs.load();

      await prefs.setCustomFolder('minhas/ouvintes');

      expect(prefs.customFolder, 'minhas_ouvintes');
    });

    test('os filtros de captura comem ligados', () async {
      final prefs = UserPreferences();
      await prefs.load();

      expect(prefs.noiseSuppress, isTrue);
      expect(prefs.autoGain, isTrue);
      expect(prefs.echoCancel, isTrue);
    });

    test('a qualidade do audio e persistida', () async {
      final prefs = UserPreferences();
      await prefs.load();

      await prefs.setAudioQuality(256);

      final reloaded = UserPreferences();
      await reloaded.load();
      expect(reloaded.audioQuality, 256);
    });
  });

  group('Recording — v3', () {
    test('formata a data no padrao brasileiro', () {
      expect(buildRecording().formattedDate, '21/11/2026');
    });

    test('formata a hora em 24 horas', () {
      expect(buildRecording().formattedTime, '05:25');
    });

    test('formata a duracao', () {
      expect(buildRecording(duration: 16).formattedDuration, '00:16');
      expect(buildRecording(duration: 83).formattedDuration, '01:23');
      expect(buildRecording(duration: 3723).formattedDuration, '1:02:03');
    });

    test('formata o tamanho do arquivo', () {
      expect(buildRecording(fileSizeBytes: 512).formattedSize, '512 B');
      expect(buildRecording(fileSizeBytes: 1492992).formattedSize, '1,4 MB');
      expect(buildRecording(fileSizeBytes: 45 * 1024 * 1024).formattedSize, '45,0 MB');
    });

    test('guarda o nome do dono e a pasta', () {
      final r = buildRecording();
      expect(r.ownerName, 'Samuel');
      expect(r.folder, '/storage/emulated/0/Download/Scrott');
    });

    test('sobrevive a serializacao em JSON', () {
      final r = buildRecording();
      final back = Recording.decodeList(Recording.encodeList([r])).first;

      expect(back.ownerName, 'Samuel');
      expect(back.fileSizeBytes, 1492992);
      expect(back.folder, r.folder);
      expect(back.formattedDate, '21/11/2026');
    });
  });

  group('StorageService — v3', () {
    test('o nome do arquivo carrega o nome, a data e a hora', () {
      final service = StorageService();
      final name = service.buildFileName(
        ownerName: 'Samuel',
        timestamp: DateTime(2026, 11, 21, 5, 25, 33),
      );

      expect(name, 'Samuel_2026-11-21_05-25-33.m4a');
    });

    test('o nome do arquivo e sanitizado', () {
      final service = StorageService();
      final name = service.buildFileName(
        ownerName: 'Maria / Silva',
        timestamp: DateTime(2026, 11, 21, 5, 25, 33),
      );

      expect(name, 'Maria__Silva_2026-11-21_05-25-33.m4a');
      expect(name.contains('/'), isFalse);
    });

    test('sem nome, usa o nome padrao do app', () {
      final service = StorageService();
      final name = service.buildFileName(
        ownerName: '',
        timestamp: DateTime(2026, 11, 21, 5, 25, 33),
      );

      expect(name.startsWith('Scroatt_'), isTrue);
    });
  });
}
