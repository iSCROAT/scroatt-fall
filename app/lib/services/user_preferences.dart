import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Preferências do usuário que atravessam as telas.
///
/// Centraliza ajustes que não pertencem a uma gravação específica — como o
/// nome de exibição e a preferência de animação — para que qualquer tela
/// possa lê-los sem conhecer a origem.
class UserPreferences {
  UserPreferences({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;

  static const String _nameKey = 'user_display_name';
  static const String _animationsKey = 'user_animations_enabled';

  /// Valor exibido quando o usuário ainda não escolheu um nome.
  static const String defaultName = 'there';

  /// Carrega as preferências persistidas.
  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
  }

  /// Nome de exibição escolhido pelo usuário.
  ///
  /// Devolve uma string vazia quando o nome ainda não foi definido, para que
  /// a interface possa cair no texto padrão.
  String get displayName => _preferences?.getString(_nameKey) ?? '';

  /// Define o nome de exibição.
  ///
  /// Nomes em branco são tratados como "não definido" e removidos da
  /// persistência, evitando gravar espaços que apareceriam na transcrição.
  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await _preferences?.remove(_nameKey);
      return;
    }
    await _preferences?.setString(_nameKey, trimmed);
  }

  /// Nome pronto para exibir: o que o usuário escolheu ou o padrão.
  String get displayNameOrDefault {
    final name = displayName;
    return name.isEmpty ? defaultName : name;
  }

  /// Indica se as animações pesadas (malha da waveform) estão ativas.
  ///
  /// Vem desligado por padrão: a malha redesenha milhares de segmentos a
  /// cada quadro e pesa em aparelhos modestos. O usuário pode ligá-la nas
  /// configurações.
  bool get animationsEnabled => _preferences?.getBool(_animationsKey) ?? false;

  /// Liga ou desliga as animações pesadas.
  Future<void> setAnimationsEnabled(bool enabled) async {
    await _preferences?.setBool(_animationsKey, enabled);
  }
}
