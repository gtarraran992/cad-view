import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'cad_native.dart';

class ViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const ViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  String _status = 'Conversione in corso...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _convertFile();
  }

  Future<void> _convertFile() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/output.dxf';

      final result = await CadNative.convertDwgToDxf(widget.filePath, outputPath);

      setState(() {
        _status = result == 'OK' ? 'Conversione completata!' : 'Errore: $result';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Errore: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        title: Text(widget.fileName, style: const TextStyle(fontSize: 15)),
      ),
      body: Center(
        child: _loading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1565C0)),
                  SizedBox(height: 16),
                  Text('Conversione in corso...',
                      style: TextStyle(color: Colors.white54)),
                ],
              )
            : Text(_status, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}