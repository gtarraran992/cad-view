cmake_minimum_required(VERSION 3.18.1)
project(cad_view)

# Sorgenti libdxfrw
file(GLOB_RECURSE LIBDXFRW_SOURCES
    "${CMAKE_SOURCE_DIR}/libdxfrw/src/*.cpp"
)

# Libreria nativa
add_library(
    cad_native
    SHARED
    cad_native.cpp
    ${LIBDXFRW_SOURCES}
)

target_include_directories(cad_native PRIVATE
    ${CMAKE_SOURCE_DIR}/libdxfrw/src
)

target_link_libraries(cad_native
    android
    log
)