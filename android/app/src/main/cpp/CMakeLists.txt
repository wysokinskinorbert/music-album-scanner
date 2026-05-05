cmake_minimum_required(VERSION 3.22.1)
project("smolvlm")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Only build for arm64-v8a and x86_64 (skip armeabi-v7a which has FP16 issues)
if(ANDROID_ABI STREQUAL "armeabi-v7a")
    message(STATUS "Skipping armeabi-v7a - not supported")
    return()
endif()

# llama.cpp options - ONLY build libraries, no executables
set(LLAMA_BUILD_COMMON ON)
set(LLAMA_BUILD_EXAMPLES OFF)
set(LLAMA_BUILD_TESTS OFF)
set(LLAMA_BUILD_TOOLS OFF)    # Disable tools - we add mtmd manually
set(LLAMA_BUILD_SERVER OFF)
set(LLAMA_BUILD_CLI OFF)
set(BUILD_SHARED_LIBS OFF)

# Suppress some warnings for llama.cpp
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-unused-function -Wno-unused-variable")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-unused-function -Wno-unused-variable")

# Add llama.cpp (builds ggml, llama, common)
add_subdirectory(llama.cpp)

# Manually add mtmd (multimodal) library
set(MTMD_SOURCES
    llama.cpp/tools/mtmd/mtmd.cpp
    llama.cpp/tools/mtmd/mtmd-image.cpp
    llama.cpp/tools/mtmd/mtmd-audio.cpp
    llama.cpp/tools/mtmd/mtmd-helper.cpp
    llama.cpp/tools/mtmd/clip.cpp
    llama.cpp/tools/mtmd/models/llava.cpp
    llama.cpp/tools/mtmd/models/cogvlm.cpp
    llama.cpp/tools/mtmd/models/conformer.cpp
    llama.cpp/tools/mtmd/models/dotsocr.cpp
    llama.cpp/tools/mtmd/models/gemma4a.cpp
    llama.cpp/tools/mtmd/models/gemma4v.cpp
    llama.cpp/tools/mtmd/models/glm4v.cpp
    llama.cpp/tools/mtmd/models/hunyuanocr.cpp
    llama.cpp/tools/mtmd/models/internvl.cpp
    llama.cpp/tools/mtmd/models/kimivl.cpp
    llama.cpp/tools/mtmd/models/kimik25.cpp
    llama.cpp/tools/mtmd/models/nemotron-v2-vl.cpp
    llama.cpp/tools/mtmd/models/llama4.cpp
    llama.cpp/tools/mtmd/models/minicpmv.cpp
    llama.cpp/tools/mtmd/models/paddleocr.cpp
    llama.cpp/tools/mtmd/models/pixtral.cpp
    llama.cpp/tools/mtmd/models/qwen2vl.cpp
    llama.cpp/tools/mtmd/models/qwen3vl.cpp
    llama.cpp/tools/mtmd/models/qwen3a.cpp
    llama.cpp/tools/mtmd/models/step3vl.cpp
    llama.cpp/tools/mtmd/models/siglip.cpp
    llama.cpp/tools/mtmd/models/whisper-enc.cpp
    llama.cpp/tools/mtmd/models/deepseekocr.cpp
    llama.cpp/tools/mtmd/models/mobilenetv5.cpp
    llama.cpp/tools/mtmd/models/youtuvl.cpp
    llama.cpp/tools/mtmd/models/yasa2.cpp
)

add_library(mtmd STATIC ${MTMD_SOURCES})

target_link_libraries(mtmd PUBLIC ggml llama)
target_include_directories(mtmd PUBLIC
    llama.cpp/tools/mtmd
    llama.cpp/tools
    llama.cpp/vendor
)
target_compile_features(mtmd PRIVATE cxx_std_17)

if(ANDROID)
    target_compile_options(mtmd PRIVATE -Wno-missing-prototypes -Wno-cast-qual)
endif()

# Our native bridge
add_library(
    smolvlm_native
    SHARED
    smolvlm_jni.cpp
)

# Link all needed libraries
target_link_libraries(
    smolvlm_native
    llama
    llama-common
    mtmd
    android
    log
)

# Include directories
target_include_directories(smolvlm_native PRIVATE
    llama.cpp/include
    llama.cpp/common
    llama.cpp/ggml/include
    llama.cpp/tools/mtmd
    llama.cpp/vendor
)
