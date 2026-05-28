package com.example.cad_view

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.cad_view/cad_native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "convertDwgToDxf" -> {
                        val inputPath  = call.argument<String>("inputPath")!!
                        val outputPath = call.argument<String>("outputPath")!!
                        result.success(CadNative.convertDwgToDxf(inputPath, outputPath))
                    }

                    "parseDxfToFile" -> {
                        val dxfPath  = call.argument<String>("dxfPath")!!
                        val jsonPath = call.argument<String>("jsonPath")!!
                        result.success(CadNative.parseDxfToFile(dxfPath, jsonPath))
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
