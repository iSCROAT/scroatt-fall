import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrott_voice/services/user_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('UserPreferences', () {
    test('a animação pesada vem desligada por padrão', () async {
      final prefs = UserPreferences();
      await prefs.load();

      expect(prefs.animationsEnabled, isFalse);
    });

    test('o nome vem vazio até o usuário escolher um', () async {
      final prefs = UserPreferences();
      await prefs.load();

      expect(prefs.displayName, isEmpty);
      expect(prefs.displayNameOrDefault, UserPreferences.defaultName);
    });

    test('guarda e recupera o nome escolhido', () async {
      final prefs = UserPreferences();
      await prefs.load();

      await prefs.setDisplayName('  Marina  ');

      expect(prefs.displayName, 'Marina');
      expect(prefs.displayNameOrDefault, 'Marina');
    });

    test('um nome em branco apaga a preferência', () async {
      final prefs = UserPreferences();
      await prefs.load();
      await prefs.setDisplayName('Marina');

      await prefs.setDisplayName('   ');

      expect(prefs.displayName, isEmpty);
      expect(prefs.displayNameOrDefault, UserPreferences.defaultName);
    });

    test('a preferência de animação sobrevive a um novo carregamento',
        () async {
      final prefs = UserPreferences();
      await prefs.load();
      await prefs.setAnimationsEnabled(true);

      final reloaded = UserPreferences();
      await reloaded.load();

      expect(reloaded.animationsEnabled, isTrue);
    });
  });
}
