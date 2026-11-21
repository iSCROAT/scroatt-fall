import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrott_voice/core/theme/app_colors.dart';
import 'package:scrott_voice/core/widgets/app_icon.dart';
import 'package:scrott_voice/features/onboarding/welcome_screen.dart';
import 'package:scrott_voice/services/app_scope.dart';
import 'package:scrott_voice/services/app_settings.dart';

/// Monta a tela inicial dentro de um [AppScope].
///
/// A tela le o estado compartilhado (nome do usuario, preferencia de
/// animacao), entao precisa do `AppScope` por volta.
Future<void> pumpWelcome(WidgetTester tester) async {
  final settings = AppSettings();
  await tester.pumpWidget(
    AppScope(
      settings: settings,
      child: const MaterialApp(
        home: Scaffold(body: WelcomeScreen()),
      ),
    ),
  );
  // A orbita brilha em laco; `pumpAndSettle` nunca terminaria, entao o
  // tempo avanca de forma fixa.
  await tester.pump(const Duration(milliseconds: 600));

  // A gravacao mantem animacoes continuas: desmontar a arvore no fim do
  // teste evita que o runner fique esperando por elas.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

void main() {
  testWidgets('a tela inicial exibe título, subtítulo e o botão Start Now',
      (tester) async {
    await pumpWelcome(tester);

    expect(find.text('Speech\nRecognition'), findsOneWidget);
    expect(
      find.text('Save time with smart\nvoice transcription.'),
      findsOneWidget,
    );
    expect(find.text('Start Now'), findsOneWidget);
  });

  testWidgets('o botão Start Now navega para a tela de gravação',
      (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Start Now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // A tela de gravação tem o título "Record" na barra superior.
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('usa o fundo escuro do tema do app', (tester) async {
    await pumpWelcome(tester);

    // A tela inicial tem o proprio `Scaffold`, com o fundo escuro do
    // tema — o `Scaffold` externo do teste é o do harness.
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(WelcomeScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, AppColors.background);
  });

  testWidgets('os ícones do catálogo resolvem para assets existentes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppIcon(AppIcons.mic),
              AppIcon(AppIcons.chevronLeft),
              AppIcon(AppIcons.play),
              AppIcon(AppIcons.settings),
              AppIcon(AppIcons.text),
              AppIcon(AppIcons.trim),
              AppIcon(AppIcons.volume),
              AppIcon(AppIcons.enhance),
              AppIcon(AppIcons.bookmark),
              AppIcon(AppIcons.more),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppIcon), findsNWidgets(10));
  });
}
