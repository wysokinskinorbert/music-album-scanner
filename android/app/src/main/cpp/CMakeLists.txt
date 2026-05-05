cmake_minimum_required(VERSION 3.22.1)
project("smolvlm")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Only build for arm64-v8a and x86_64 (skip armeabi-v7a which has FP16 issues)
if(ANDROID_ABI STREQUAL "armeabi-v7a")
    message(STATUS "Skipping armeabi-v7a - not supported")
    return()
endif()

# llama.cpp options - disable unnecessary stuff
set(LLAMA_BUILD_COMMON ON)
set(LLAMA_BUILD_EXAMPLES OFF)
set(LLAMA_BUILD_TESTS OFF)
set(LLAMA_BUILD_TOOLS OFF)
set(LLAMA_BUILD_SERVER OFF)
set(LLAMA_BUILD_CLI OFF)
set(BUILD_SHARED_LIBS OFF)

# Add llama.cpp
add_subdirectory(llama.cpp)

# Native bridge
add_library(
    smolvlm_native
    SHARED
    smolvlm_jni.cpp
)

# Link to llama libraries
target_link_libraries(
    smolvlm_native
    llama
    llama-common
    android
    log
)

# Include directories
target_include_directories(smolvlm_native PRIVATE
    llama.cpp/include
    llama.cpp/common
    llama.cpp/ggml/include
)
