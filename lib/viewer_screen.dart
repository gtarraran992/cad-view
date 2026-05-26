import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'cad_native.dart';
import 'package:dxf/dxf.dart';

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
  List<AcDbEntity> _entities = [];

  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset _lastFocalPoint = Offset.zero;
  double _lastScale = 1.0;

  @override
  void initState() {
    super.initState();
    _convertAndParse();
  }

  Future<void> _convertAndParse() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/output.dxf';

      final result = await CadNative.convertDwgToDxf(widget.filePath, outputPath);

      if (result != 'OK') {
        setState(() {
          _status = 'Errore: $result';
          _loading = false;
        });
        return;
      }

      final dxfContent = await File(outputPath).readAsString();
      final dxf = DXF.fromString(dxfContent);

      setState(() {
        _entities = dxf.entities;
        _status = 'OK';
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
        actions: [
          if (!_loading && _status == 'OK')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${_entities.length} entità',
                style: const TextStyle(color: Color(0xFF7B8BB2), fontSize: 12),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1565C0)),
                  SizedBox(height: 16),
                  Text('Caricamento...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : _status != 'OK'
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _status,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : GestureDetector(
                  onScaleStart: (details) {
                    _lastFocalPoint = details.focalPoint;
                    _lastScale = _scale;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      _scale = (_lastScale * details.scale).clamp(0.01, 100.0);
                      _offset += details.focalPoint - _lastFocalPoint;
                      _lastFocalPoint = details.focalPoint;
                    });
                  },
                  child: CustomPaint(
                    painter: DxfPainter(
                      entities: _entities,
                      scale: _scale,
                      offset: _offset,
                    ),
                    size: Size.infinite,
                  ),
                ),
    );
  }
}

class DxfPainter extends CustomPainter {
  final List<AcDbEntity> entities;
  final double scale;
  final Offset offset;

  DxfPainter({
    required this.entities,
    required this.scale,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0 / scale
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(offset.dx + size.width / 2, offset.dy + size.height / 2);
    canvas.scale(scale, -scale);

    for (final entity in entities) {
      if (entity is AcDbLine) {
        canvas.drawLine(
          Offset(entity.x, entity.y),
          Offset(entity.x1, entity.y1),
          paint,
        );
      } else if (entity is AcDbPolyline) {
        if (entity.vertices.length < 2) continue;
        final path = Path();
        path.moveTo(entity.vertices[0][0], entity.vertices[0][1]);
        for (var i = 1; i < entity.vertices.length; i++) {
          path.lineTo(entity.vertices[i][0], entity.vertices[i][1]);
        }
        if (entity.isClosed) path.close();
        canvas.drawPath(path, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(DxfPainter oldDelegate) =>
      oldDelegate.scale != scale || oldDelegate.offset != offset;
}