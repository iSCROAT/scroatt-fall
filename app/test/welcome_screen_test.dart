import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrott_voice/core/theme/app_colors.dart';
import 'package:scrott_voice/core/widgets/app_icon.dart';
import 'package:scrott_voice/features/onboarding/welcome_screen.dart';

void main() {
  testWidgets('a tela inicial exibe título, subtítulo e o botão Start Now',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Speech\nRecognition'), findsOneWidget);
    expect(
      find.text('Save time with smart\nvoice transcription.'),
      findsOneWidget,
    );
    expect(find.text('Start Now'), findsOneWidget);
  });

  testWidgets('o botão Start Now navega para a tela de gravação',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Start Now'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // A tela de gravação tem o título "Record" na barra superior.
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('usa o fundo escuro do tema do app', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WelcomeScreen()),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
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
