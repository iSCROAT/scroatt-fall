import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'features/library/library_screen.dart';
import 'features/onboarding/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // `setSystemUIOverlayStyle` retorna void (apenas aplica o estilo).
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF05070D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ScroattApp());
}

/// Scroatt — gravador de voz com transcrição.
class ScroattApp extends StatelessWidget {
  const ScroattApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scroatt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      home: const _RootRouter(),
    );
  }
}

/// Roteador raiz: alterna entre a home e a biblioteca com um toque
/// na barra inferior flutuante.
class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  final int _index = 0;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _index,
      children: const [
        WelcomeScreen(),
        LibraryScreen(),
      ],
    );
  }
}
