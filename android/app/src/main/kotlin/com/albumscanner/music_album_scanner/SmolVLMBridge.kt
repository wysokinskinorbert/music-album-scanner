package com.albumscanner.music_album_scanner

import android.content.Context
import android.util.Log
import java.io.File

class SmolVLMBridge(private val context: Context) {
    companion object {
        private const val TAG = "SmolVLMBridge"
        
        init {
            System.loadLibrary("smolvlm_native")
        }
    }
    
    private external fun loadModel(modelPath: String, mmprojPath: String): Boolean
    private external fun processImage(imagePath: String, prompt: String): String
    private external fun unloadModel()
    
    private var isModelLoaded = false
    
    fun initializeModel(): Boolean {
        if (isModelLoaded) return true
        
        val modelFile = File(context.filesDir, "models/SmolVLM-256M-Instruct-Q8_0.gguf")
        val mmprojFile = File(context.filesDir, "models/mmproj-SmolVLM-256M-Instruct-Q8_0.gguf")
        
        if (!modelFile.exists() || !mmprojFile.exists()) {
            Log.e(TAG, "Model files not found. Model: ${modelFile.exists()}, MMProj: ${mmprojFile.exists()}")
            return false
        }
        
        val result = loadModel(modelFile.absolutePath, mmprojFile.absolutePath)
        isModelLoaded = result
        
        if (result) {
            Log.i(TAG, "Model loaded successfully")
        } else {
            Log.e(TAG, "Failed to load model")
        }
        
        return result
    }
    
    fun recognizeAlbum(imagePath: String): String {
        if (!isModelLoaded) {
            if (!initializeModel()) {
                return "Error: Model not loaded"
            }
        }
        
        val prompt = "What album is this? Name the artist and album title."
        return processImage(imagePath, prompt)
    }
    
    fun release() {
        if (isModelLoaded) {
            unloadModel()
            isModelLoaded = false
            Log.i(TAG, "Model unloaded")
        }
    }
}
