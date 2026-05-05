cmake_minimum_required(VERSION 3.10.2)
project("smolvlm")

# Ustawienia C++
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Ścieżka do llama.cpp (zakładamy że jest skopiowany do cpp/llama.cpp)
set(LLAMA_CPP_DIR "${CMAKE_SOURCE_DIR}/llama.cpp")

# Dodaj źródła llama.cpp
add_library(
    llama
    SHARED
    ${LLAMA_CPP_DIR}/ggml.c
    ${LLAMA_CPP_DIR}/ggml-alloc.c
    ${LLAMA_CPP_DIR}/ggml-backend.c
    ${LLAMA_CPP_DIR}/ggml-quants.c
    ${LLAMA_CPP_DIR}/llama.cpp
    ${LLAMA_CPP_DIR}/common/common.cpp
    ${LLAMA_CPP_DIR}/common/sampling.cpp
    ${LLAMA_CPP_DIR}/common/grammar-parser.cpp
    ${LLAMA_CPP_DIR}/common/json-schema-to-grammar.cpp
    ${LLAMA_CPP_DIR}/common/build-info.cpp
    ${LLAMA_CPP_DIR}/common/train.cpp
    ${LLAMA_CPP_DIR}/common/ngram-cache.cpp
)

# Natywny bridge
add_library(
    smolvlm_native
    SHARED
    smolvlm_jni.cpp
)

# Linkowanie
target_link_libraries(
    smolvlm_native
    llama
    android
    log
)

# Include directories
target_include_directories(llama PRIVATE ${LLAMA_CPP_DIR})
target_include_directories(smolvlm_native PRIVATE ${LLAMA_CPP_DIR} ${LLAMA_CPP_DIR}/common)
