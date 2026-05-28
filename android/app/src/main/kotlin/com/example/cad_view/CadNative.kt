package com.example.cad_view

object CadNative {
    init {
        System.loadLibrary("cad_native")
    }

    /** Converte DWG → DXF. Ritorna "OK" o "ERROR_..." */
    external fun convertDwgToDxf(inputPath: String, outputPath: String): String

    /** Parsa DXF e scrive il JSON su jsonPath.
     *  Ritorna "OK" o "ERROR_..." */
    external fun parseDxfToFile(dxfPath: String, jsonPath: String): String
}
