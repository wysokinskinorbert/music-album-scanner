#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>
#include "llama.h"

#define LOG_TAG "SmolVLMNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Globalne zmienne dla modelu
static llama_model* g_model = nullptr;
static llama_context* g_ctx = nullptr;
static llama_sampler* g_sampler = nullptr;

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_example_music_1album_1scanner_SmolVLMBridge_loadModel(
    JNIEnv* env,
    jobject /*thiz*/,
    jstring modelPath,
    jstring mmprojPath
) {
    const char* model_path = env->GetStringUTFChars(modelPath, nullptr);
    const char* mmproj_path = env->GetStringUTFChars(mmprojPath, nullptr);
    
    LOGI("Loading model from: %s", model_path);
    LOGI("Loading mmproj from: %s", mmproj_path);
    
    // Inicjalizacja llama
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0; // CPU only
    
    g_model = llama_load_model_from_file(model_path, model_params);
    if (!g_model) {
        LOGE("Failed to load model");
        env->ReleaseStringUTFChars(modelPath, model_path);
        env->ReleaseStringUTFChars(mmprojPath, mmproj_path);
        return JNI_FALSE;
    }
    
    // Kontekst
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048;
    ctx_params.n_batch = 512;
    
    g_ctx = llama_new_context_with_model(g_model, ctx_params);
    if (!g_ctx) {
        LOGE("Failed to create context");
        llama_free_model(g_model);
        g_model = nullptr;
        env->ReleaseStringUTFChars(modelPath, model_path);
        env->ReleaseStringUTFChars(mmprojPath, mmproj_path);
        return JNI_FALSE;
    }
    
    // Sampler
    g_sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(g_sampler, llama_sampler_init_greedy());
    
    LOGI("Model loaded successfully");
    
    env->ReleaseStringUTFChars(modelPath, model_path);
    env->ReleaseStringUTFChars(mmprojPath, mmproj_path);
    return JNI_TRUE;
}

JNIEXPORT jstring JNICALL
Java_com_example_music_1album_1scanner_SmolVLMBridge_processImage(
    JNIEnv* env,
    jobject /*thiz*/,
    jstring imagePath,
    jstring prompt
) {
    const char* image_path = env->GetStringUTFChars(imagePath, nullptr);
    const char* prompt_str = env->GetStringUTFChars(prompt, nullptr);
    
    LOGI("Processing image: %s", image_path);
    LOGI("Prompt: %s", prompt_str);
    
    // TODO: Implementacja przetwarzania obrazu
    // To wymaga załadowania obrazu, tokenizacji promptu,
    // i generacji odpowiedzi przez llama.cpp
    
    std::string result = "Not implemented yet";
    
    env->ReleaseStringUTFChars(imagePath, image_path);
    env->ReleaseStringUTFChars(prompt, prompt_str);
    
    return env->NewStringUTF(result.c_str());
}

JNIEXPORT void JNICALL
Java_com_example_music_1album_1scanner_SmolVLMBridge_unloadModel(
    JNIEnv* /*env*/,
    jobject /*thiz*/
) {
    LOGI("Unloading model");
    
    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
    if (g_ctx) {
        llama_free(g_ctx);
        g_ctx = nullptr;
    }
    if (g_model) {
        llama_free_model(g_model);
        g_model = nullptr;
    }
}

} // extern "C"
