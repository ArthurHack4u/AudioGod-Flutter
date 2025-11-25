package com.moran.audio_god_eq

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.audiofx.Equalizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.moran.audio_god_eq/audio"
    private var equalizer: Equalizer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "activarEQ") {
                try {
                    val sessionId = call.argument<Int>("sessionId") ?: 0
                    equalizer?.release()
                    // PRIORIDAD ALTA (1000) para pelear contra el sistema (Spotify Mode)
                    equalizer = Equalizer(1000, sessionId)
                    equalizer?.enabled = true
                    result.success("EQ Android Activo ID:$sessionId")
                } catch (e: Exception) {
                    try {
                        // Respaldo prioridad 0
                        equalizer = Equalizer(0, 0)
                        equalizer?.enabled = true
                        result.success("EQ Activo (Respaldo)")
                    } catch(e2: Exception) { result.error("ERR", e2.message, null) }
                }
            } else if (call.method == "setBandLevel") {
                val band = call.argument<Int>("band")
                val level = call.argument<Int>("level") 
                if (band != null && level != null && equalizer != null) {
                    try {
                        val numBands = equalizer?.numberOfBands ?: 5
                        val targetBand = (band.toFloat() / 5.0 * numBands).toInt().toShort()
                        if (targetBand < numBands) {
                            equalizer?.setBandLevel(targetBand, level.toShort())
                            result.success("OK")
                        }
                    } catch (e: Exception) {}
                }
            } else if (call.method == "getDeviceName") {
                // DETECTOR DE SALIDA ANDROID
                try {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    var deviceName = "Altavoz"
                    var priority = -1
                    for (d in devices) {
                        val t = d.type
                        if ((t == AudioDeviceInfo.TYPE_USB_HEADSET || t == AudioDeviceInfo.TYPE_USB_DEVICE) && priority < 3) {
                            deviceName = d.productName.toString(); priority = 3
                        } else if ((t == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP || t == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) && priority < 2) {
                            deviceName = d.productName.toString(); priority = 2
                        } else if ((t == AudioDeviceInfo.TYPE_WIRED_HEADSET || t == AudioDeviceInfo.TYPE_WIRED_HEADPHONES) && priority < 1) {
                            deviceName = d.productName.toString(); priority = 1
                        }
                    }
                    result.success(deviceName)
                } catch (e: Exception) { result.success("Android Audio") }
            } else { result.notImplemented() }
        }
    }
}