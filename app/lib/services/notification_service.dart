import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Ações de acesso rápido disponíveis na notificação do gravador.
///
/// Cada ação vira um botão na notificação persistente do Android e é
/// entregue de volta ao app por [NotificationService.onAction].
enum RecorderAction {
  /// Pausa a gravação em andamento.
  pause,

  /// Retoma uma gravação pausada.
  resume,

  /// Interrompe e finaliza a gravação.
  stop,

  /// Zera o temporizador da gravação mantendo o áudio.
  restart,
}

/// Callback executado quando o usuário toca em uma ação da notificação.
typedef RecorderActionCallback = void Function(RecorderAction action);

/// Fachada da notificação persistente do gravador.
///
/// Mantém uma notificação fixa na barra de status com o tempo decorrido e
/// botões de acesso rápido (pausar, continuar, parar), permitindo controlar
/// a gravação sem reabrir o aplicativo.
///
/// O serviço Android [`RecordingService`] publica a notificação de primeiro
/// plano; este lado Dart a atualiza a cada segundo com o tempo decorrido e
/// recebe os toques nos botões de ação.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Canal do Android 8+ para a notificação de gravação.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'scrott_recording',
    'Recording',
    description: 'Shows the ongoing recording with quick actions.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  /// Identificador da notificação de gravação.
  static const int _recordingNotificationId = 1001;

  /// Canal que conversa com o `RecordingService` nativo.
  static const MethodChannel _serviceChannel =
      MethodChannel('com.scrott.voice/recorder_service');

  /// Canal que recebe as ações disparadas pelo serviço nativo.
  static const MethodChannel _actionChannel =
      MethodChannel('com.scrott.voice/recorder_actions');

  bool _initialized = false;
  RecorderActionCallback? _onAction;
  Timer? _ticker;

  /// Registra o callback que recebe as ações disparadas pela notificação.
  void setActionCallback(RecorderActionCallback callback) {
    _onAction = callback;
  }

  /// Inicializa o plugin, o canal nativo e o ouvinte de ações.
  Future<void> initialize({RecorderActionCallback? actionCallback}) async {
    if (actionCallback != null) _onAction = actionCallback;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);

    _actionChannel.setMethodCallHandler(_handleNativeCall);

    _initialized = true;
  }

  /// Solicita a permissão de notificação (Android 13+).
  ///
  /// Retorna `true` quando a permissão foi concedida ou já existia.
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    try {
      return await androidPlugin.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Publica (ou atualiza) a notificação de gravação em andamento.
  ///
  /// [elapsed] é o tempo já decorrido e [paused] indica se a gravação está
  /// pausada. As ações exibidas mudam conforme o estado: "Pause" aparece
  /// enquanto grava e "Resume" enquanto está pausada.
  Future<void> showRecording({
    required Duration elapsed,
    required bool paused,
  }) async {
    if (!_initialized) await initialize();

    final label = formatDuration(elapsed);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: false,
        silent: true,
        ticker: paused ? 'Recording paused' : 'Recording',
        styleInformation: BigTextStyleInformation(
          paused ? 'Paused' : 'Recording',
          contentTitle: label,
        ),
        actions: actionsFor(paused),
      ),
    );

    try {
      await _plugin.show(
        _recordingNotificationId,
        label,
        paused ? 'Paused' : 'Recording',
        details,
      );
    } catch (_) {
      // A notificação é um complemento: falhar aqui não pode derrubar a
      // gravação, que é a função principal do app.
    }

    await _syncNativeService(elapsed: elapsed, paused: paused);
  }

  /// Mantém o serviço nativo de primeiro plano em sincronia com o app.
  Future<void> _syncNativeService({
    required Duration elapsed,
    required bool paused,
  }) async {
    try {
      await _serviceChannel.invokeMethod<void>('start', <String, Object>{
        'elapsed': formatDuration(elapsed),
        'paused': paused,
      });
    } catch (_) {
      // Sem serviço nativo (web/desktop ou engine ainda não registrado):
      // a notificação do plugin já cobre o caso de uso.
    }
  }

  /// Encerra o serviço nativo e remove a notificação de gravação.
  Future<void> cancelRecording() async {
    stopTicker();
    try {
      await _serviceChannel.invokeMethod<void>('stop');
    } catch (_) {
      // Idem: falha ao remover o serviço não é crítica.
    }
    try {
      await _plugin.cancel(_recordingNotificationId);
    } catch (_) {
      // Idem: falha ao remover a notificação não é crítica.
    }
  }

  /// Atualiza a notificação periodicamente enquanto a gravação corre.
  ///
  /// [elapsed] e [isPaused] são Functions para que o valor lido seja sempre
  /// o mais recente — é o mesmo relógio que a tela usa, garantindo que a
  /// notificação e a interface mostrem exatamente o mesmo tempo.
  void startTicker({
    required Duration Function() elapsed,
    required bool Function() isPaused,
    Duration interval = const Duration(seconds: 1),
  }) {
    _ticker?.cancel();
    _ticker = Timer.periodic(interval, (_) async {
      await showRecording(elapsed: elapsed(), paused: isPaused());
    });
  }

  /// Encerra o atualizador periódico da notificação.
  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Monta as ações de acesso rápido conforme o estado da gravação.
  ///
  /// O Android aceita no máximo três ações visíveis, então a gravação
  /// pausada troca "Pause" por "Resume" mantendo sempre "Stop" à mão.
  static List<AndroidNotificationAction> actionsFor(bool paused) {
    if (paused) {
      return const [
        AndroidNotificationAction(
          'resume',
          'Resume',
          showsUserInterface: true,
          cancelNotification: false,
          icon: DrawableResourceAndroidBitmap('ic_mic'),
        ),
        AndroidNotificationAction(
          'restart',
          'Restart',
          showsUserInterface: false,
          cancelNotification: false,
          icon: DrawableResourceAndroidBitmap('ic_refresh'),
        ),
        AndroidNotificationAction(
          'stop',
          'Stop',
          showsUserInterface: false,
          cancelNotification: false,
          icon: DrawableResourceAndroidBitmap('ic_stop'),
        ),
      ];
    }
    return const [
      AndroidNotificationAction(
        'pause',
        'Pause',
        showsUserInterface: true,
        cancelNotification: false,
        icon: DrawableResourceAndroidBitmap('ic_pause'),
      ),
      AndroidNotificationAction(
        'stop',
        'Stop',
        showsUserInterface: false,
        cancelNotification: false,
        icon: DrawableResourceAndroidBitmap('ic_stop'),
      ),
    ];
  }

  /// Converte o identificador textual da ação em [RecorderAction].
  static RecorderAction? parseAction(String? id) {
    switch (id) {
      case 'pause':
        return RecorderAction.pause;
      case 'resume':
        return RecorderAction.resume;
      case 'stop':
        return RecorderAction.stop;
      case 'restart':
        return RecorderAction.restart;
      default:
        return null;
    }
  }

  /// Formata a duração no padrão `mm:ss` (ou `h:mm:ss` acima de uma hora).
  static String formatDuration(Duration d) {
    final total = d.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$mm:$ss';
    return '$mm:$ss';
  }

  void _handleResponse(NotificationResponse response) {
    final action = parseAction(response.actionId);
    if (action != null) {
      _onAction?.call(action);
      return;
    }
    // Toque no corpo da notificação (sem ação): o app volta para a frente.
    _onAction?.call(RecorderAction.pause);
  }

  /// Recebe as ações vindas do `RecordingService` nativo.
  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'recorderAction') return;
    final action = parseAction(call.arguments as String?);
    if (action != null) _onAction?.call(action);
  }

  /// Registra o motor Flutter no cache nativo para que o serviço em
  /// primeiro plano consiga falar com o Dart.
  Future<void> registerEngine(String engineId) async {
    try {
      await _serviceChannel.invokeMethod<void>(
        'registerEngine',
        <String, Object>{'id': engineId},
      );
    } catch (_) {
      // Sem serviço nativo disponível: segue apenas com o plugin.
    }
  }
}

/// Manipulador obrigatório para callbacks em background do plugin.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {}
