import 'dart:io';
import 'dart:math' as math;

import 'package:dxf/dxf.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'cad_native.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Layer color mapping (AutoCAD standard ACI index → Color)
// ─────────────────────────────────────────────────────────────────────────────

// Layer → color palette (cycles through these)
const _layerPalette = [
  Color(0xFF00E5FF), // cyan
  Color(0xFFFF4081), // pink
  Color(0xFF69F0AE), // green
  Color(0xFFFFD740), // amber
  Color(0xFFE040FB), // purple
  Color(0xFF40C4FF), // light blue
  Color(0xFFFF6E40), // deep orange
  Color(0xFFB2FF59), // lime
];

class _LayerStyle {
  const _LayerStyle(this.color, this.visible);
  final Color color;
  final bool visible;
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _Line {
  const _Line(this.x1, this.y1, this.x2, this.y2, this.layer);
  final double x1, y1, x2, y2;
  final String layer;
}

class _Polyline {
  const _Polyline(this.vertices, this.layer, {this.closed = false});
  final List<Offset> vertices;
  final String layer;
  final bool closed;
}

class _Circle {
  const _Circle(this.cx, this.cy, this.r, this.layer);
  final double cx, cy, r;
  final String layer;
}

class _Arc {
  const _Arc(this.cx, this.cy, this.r, this.startDeg, this.endDeg, this.layer);
  final double cx, cy, r, startDeg, endDeg;
  final String layer;
}

class _DxfData {
  const _DxfData({
    required this.lines,
    required this.polylines,
    required this.circles,
    required this.arcs,
    required this.bounds,
    required this.layers,
  });
  final List<_Line> lines;
  final List<_Polyline> polylines;
  final List<_Circle> circles;
  final List<_Arc> arcs;
  final Rect bounds;
  final Set<String> layers;
}

// ─────────────────────────────────────────────────────────────────────────────
// Measurement
// ─────────────────────────────────────────────────────────────────────────────

class _MeasureResult {
  const _MeasureResult({
    required this.p1,
    required this.p2,
    required this.distance,
    required this.deltaX,
    required this.deltaY,
    required this.angleDeg,
  });
  final Offset p1, p2;
  final double distance, deltaX, deltaY, angleDeg;

  static _MeasureResult from(Offset p1, Offset p2) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    var angle = math.atan2(-dy, dx) * 180.0 / math.pi;
    if (angle < 0) angle += 360.0;
    return _MeasureResult(
      p1: p1, p2: p2,
      distance: dist,
      deltaX: dx.abs(),
      deltaY: dy.abs(),
      angleDeg: angle,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.filePath});
  final String filePath;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  _DxfData? _data;
  String? _error;
  bool _loading = true;

  // viewport
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _focalStart = Offset.zero;

  // layers visibility
  final Map<String, _LayerStyle> _layerStyles = {};

  // measure
  bool _measureMode = false;
  Offset? _measureP1;
  Offset? _measureP2;
  _MeasureResult? _measureResult;

  // panels
  bool _showLayers = false;

  // ── init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _convertAndParse();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  // ── parse ─────────────────────────────────────────────────────────────────

  Future<void> _convertAndParse() async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final dxfPath = '${tmpDir.path}/output.dxf';

      final ext = widget.filePath.split('.').last.toLowerCase();
      if (ext == 'dwg') {
        final ok = await CadNative.convertDwgToDxf(widget.filePath, dxfPath);
        if (!ok) throw Exception('Conversione DWG fallita');
      } else {
        await File(widget.filePath).copy(dxfPath);
      }

      final dxfContent = await File(dxfPath).readAsString();
      final dxf = DXF.fromString(dxfContent);

      final lines = <_Line>[];
      final polylines = <_Polyline>[];
      final circles = <_Circle>[];
      final arcs = <_Arc>[];
      final layerSet = <String>{};

      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

      void expand(double x, double y) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }

      for (final e in dxf.entities) {
        // dxf 3.x: AcDbEntity espone "layerName", non "layer"
        final layer = (e as dynamic).layerName as String? ?? '0';
        layerSet.add(layer);

        if (e is AcDbLine) {
          lines.add(_Line(e.x, e.y, e.x1, e.y1, layer));
          expand(e.x, e.y);
          expand(e.x1, e.y1);
        } else if (e is AcDbPolyline) {
          final verts = <Offset>[];
          for (final v in e.vertices) {
            final x = (v[0] as num).toDouble();
            final y = (v[1] as num).toDouble();
            verts.add(Offset(x, y));
            expand(x, y);
          }
          if (verts.length >= 2) {
            polylines.add(_Polyline(verts, layer, closed: e.isClosed));
          }
        } else if (e is AcDbCircle) {
          // dxf 3.x: campo "radius" (non "r")
          circles.add(_Circle(e.x, e.y, e.radius, layer));
          expand(e.x - e.radius, e.y - e.radius);
          expand(e.x + e.radius, e.y + e.radius);
        } else if (e is AcDbArc) {
          // dxf 3.x: campo "radius" (non "r")
          arcs.add(_Arc(e.x, e.y, e.radius, e.startAngle, e.endAngle, layer));
          expand(e.x - e.radius, e.y - e.radius);
          expand(e.x + e.radius, e.y + e.radius);
        }
      }

      if (minX == double.infinity) {
        throw Exception('Nessuna entità geometrica trovata nel file DXF');
      }

      // Add 2% padding to bounds
      final w = maxX - minX;
      final h = maxY - minY;
      final pad = math.max(w, h) * 0.02;
      final bounds = Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);

      // Build layer styles
      final styles = <String, _LayerStyle>{};
      var idx = 0;
      for (final name in layerSet) {
        final color = _layerPalette[idx % _layerPalette.length];
        styles[name] = _LayerStyle(color, true);
        idx++;
      }

      setState(() {
        _data = _DxfData(
          lines: lines,
          polylines: polylines,
          circles: circles,
          arcs: arcs,
          bounds: bounds,
          layers: layerSet,
        );
        _layerStyles.addAll(styles);
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── fit to screen ─────────────────────────────────────────────────────────

  void _fitToScreen() {
    if (_data == null || !mounted) return;
    final size = MediaQuery.of(context).size;
    final bounds = _data!.bounds;
    const padding = 40.0;
    final availW = size.width - padding * 2;
    final availH = size.height - padding * 2 - kToolbarHeight;

    final scaleX = availW / bounds.width.clamp(1.0, double.infinity);
    final scaleY = availH / bounds.height.clamp(1.0, double.infinity);
    final scale = math.min(scaleX, scaleY);

    final cx = (bounds.left + bounds.right) / 2;
    final cy = (bounds.top + bounds.bottom) / 2;

    setState(() {
      _scale = scale;
      _offset = Offset(
        size.width / 2 - cx * scale,
        size.height / 2 + cy * scale,
      );
    });
  }

  // ── coordinate transforms ─────────────────────────────────────────────────

  Offset _screenToWorld(Offset s) => Offset(
        (s.dx - _offset.dx) / _scale,
        -((s.dy - _offset.dy) / _scale),
      );

  // ── gestures ──────────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _scale;
    _baseOffset = _offset;
    _focalStart = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _scale = (_baseScale * d.scale).clamp(0.001, 100000.0);
      _offset = _baseOffset +
          (d.focalPoint - _focalStart) +
          (_focalStart - _baseOffset) * (1 - d.scale);
    });
  }

  void _onTapDown(TapDownDetails d) {
    if (!_measureMode) return;
    final world = _screenToWorld(d.localPosition);
    setState(() {
      if (_measureP1 == null || _measureResult != null) {
        _measureP1 = world;
        _measureP2 = null;
        _measureResult = null;
      } else {
        _measureP2 = world;
        _measureResult = _MeasureResult.from(_measureP1!, world);
      }
    });
  }

  void _clearMeasure() => setState(() {
        _measureP1 = null;
        _measureP2 = null;
        _measureResult = null;
      });

  // ── layer color ───────────────────────────────────────────────────────────

  Color _layerColor(String layer) =>
      _layerStyles[layer]?.color ?? _layerPalette[0];

  bool _layerVisible(String layer) =>
      _layerStyles[layer]?.visible ?? true;

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad    = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      // Use transparent AppBar so we control the safe area manually
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF12122A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.filePath.split('/').last,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Layer panel toggle
          if (_data != null)
            IconButton(
              icon: Icon(Icons.layers,
                  color: _showLayers ? Colors.amber : Colors.white54),
              tooltip: 'Layer',
              onPressed: () => setState(() => _showLayers = !_showLayers),
            ),
          // Measure toggle
          IconButton(
            icon: Icon(Icons.straighten,
                color: _measureMode ? Colors.amber : Colors.white54),
            tooltip: _measureMode ? 'Esci misura' : 'Misura',
            onPressed: () => setState(() {
              _measureMode = !_measureMode;
              if (!_measureMode) _clearMeasure();
            }),
          ),
          // Fit
          IconButton(
            icon: const Icon(Icons.fit_screen, color: Colors.white54),
            tooltip: 'Adatta',
            onPressed: _fitToScreen,
          ),
        ],
      ),
      body: _loading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(message: _error!)
              : Stack(
                  children: [
                    // ── canvas ──────────────────────────────────────────
                    GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onTapDown: _measureMode ? _onTapDown : null,
                      child: CustomPaint(
                        painter: _DxfPainter(
                          data: _data!,
                          scale: _scale,
                          offset: _offset,
                          layerColor: _layerColor,
                          layerVisible: _layerVisible,
                          measureP1: _measureP1,
                          measureP2: _measureP2,
                          measureMode: _measureMode,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),

                    // ── measure hint ────────────────────────────────────
                    if (_measureMode && _measureResult == null)
                      Positioned(
                        top: 12,
                        left: 0, right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.amber.withOpacity(0.5)),
                            ),
                            child: Text(
                              _measureP1 == null
                                  ? '📍 Tocca il primo punto'
                                  : '📍 Tocca il secondo punto',
                              style: const TextStyle(
                                  color: Colors.amber, fontSize: 13),
                            ),
                          ),
                        ),
                      ),

                    // ── layer panel ─────────────────────────────────────
                    if (_showLayers && _data != null)
                      Positioned(
                        top: 8, right: 8,
                        child: _LayerPanel(
                          layers: _data!.layers.toList()..sort(),
                          styles: _layerStyles,
                          onToggle: (layer) => setState(() {
                            final s = _layerStyles[layer]!;
                            _layerStyles[layer] =
                                _LayerStyle(s.color, !s.visible);
                          }),
                        ),
                      ),

                    // ── measure result panel ────────────────────────────
                    if (_measureResult != null)
                      Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: _MeasurePanel(
                          result: _measureResult!,
                          onClear: _clearMeasure,
                          bottomPad: bottomPad,
                        ),
                      ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

class _DxfPainter extends CustomPainter {
  _DxfPainter({
    required this.data,
    required this.scale,
    required this.offset,
    required this.layerColor,
    required this.layerVisible,
    this.measureP1,
    this.measureP2,
    this.measureMode = false,
  });

  final _DxfData data;
  final double scale;
  final Offset offset;
  final Color Function(String) layerColor;
  final bool Function(String) layerVisible;
  final Offset? measureP1;
  final Offset? measureP2;
  final bool measureMode;

  Offset _w2s(double wx, double wy) =>
      Offset(wx * scale + offset.dx, -wy * scale + offset.dy);
  Offset _w2sO(Offset w) => _w2s(w.dx, w.dy);

  Paint _paint(String layer) => Paint()
    ..color = layerColor(layer)
    ..strokeWidth = (1.4 / scale).clamp(0.4, 4.0)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0A14),
    );

    // Lines
    for (final l in data.lines) {
      if (!layerVisible(l.layer)) continue;
      canvas.drawLine(_w2s(l.x1, l.y1), _w2s(l.x2, l.y2), _paint(l.layer));
    }

    // Polylines
    for (final poly in data.polylines) {
      if (!layerVisible(poly.layer)) continue;
      if (poly.vertices.isEmpty) continue;
      final path = Path();
      final first = _w2sO(poly.vertices.first);
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < poly.vertices.length; i++) {
        final p = _w2sO(poly.vertices[i]);
        path.lineTo(p.dx, p.dy);
      }
      if (poly.closed) path.close();
      canvas.drawPath(path, _paint(poly.layer));
    }

    // Circles
    for (final c in data.circles) {
      if (!layerVisible(c.layer)) continue;
      final center = _w2s(c.cx, c.cy);
      final radius = c.r * scale;
      canvas.drawCircle(center, radius, _paint(c.layer));
    }

    // Arcs
    for (final a in data.arcs) {
      if (!layerVisible(a.layer)) continue;
      final center = _w2s(a.cx, a.cy);
      final radius = a.r * scale;
      final rect = Rect.fromCircle(center: center, radius: radius);
      // DXF angles are CCW from X; Flutter drawArc is CW from 3 o'clock
      final startRad = -a.startDeg * math.pi / 180.0;
      var sweepDeg = a.endDeg - a.startDeg;
      if (sweepDeg <= 0) sweepDeg += 360;
      final sweepRad = -sweepDeg * math.pi / 180.0;
      canvas.drawArc(rect, startRad, sweepRad, false, _paint(a.layer));
    }

    // Measure overlay
    if (measureMode) _drawMeasure(canvas);
  }

  void _drawMeasure(Canvas canvas) {
    if (measureP1 == null) return;
    final s1 = _w2sO(measureP1!);

    // Point 1 dot
    canvas.drawCircle(s1, 7, Paint()..color = Colors.amber);
    canvas.drawCircle(
        s1, 7, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5);

    if (measureP2 == null) return;
    final s2 = _w2sO(measureP2!);

    // Point 2 dot
    canvas.drawCircle(s2, 7, Paint()..color = Colors.amber);
    canvas.drawCircle(
        s2, 7, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Main line
    canvas.drawLine(s1, s2,
        Paint()
          ..color = Colors.amber
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke);

    // Delta X guide (red, horizontal)
    final corner = Offset(s2.dx, s1.dy);
    canvas.drawLine(s1, corner,
        Paint()
          ..color = Colors.redAccent.withOpacity(0.7)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);

    // Delta Y guide (green, vertical)
    canvas.drawLine(corner, s2,
        Paint()
          ..color = Colors.greenAccent.withOpacity(0.7)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_DxfPainter old) =>
      old.scale != scale ||
      old.offset != offset ||
      old.measureP1 != measureP1 ||
      old.measureP2 != measureP2 ||
      old.measureMode != measureMode;
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer Panel
// ─────────────────────────────────────────────────────────────────────────────

class _LayerPanel extends StatelessWidget {
  const _LayerPanel({
    required this.layers,
    required this.styles,
    required this.onToggle,
  });
  final List<String> layers;
  final Map<String, _LayerStyle> styles;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: const Color(0xE6121228),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(Icons.layers, size: 14, color: Colors.white54),
                SizedBox(width: 6),
                Text('Layer',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: layers.length,
              itemBuilder: (_, i) {
                final name = layers[i];
                final style = styles[name]!;
                return InkWell(
                  onTap: () => onToggle(name),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            color: style.visible
                                ? style.color
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: style.color, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: style.visible
                                  ? Colors.white
                                  : Colors.white30,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!style.visible)
                          const Icon(Icons.visibility_off,
                              size: 12, color: Colors.white24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Measure Panel — respects navigation bar insets
// ─────────────────────────────────────────────────────────────────────────────

class _MeasurePanel extends StatelessWidget {
  const _MeasurePanel({
    required this.result,
    required this.onClear,
    required this.bottomPad,
  });
  final _MeasureResult result;
  final VoidCallback onClear;
  final double bottomPad;

  String _fmt(double v) {
    if (v.abs() >= 10000) return v.toStringAsFixed(0);
    if (v.abs() >= 100)   return v.toStringAsFixed(1);
    if (v.abs() >= 1)     return v.toStringAsFixed(3);
    return v.toStringAsExponential(2);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12122A),
        border: Border(top: BorderSide(color: Colors.amber, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.straighten, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              const Text('Misura',
                  style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5)),
              const Spacer(),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    color: Colors.white38, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 4 metrics
          Row(
            children: [
              _Tile('Distanza', _fmt(result.distance), Colors.white),
              _Tile('Delta X',  _fmt(result.deltaX),   Colors.redAccent),
              _Tile('Delta Y',  _fmt(result.deltaY),   Colors.greenAccent),
              _Tile('Angolo',
                  '${result.angleDeg.toStringAsFixed(2)}°',
                  Colors.cyanAccent),
            ],
          ),
          const SizedBox(height: 8),
          // Coordinates
          Text(
            'P1 (${_fmt(result.p1.dx)}, ${_fmt(result.p1.dy)})   '
            'P2 (${_fmt(result.p2.dx)}, ${_fmt(result.p2.dy)})',
            style: const TextStyle(color: Colors.white30, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / Error
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text('Caricamento…',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Errore:\n$message',
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
}