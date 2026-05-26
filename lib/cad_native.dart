import 'package:flutter/services.dart';

class CadNative {
  static const _channel = MethodChannel('com.example.cad_view/cad_native');

  static Future<String> convertDwgToDxf(String inputPath, String outputPath) async {
    final result = await _channel.invokeMethod<String>('convertDwgToDxf', {
      'inputPath': inputPath,
      'outputPath': outputPath,
    });
    return result ?? 'ERROR';
  }
}