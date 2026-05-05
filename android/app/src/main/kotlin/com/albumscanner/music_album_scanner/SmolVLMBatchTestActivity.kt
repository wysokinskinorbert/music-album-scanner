package com.albumscanner.music_album_scanner

import android.app.Activity
import android.os.Bundle
import android.util.Log
import java.io.File
import kotlin.concurrent.thread

/**
 * Batch test: runs SmolVLM on all 19 album covers and logs results.
 * Launch via: am start -n com.albumscanner.music_album_scanner/.SmolVLMBatchTestActivity
 */
class SmolVLMBatchTestActivity : Activity() {
    companion object {
        private const val TAG = "SmolVLMBatch"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        thread {
            runBatchTest()
            finish()
        }
    }

    private fun runBatchTest() {
        val coversDir = File("/sdcard/Download/AlbumCovers")
        if (!coversDir.exists()) {
            Log.e(TAG, "Covers directory not found: ${coversDir.absolutePath}")
            return
        }

        val covers = coversDir.listFiles()
            ?.filter { it.name.endsWith(".jpg") || it.name.endsWith(".png") }
            ?.sortedBy { it.name }
            ?: run {
                Log.e(TAG, "No cover files found")
                return
            }

        Log.i(TAG, "=== SMOLVLM BATCH TEST: ${covers.size} covers ===")

        val bridge = SmolVLMBridge(this)

        // Step 1: Load model once
        Log.i(TAG, "Loading SmolVLM model...")
        val loadStart = System.currentTimeMillis()
        val loaded = bridge.initializeModel()
        val loadTime = (System.currentTimeMillis() - loadStart) / 1000.0
        Log.i(TAG, "Model loaded: $loaded (${String.format("%.1f", loadTime)}s)")
        if (!loaded) {
            Log.e(TAG, "FAILED to load model - aborting batch test")
            return
        }

        // Step 2: Process each cover
        var correct = 0
        var total = 0
        val results = mutableListOf<String>()

        for ((index, cover) in covers.withIndex()) {
            total++
            val coverName = cover.name
            // Extract expected artist and album from filename: "01_Artist_Album.jpg"
            val expected = coverName
                .replace(Regex("^\\d+_"), "")
                .replace(".jpg", "")
                .replace(".png", "")
                .replace("_", " ")

            Log.i(TAG, "--- Cover ${index + 1}/${covers.size}: $coverName ---")
            Log.i(TAG, "Expected: $expected")

            val startTime = System.currentTimeMillis()
            val result = bridge.recognizeAlbum(cover.absolutePath)
            val elapsed = (System.currentTimeMillis() - startTime) / 1000.0

            Log.i(TAG, "SmolVLM (${String.format("%.1f", elapsed)}s): $result")

            // Simple match check: do key words from expected appear in result?
            val expectedWords = expected.lowercase()
                .split(Regex("\\s+"))
                .filter { it.length >= 3 }
                .toSet()
            val resultLower = result.lowercase()
            val matchedWords = expectedWords.filter { resultLower.contains(it) }
            val isMatch = matchedWords.size >= 2 ||
                (matchedWords.size >= 1 && matchedWords.any { it.length >= 4 })

            if (isMatch) correct++

            val status = if (isMatch) "OK  " else "MISS"
            val line = "$status | ${String.format("%-50s", expected)} | ${String.format("%5.1f", elapsed)}s | $result"
            results.add(line)
            Log.i(TAG, "Match: $status (${matchedWords.size}/${expectedWords.size} words: $matchedWords)")
        }

        // Step 3: Release model
        bridge.release()
        Log.i(TAG, "Model released")

        // Step 4: Summary
        val pct = if (total > 0) correct * 100 / total else 0
        Log.i(TAG, "")
        Log.i(TAG, "========================================")
        Log.i(TAG, "=== BATCH TEST COMPLETE ===")
        Log.i(TAG, "=== $correct/$total correct ($pct%) ===")
        Log.i(TAG, "========================================")
        Log.i(TAG, "")
        for (line in results) {
            Log.i(TAG, line)
        }
    }
}
