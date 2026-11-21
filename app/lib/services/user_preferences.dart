import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';

/// Preferencias do usuario que atravessam as telas.
///
/// Centraliza ajustes que nao pertencem a uma gravacao especifica — como o
/// nome de exibicao, a preferencia de animacao, o idioma de transcricao e
/// o destino dos arquivos de audio — para que qualquer tela possa le-los
/// sem conhecer a origem.
class UserPreferences {
  UserPreferences({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;

  static const String _nameKey = 'user_display_name';
  static const String _animationsKey = 'user_animations_enabled';
  static const String _languageKey = 'user_transcription_language';
  static const String _storageKey = 'user_storage_location';
  static const String _customFolderKey = 'user_custom_folder';
  static const String _audioQualityKey = 'user_audio_quality';
  static const String _keepOnDeviceKey = 'user_keep_on_device';
  static const String _noiseSuppressKey = 'user_noise_suppress';
  static const String _autoGainKey = 'user_auto_gain';
  static const String _echoCancelKey = 'user_echo_cancel';

  /// Valor exibido quando o usuario ainda nao escolheu um nome.
  static const String defaultName = 'there';

  /// Idioma padrao do aplicativo.
  ///
  /// O portugues (Brasil) e o padrao porque o app foi escrito para esse
  /// publico; o usuario pode trocar nas configuracoes.
  static const String defaultLanguage = 'pt-BR';

  /// Carrega as preferencias persistidas.
  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
  }

  /// Nome de exibicao escolhido pelo usuario.
  ///
  /// Devolve uma string vazia quando o nome ainda nao foi definido, para que
  /// a interface possa cair no texto padrao.
  String get displayName => _preferences?.getString(_nameKey) ?? '';

  /// Define o nome de exibicao.
  ///
  /// Nomes em branco sao tratados como "nao definido" e removidos da
  /// persistencia, evitando gravar espacos que apareceriam na transcricao.
  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await _preferences?.remove(_nameKey);
      return;
    }
    await _preferences?.setString(_nameKey, trimmed);
  }

  /// Nome pronto para exibir: o que o usuario escolheu ou o padrao.
  String get displayNameOrDefault {
    final name = displayName;
    return name.isEmpty ? defaultName : name;
  }

  /// Indica se as animacoes pesadas (malha da waveform) estao ativas.
  ///
  /// Vem desligado por padrao: a malha redesenha milhares de segmentos a
  /// cada quadro e pesa em aparelhos modestos. O usuario pode liga-la nas
  /// configuracoes.
  bool get animationsEnabled => _preferences?.getBool(_animationsKey) ?? false;

  /// Liga ou desliga as animacoes pesadas.
  Future<void> setAnimationsEnabled(bool enabled) async {
    await _preferences?.setBool(_animationsKey, enabled);
  }

  /// Idioma de transcricao escolhido.
  String get transcriptionLanguage =>
      _preferences?.getString(_languageKey) ?? defaultLanguage;

  /// Define o idioma de transcricao.
  Future<void> setTranscriptionLanguage(String code) async {
    await _preferences?.setString(_languageKey, code);
  }

  /// Destino dos arquivos de audio.
  StorageLocation get storageLocation {
    final raw = _preferences?.getString(_storageKey);
    if (raw == null) return StorageLocation.downloads;
    final index = StorageLocation.values.indexWhere((e) => e.name == raw);
    return index < 0 ? StorageLocation.downloads : StorageLocation.values[index];
  }

  /// Define o destino dos arquivos de audio.
  Future<void> setStorageLocation(StorageLocation location) async {
    await _preferences?.setString(_storageKey, location.name);
  }

  /// Pasta escolhida pelo usuario, dentro do destino configurado.
  ///
  /// Vem vazia quando o usuario ainda nao customizou — nesse caso o app
  /// usa a pasta padrao (`Scroott`).
  String get customFolder => _preferences?.getString(_customFolderKey) ?? '';

  /// Define a pasta personalizada.
  ///
  /// O nome e sanitizado antes de ser gravado: barras, dois-pontos e
  /// outros caracteres de caminho nao podem entrar.
  Future<void> setCustomFolder(String folder) async {
    final cleaned = folder
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    if (cleaned.isEmpty) {
      await _preferences?.remove(_customFolderKey);
      return;
    }
    await _preferences?.setString(_customFolderKey, cleaned);
  }

  /// Qualidade do audio em kbps.
  int get audioQuality => _preferences?.getInt(_audioQualityKey) ?? 128;

  /// Define a qualidade do audio.
  Future<void> setAudioQuality(int kbps) async {
    await _preferences?.setInt(_audioQualityKey, kbps);
  }

  /// Mantem as gravacoes no aparelho apos salvar.
  bool get keepOnDevice => _preferences?.getBool(_keepOnDeviceKey) ?? true;

  Future<void> setKeepOnDevice(bool value) async {
    await _preferences?.setBool(_keepOnDeviceKey, value);
  }

  /// Supressao de ruido na captura.
  bool get noiseSuppress => _preferences?.getBool(_noiseSuppressKey) ?? true;

  Future<void> setNoiseSuppress(bool value) async {
    await _preferences?.setBool(_noiseSuppressKey, value);
  }

  /// Ganho automatico na captura.
  bool get autoGain => _preferences?.getBool(_autoGainKey) ?? true;

  Future<void> setAutoGain(bool value) async {
    await _preferences?.setBool(_autoGainKey, value);
  }

  /// Cancelamento de eco na captura.
  bool get echoCancel => _preferences?.getBool(_echoCancelKey) ?? true;

  Future<void> setEchoCancel(bool value) async {
    await _preferences?.setBool(_echoCancelKey, value);
  }
}
