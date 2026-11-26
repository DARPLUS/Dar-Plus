package com.darplus.dar_plus

import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtone: android.media.Ringtone? = null
    private var toneGenerator: android.media.ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dar_plus/ringtone")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    try {
                        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                        ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                        ringtone?.play()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PLAY_ERROR", e.message, null)
                    }
                }
                "playRingback" -> {
                    try {
                        toneGenerator?.release()
                        toneGenerator = android.media.ToneGenerator(android.media.AudioManager.STREAM_VOICE_CALL, 80)
                        toneGenerator?.startTone(android.media.ToneGenerator.TONE_SUP_RINGTONE, 2000)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RINGBACK_ERROR", e.message, null)
                    }
                }
                "stop" -> {
                    try {
                        ringtone?.stop()
                        ringtone = null
                        toneGenerator?.stopTone()
                        toneGenerator?.release()
                        toneGenerator = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
