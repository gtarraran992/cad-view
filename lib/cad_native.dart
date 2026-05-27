import 'package:flutter/services.dart';

/// Bridge Dart ↔ Kotlin/JNI per operazioni native CAD.
class CadNative {
  CadNative._();

  static const _channel = MethodChannel('com.example.cad_view/cad_native');

  /// Converte [dwgPath] in DXF salvato in [dxfPath].
  /// Lancia [Exception] con il codice di errore se la conversione fallisce.
  static Future<bool> convertDwgToDxf(
    String dwgPath,
    String dxfPath,
  ) async {
    try {
      // Il C++ ritorna una String: "OK" | "ERROR_FILE_NOT_FOUND" | "ERROR_READ" | "ERROR_WRITE"
      final response = await _channel.invokeMethod<String>(
        'convertDwgToDxf',
        {
          'inputPath': dwgPath,
          'outputPath': dxfPath,
        },
      );

      if (response == 'OK') return true;

      // Mappa i codici di errore C++ in messaggi leggibili
      final msg = switch (response) {
        'ERROR_FILE_NOT_FOUND' => 'File DWG non trovato: $dwgPath',
        'ERROR_READ'           => 'Impossibile leggere il file DWG (formato non supportato?)',
        'ERROR_WRITE'          => 'Impossibile scrivere il file DXF: $dxfPath',
        _                      => 'Errore sconosciuto: $response',
      };
      throw Exception(msg);
    } on PlatformException catch (e) {
      throw Exception('CadNative error [${e.code}]: ${e.message}');
    }
  }
}
