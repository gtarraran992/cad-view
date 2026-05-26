package com.example.cad_view

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.cad_view/cad_native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "convertDwgToDxf" -> {
                    val inputPath = call.argument<String>("inputPath")!!
                    val outputPath = call.argument<String>("outputPath")!!
                    val response = CadNative.convertDwgToDxf(inputPath, outputPath)
                    result.success(response)
                }
                else -> result.notImplemented()
            }
        }
    }
}