package com.albumscanner.music_album_scanner

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.albumscanner.music_album_scanner/smolvlm"
    private var smolVLMBridge: SmolVLMBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        smolVLMBridge = SmolVLMBridge(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeModel" -> {
                    val success = smolVLMBridge?.initializeModel() ?: false
                    result.success(success)
                }
                "recognizeAlbum" -> {
                    val imagePath = call.argument<String>("imagePath")
                    if (imagePath != null) {
                        val response = smolVLMBridge?.recognizeAlbum(imagePath) ?: "Error"
                        result.success(response)
                    } else {
                        result.error("INVALID_ARGUMENT", "imagePath is required", null)
                    }
                }
                "releaseModel" -> {
                    smolVLMBridge?.release()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        smolVLMBridge?.release()
        super.onDestroy()
    }
}
