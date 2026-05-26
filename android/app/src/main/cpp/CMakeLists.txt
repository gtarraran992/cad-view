cmake_minimum_required(VERSION 3.22.1)
project(cad_view)

file(GLOB_RECURSE LIBDXFRW_SOURCES
        "${CMAKE_SOURCE_DIR}/libdxfrw/src/*.cpp"
)

add_library(
        cad_native
        SHARED
        cad_native.cpp
        ${LIBDXFRW_SOURCES}
        ${CMAKE_SOURCE_DIR}/libdxfrw/dwg2dxf/dx_iface.cpp
)

target_include_directories(cad_native PRIVATE
        ${CMAKE_SOURCE_DIR}/libdxfrw/src
        ${CMAKE_SOURCE_DIR}/libdxfrw/dwg2dxf
)

target_link_libraries(cad_native
        android
        log
)