import 'package:flutter/services.dart';

class CadNative {
  CadNative._();

  static const _channel = MethodChannel('com.example.cad_view/cad_native');

  /// Converte DWG → DXF. Lancia Exception se fallisce.
  static Future<bool> convertDwgToDxf(String dwgPath, String dxfPath) async {
    try {
      final response = await _channel.invokeMethod<String>(
        'convertDwgToDxf',
        {'inputPath': dwgPath, 'outputPath': dxfPath},
      );
      if (response == 'OK') return true;
      final msg = switch (response) {
        'ERROR_FILE_NOT_FOUND' => 'File DWG non trovato: $dwgPath',
        'ERROR_READ'           => 'Impossibile leggere il DWG',
        'ERROR_WRITE'          => 'Impossibile scrivere il DXF',
        _                      => 'Errore: $response',
      };
      throw Exception(msg);
    } on PlatformException catch (e) {
      throw Exception('CadNative [${e.code}]: ${e.message}');
    }
  }

  /// Parsa DXF in C++ e scrive il JSON su [jsonPath].
  /// Evita il limite di dimensione delle stringhe JNI.
  /// Lancia Exception se fallisce.
  static Future<void> parseDxfToFile(String dxfPath, String jsonPath) async {
    try {
      final response = await _channel.invokeMethod<String>(
        'parseDxfToFile',
        {'dxfPath': dxfPath, 'jsonPath': jsonPath},
      );
      if (response == 'OK') return;
      final msg = switch (response) {
        'ERROR_READ'         => 'Impossibile leggere il DXF: $dxfPath',
        'ERROR_OPEN_OUTPUT'  => 'Impossibile scrivere JSON: $jsonPath',
        _                    => 'Errore parseDxf: $response',
      };
      throw Exception(msg);
    } on PlatformException catch (e) {
      throw Exception('CadNative parseDxf [${e.code}]: ${e.message}');
    }
  }
}
