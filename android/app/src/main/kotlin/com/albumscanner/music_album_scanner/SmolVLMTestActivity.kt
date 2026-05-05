package com.albumscanner.music_album_scanner

import android.app.Activity
import android.os.Bundle
import android.util.Log
import java.io.File

class SmolVLMTestActivity : Activity() {
    private val TAG = "SmolVLMTest"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.i(TAG, "=== SmolVLM Test Activity Started ===")
        
        Thread {
            try {
                val bridge = SmolVLMBridge(this)
                
                // 1. Load model
                Log.i(TAG, "Step 1: Loading model...")
                val loaded = bridge.initializeModel()
                Log.i(TAG, "Model loaded: $loaded")
                
                if (!loaded) {
                    Log.e(TAG, "FAILED: Could not load model")
                    return@Thread
                }
                
                // 2. Test with first cover
                val testImage = "/sdcard/Download/AlbumCovers/01_Aphex_Twin_Selected_Ambient_Works_85-92.jpg"
                Log.i(TAG, "Step 2: Recognizing album from: $testImage")
                
                val result = bridge.recognizeAlbum(testImage)
                Log.i(TAG, "=== RESULT: '$result' ===")
                
                // 3. Release
                bridge.release()
                Log.i(TAG, "Model released")
                
            } catch (e: Exception) {
                Log.e(TAG, "EXCEPTION: ${e.message}", e)
            }
        }.start()
    }
}
