package com.albumscanner.music_album_scanner

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class SmolVLMBridge(private val context: Context) {
    companion object {
        private const val TAG = "SmolVLMBridge"
        private val MODEL_FILES = listOf(
            "SmolVLM-256M-Instruct-Q8_0.gguf",
            "mmproj-SmolVLM-256M-Instruct-Q8_0.gguf"
        )

        init {
            System.loadLibrary("smolvlm_native")
        }
    }

    private external fun loadModel(modelPath: String, mmprojPath: String): Boolean
    private external fun processImage(imagePath: String, prompt: String): String
    private external fun unloadModel()

    private var isModelLoaded = false

    /**
     * Copy model files from external/accessible locations to internal storage
     * where the app always has read access regardless of scoped storage.
     */
    private fun ensureModelsInInternalStorage(): File? {
        val internalDir = File(context.filesDir, "models")
        val allExist = MODEL_FILES.all { File(internalDir, it).exists() }

        if (allExist) {
            Log.i(TAG, "Models already in internal storage: ${internalDir.absolutePath}")
            return internalDir
        }

        // Source locations to check (in order of preference)
        val extDir = context.getExternalFilesDir(null)
        val sourceDirs = mutableListOf<File>()
        if (extDir != null) {
            sourceDirs.add(File(extDir, "models"))
        }
        sourceDirs.add(File("/sdcard/Android/data/com.albumscanner.music_album_scanner/files/models"))
        sourceDirs.add(File("/sdcard/Download/models"))

        var sourceDir: File? = null
        for (dir in sourceDirs) {
            if (dir.exists() && MODEL_FILES.all { File(dir, it).exists() }) {
                sourceDir = dir
                Log.i(TAG, "Found source models in: ${dir.absolutePath}")
                break
            }
        }

        if (sourceDir == null) {
            Log.e(TAG, "Model files not found in any external location")
            for (dir in sourceDirs) {
                Log.i(TAG, "  Checked: ${dir.absolutePath} (exists: ${dir.exists()})")
            }
            return null
        }

        // Copy to internal storage
        internalDir.mkdirs()
        for (filename in MODEL_FILES) {
            val src = File(sourceDir, filename)
            val dst = File(internalDir, filename)
            Log.i(TAG, "Copying ${src.absolutePath} -> ${dst.absolutePath} (${src.length()} bytes)")
            try {
                FileInputStream(src).use { input ->
                    FileOutputStream(dst).use { output ->
                        val buf = ByteArray(8 * 1024 * 1024) // 8MB buffer for large files
                        var len: Int
                        while (input.read(buf).also { len = it } > 0) {
                            output.write(buf, 0, len)
                        }
                    }
                }
                Log.i(TAG, "Copied: $filename (${dst.length()} bytes)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to copy $filename: ${e.message}", e)
                // Clean up partial copies
                dst.delete()
                return null
            }
        }

        Log.i(TAG, "All models copied to internal storage")
        return internalDir
    }

    fun initializeModel(): Boolean {
        if (isModelLoaded) return true

        val modelDir = ensureModelsInInternalStorage()
        if (modelDir == null) {
            Log.e(TAG, "Cannot access model files")
            return false
        }

        val modelFile = File(modelDir, "SmolVLM-256M-Instruct-Q8_0.gguf")
        val mmprojFile = File(modelDir, "mmproj-SmolVLM-256M-Instruct-Q8_0.gguf")

        Log.i(TAG, "Loading model: ${modelFile.absolutePath} (${modelFile.length()} bytes)")
        Log.i(TAG, "Loading mmproj: ${mmprojFile.absolutePath} (${mmprojFile.length()} bytes)")

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

        val prompt = "What album cover is this? Reply ONLY: Artist - Album"
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
