import 'package:flutter/widgets.dart';

import 'app_settings.dart';

/// Disponibiliza o [AppSettings] para a árvore de widgets.
///
/// Um [InheritedNotifier] resolve o caso sem trazer dependência extra: as
/// telas que chamam [AppScope.of] são reconstruídas sozinhas quando o
/// estado muda (nome do usuário, animações, lista de gravações).
class AppScope extends InheritedNotifier<AppSettings> {
  const AppScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  /// Recupera o [AppSettings] mais próximo.
  ///
  /// Lança um [FlutterError] se a tela for usada fora do [AppScope] — isso
  /// denuncia na hora um erro de montagem, em vez de um crash silencioso
  /// mais tarde.
  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null || scope.notifier == null) {
      throw FlutterError(
        'AppScope.of() foi chamado com um contexto que não contém um AppScope.\n'
        'Envolva a aplicação em um AppScope ou use AppScope.maybeOf().',
      );
    }
    return scope.notifier!;
  }

  /// Igual a [of], mas devolve `null` quando não há [AppScope] no contexto.
  static AppSettings? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    return scope?.notifier;
  }
}
