import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrott_voice/core/widgets/app_icon.dart';
import 'package:scrott_voice/features/record/record_screen.dart';
import 'package:scrott_voice/services/app_scope.dart';
import 'package:scrott_voice/services/app_settings.dart';

/// Monta a tela de gravação dentro de um [AppScope].
Future<AppSettings> pumpRecorder(
  WidgetTester tester, {
  Size size = const Size(360, 780),
}) async {
  final settings = AppSettings();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    AppScope(
      settings: settings,
      child: const MaterialApp(
        home: Scaffold(body: RecordScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return settings;
}

void main() {
  testWidgets('a linha de controles cabe na tela sem estourar',
      (tester) async {
    await pumpRecorder(tester);

    // O `Row` dos cinco controles não pode gerar overflow: o Flutter
    // sinalizaria com a faixa amarela no topo da tela.
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saudação usa o nome escolhido pelo usuário',
      (tester) async {
    final settings = await pumpRecorder(tester);

    await settings.setDisplayName('Marina');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Hello Marina'), findsOneWidget);
  });

  testWidgets('as configurações têm campo de nome e toggle de animação',
      (tester) async {
    await pumpRecorder(tester);

    // Abre as configurações pelo ícone da barra superior.
    await tester.tap(find.byWidgetPredicate(
      (w) => w is AppIcon && w.asset == AppIcons.settings,
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('YOUR NAME'), findsOneWidget);
    expect(find.text('Live waveform animation'), findsOneWidget);
  });
}
