package com.scrott.voice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // O `RecordingService` usa este registro para entregar as acoes
        // de acesso rapido da notificacao de volta ao Dart.
        FlutterEngineCache.getInstance()
            .put(RecordingService.ENGINE_ID, flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RecordingService.SERVICE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val elapsed = call.argument<String>("elapsed") ?: "00:00"
                    val paused = call.argument<Boolean>("paused") ?: false
                    RecordingService.startRecording(this, elapsed, paused)
                    result.success(null)
                }
                "stop" -> {
                    RecordingService.stopRecording(this)
                    result.success(null)
                }
                "registerEngine" -> {
                    // O motor ja foi registrado no `configureFlutterEngine`.
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
