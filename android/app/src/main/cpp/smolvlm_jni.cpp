#include <jni.h>
#include <string>
#include <vector>
#include <cstdio>
#include <cerrno>
#include <cstring>
#include <android/log.h>
#include <android/asset_manager.h>
#include <android/bitmap.h>

#include "llama.h"
#include "ggml.h"
#include "mtmd.h"
#include "mtmd-helper.h"
#include "common.h"
#include "sampling.h"
#include "chat.h"

#define LOG_TAG "SmolVLMNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)

// Global state
static llama_model   * g_model   = nullptr;
static llama_context * g_ctx     = nullptr;
static mtmd_context  * g_mtmd    = nullptr;
static common_sampler * g_smpl   = nullptr;
static const llama_vocab * g_vocab = nullptr;
static llama_pos g_n_past = 0;

// Max tokens to generate
static const int MAX_TOKENS = 64;

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_albumscanner_music_1album_1scanner_SmolVLMBridge_loadModel(
    JNIEnv* env,
    jobject /*thiz*/,
    jstring modelPath,
    jstring mmprojPath)
{
    const char* model_path  = env->GetStringUTFChars(modelPath, nullptr);
    const char* mmproj_path = env->GetStringUTFChars(mmprojPath, nullptr);

    LOGI("=== SmolVLM Load Model ===");
    LOGI("Model:  %s", model_path);
    LOGI("MMProj: %s", mmproj_path);

    // 1. Load backends
    ggml_backend_load_all();
    LOGI("Backends loaded");

    // 2. Load text model
    auto mparams = llama_model_default_params();
    mparams.n_gpu_layers = 0; // CPU only

    // Try to open the file first to check access
    FILE* f = fopen(model_path, "rb");
    if (f) {
        fseek(f, 0, SEEK_END);
        long size = ftell(f);
        fclose(f);
        LOGI("File accessible: %ld bytes", size);
    } else {
        LOGE("Cannot open file: %s (errno=%d: %s)", model_path, errno, strerror(errno));
    }

    g_model = llama_load_model_from_file(model_path, mparams);
    if (!g_model) {
        LOGE("Failed to load text model from: %s", model_path);
        LOGE("This could be: wrong format, corrupted file, or unsupported model");
        env->ReleaseStringUTFChars(modelPath, model_path);
        env->ReleaseStringUTFChars(mmprojPath, mmproj_path);
        return JNI_FALSE;
    }
    LOGI("Text model loaded");

    // 3. Create context
    auto cparams = llama_context_default_params();
    cparams.n_ctx      = 2048;
    cparams.n_batch    = 512;
    cparams.n_threads  = 4;
    cparams.n_threads_batch = 4;

    g_ctx = llama_new_context_with_model(g_model, cparams);
    if (!g_ctx) {
        LOGE("Failed to create context");
        llama_free_model(g_model);
        g_model = nullptr;
        env->ReleaseStringUTFChars(modelPath, model_path);
        env->ReleaseStringUTFChars(mmprojPath, mmproj_path);
        return JNI_FALSE;
    }
    LOGI("Context created (n_ctx=2048, n_threads=4)");

    g_vocab = llama_model_get_vocab(g_model);

    // 4. Init mtmd (multimodal/vision context)
    auto mtparams = mtmd_context_params_default();
    mtparams.use_gpu       = false;
    mtparams.print_timings = false;
    mtparams.n_threads     = 4;
    mtparams.warmup        = false;

    g_mtmd = mtmd_init_from_file(mmproj_path, g_model, mtparams);
    if (!g_mtmd) {
        LOGE("Failed to init mtmd from: %s", mmproj_path);
        llama_free(g_ctx);
        llama_free_model(g_model);
        g_ctx   = nullptr;
        g_model = nullptr;
        env->ReleaseStringUTFChars(modelPath, model_path);
        env->ReleaseStringUTFChars(mmprojPath, mmproj_path);
        return JNI_FALSE;
    }
    LOGI("MTMD (vision) context initialized");

    // 5. Init sampler with repetition penalty to avoid loops
    struct common_params_sampling sparams;
    sparams.temp = 0.1f;    // near-greedy but allows some variation
    sparams.top_k = 40;
    sparams.penalty_repeat = 1.2f;  // penalize repeating tokens
    sparams.penalty_last_n = 64;    // look back 64 tokens for repeats
    g_smpl = common_sampler_init(g_model, sparams);
    LOGI("Sampler initialized (temp=0.1, repeat_penalty=1.2)");

    g_n_past = 0;

    LOGI("=== Model loaded successfully ===");

    env->ReleaseStringUTFChars(modelPath, model_path);
    env->ReleaseStringUTFChars(mmprojPath, mmproj_path);
    return JNI_TRUE;
}

JNIEXPORT jstring JNICALL
Java_com_albumscanner_music_1album_1scanner_SmolVLMBridge_processImage(
    JNIEnv* env,
    jobject /*thiz*/,
    jstring imagePath,
    jstring prompt)
{
    const char* image_path  = env->GetStringUTFChars(imagePath, nullptr);
    const char* prompt_str  = env->GetStringUTFChars(prompt, nullptr);

    LOGI("=== Process Image ===");
    LOGI("Image:  %s", image_path);
    LOGI("Prompt: %s", prompt_str);

    if (!g_model || !g_ctx || !g_mtmd) {
        LOGE("Model not loaded");
        env->ReleaseStringUTFChars(imagePath, image_path);
        env->ReleaseStringUTFChars(prompt, prompt_str);
        return env->NewStringUTF("Error: Model not loaded");
    }

    std::string result_text;

    // 1. Load image bitmap
    mtmd_bitmap * bitmap = mtmd_helper_bitmap_init_from_file(g_mtmd, image_path);
    if (!bitmap) {
        LOGE("Failed to load image: %s", image_path);
        env->ReleaseStringUTFChars(imagePath, image_path);
        env->ReleaseStringUTFChars(prompt, prompt_str);
        return env->NewStringUTF("Error: Cannot load image");
    }
    LOGI("Image loaded: %ux%u", mtmd_bitmap_get_nx(bitmap), mtmd_bitmap_get_ny(bitmap));

    // 2. Build the chat message with media marker
    // SmolVLM uses Idefics3 chat template
    // mtmd uses <__media__> as the default media marker
    std::string user_prompt = std::string("<__media__>\n") + prompt_str;
    // 3. Tokenize with image
    const mtmd_bitmap * bitmaps[] = { bitmap };
    mtmd_input_text text;
    text.text          = user_prompt.c_str();
    text.add_special   = true;
    text.parse_special = true;

    mtmd_input_chunks * chunks = mtmd_input_chunks_init();
    int32_t tok_res = mtmd_tokenize(g_mtmd, chunks, &text, bitmaps, 1);
    if (tok_res != 0) {
        LOGE("mtmd_tokenize failed: %d", tok_res);
        mtmd_input_chunks_free(chunks);
        mtmd_bitmap_free(bitmap);
        env->ReleaseStringUTFChars(imagePath, image_path);
        env->ReleaseStringUTFChars(prompt, prompt_str);
        return env->NewStringUTF("Error: Tokenization failed");
    }
    LOGI("Tokenized successfully, %zu chunks", mtmd_input_chunks_size(chunks));

    // 4. Reset state for new inference
    g_n_past = 0;
    common_sampler_reset(g_smpl);
    // Clear KV cache from previous inference
    llama_memory_clear(llama_get_memory(g_ctx), true);

    // 5. Evaluate chunks (text + image embeddings)
    llama_pos new_n_past = 0;
    int32_t eval_res = mtmd_helper_eval_chunks(g_mtmd, g_ctx, chunks,
                                                g_n_past,  // n_past
                                                0,         // seq_id
                                                512,       // n_batch
                                                true,      // logits_last
                                                &new_n_past);
    if (eval_res != 0) {
        LOGE("mtmd_helper_eval_chunks failed: %d", eval_res);
        mtmd_input_chunks_free(chunks);
        mtmd_bitmap_free(bitmap);
        env->ReleaseStringUTFChars(imagePath, image_path);
        env->ReleaseStringUTFChars(prompt, prompt_str);
        return env->NewStringUTF("Error: Eval chunks failed");
    }
    g_n_past = new_n_past;
    LOGI("Chunks evaluated, n_past=%d", (int)g_n_past);

    // Cleanup chunks and bitmap
    mtmd_input_chunks_free(chunks);
    mtmd_bitmap_free(bitmap);

    // 6. Generate response token by token
    llama_batch batch = llama_batch_init(1, 0, 1);
    std::vector<llama_token> generated_tokens;

    LOGI("Generating response...");

    for (int i = 0; i < MAX_TOKENS; i++) {
        // Sample next token
        llama_token token = common_sampler_sample(g_smpl, g_ctx, -1);
        generated_tokens.push_back(token);
        common_sampler_accept(g_smpl, token, true);

        // Check for end of generation
        if (llama_vocab_is_eog(g_vocab, token)) {
            LOGI("EOS token at position %d", i);
            break;
        }

        // Decode the token piece for logging
        std::string piece = common_token_to_piece(g_ctx, token);
        LOGI("Token %d: '%s' (id=%d)", i, piece.c_str(), (int)token);

        // Eval the generated token
        common_batch_clear(batch);
        common_batch_add(batch, token, g_n_past++, {0}, true);

        if (llama_decode(g_ctx, batch) != 0) {
            LOGE("llama_decode failed at token %d", i);
            break;
        }
    }

    llama_batch_free(batch);

    // 7. Convert tokens to text
    result_text = common_detokenize(g_ctx, generated_tokens);

    LOGI("=== Result: '%s' ===", result_text.c_str());

    env->ReleaseStringUTFChars(imagePath, image_path);
    env->ReleaseStringUTFChars(prompt, prompt_str);

    return env->NewStringUTF(result_text.c_str());
}

JNIEXPORT void JNICALL
Java_com_albumscanner_music_1album_1scanner_SmolVLMBridge_unloadModel(
    JNIEnv* /*env*/,
    jobject /*thiz*/)
{
    LOGI("=== Unloading model ===");

    if (g_smpl) {
        common_sampler_free(g_smpl);
        g_smpl = nullptr;
    }
    if (g_mtmd) {
        mtmd_free(g_mtmd);
        g_mtmd = nullptr;
    }
    if (g_ctx) {
        llama_free(g_ctx);
        g_ctx = nullptr;
    }
    if (g_model) {
        llama_free_model(g_model);
        g_model = nullptr;
    }
    g_vocab   = nullptr;
    g_n_past  = 0;

    LOGI("Model unloaded");
}

} // extern "C"
