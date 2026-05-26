package com.example.cad_view

object CadNative {
    init {
        System.loadLibrary("cad_native")
    }

    external fun convertDwgToDxf(inputPath: String, outputPath: String): String
}