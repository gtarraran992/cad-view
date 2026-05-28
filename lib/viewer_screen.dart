import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'cad_native.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _Line {
  const _Line(this.x1, this.y1, this.x2, this.y2, this.color, this.layer);
  final double x1, y1, x2, y2;
  final Color  color;
  final String layer;
}

class _Poly {
  const _Poly(this.pts, this.closed, this.color, this.layer);
  final List<Offset> pts;
  final bool   closed;
  final Color  color;
  final String layer;
}

class _Circle {
  const _Circle(this.cx, this.cy, this.r, this.color, this.layer);
  final double cx, cy, r;
  final Color  color;
  final String layer;
}

class _Arc {
  const _Arc(this.cx, this.cy, this.r, this.sa, this.ea, this.color, this.layer);
  final double cx, cy, r, sa, ea;
  final Color  color;
  final String layer;
}

class _LayerInfo {
  _LayerInfo(this.color, this.visible);
  final Color color;
  bool  visible;
}

class _DxfData {
  const _DxfData(this.lines, this.polys, this.circles, this.arcs,
      this.bounds, this.layers);
  final List<_Line>             lines;
  final List<_Poly>             polys;
  final List<_Circle>           circles;
  final List<_Arc>              arcs;
  final Rect                    bounds;
  final Map<String, _LayerInfo> layers;
}

// ─────────────────────────────────────────────────────────────────────────────
// JSON → _DxfData
// Formato: {"layers":{"name":{"color":"#RRGGBB"},...}, "entities":[...]}
// ─────────────────────────────────────────────────────────────────────────────

Color _hexColor(String? hex) {
  if (hex == null || hex.length < 7) return Colors.white;
  try {
    return Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
  } catch (_) {
    return Colors.white;
  }
}

_DxfData _parseJson(String jsonStr) {
  final root     = jsonDecode(jsonStr) as Map<String, dynamic>;
  final layerMap = root['layers'] as Map<String, dynamic>? ?? {};
  final entList  = root['entities'] as List<dynamic>? ?? [];

  // Build layer info
  final layers = <String, _LayerInfo>{};
  for (final entry in layerMap.entries) {
    final info  = entry.value as Map<String, dynamic>;
    final color = _hexColor(info['color'] as String?);
    layers[entry.key] = _LayerInfo(color, true);
  }

  final lines   = <_Line>[];
  final polys   = <_Poly>[];
  final circles = <_Circle>[];
  final arcs    = <_Arc>[];

  double minX = double.infinity,    minY = double.infinity;
  double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

  void expand(double x, double y) {
    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
  }

  for (final e in entList) {
    final m     = e as Map<String, dynamic>;
    final t     = m['t'] as String;
    final layer = m['l'] as String? ?? '0';
    final color = _hexColor(m['c'] as String?);

    // Ensure layer appears in map (fallback white if not in table)
    layers.putIfAbsent(layer, () => _LayerInfo(Colors.white, true));

    switch (t) {
      case 'L':
        final x1 = (m['x1'] as num).toDouble();
        final y1 = (m['y1'] as num).toDouble();
        final x2 = (m['x2'] as num).toDouble();
        final y2 = (m['y2'] as num).toDouble();
        lines.add(_Line(x1, y1, x2, y2, color, layer));
        expand(x1, y1); expand(x2, y2);

      case 'P':
        final raw    = m['p'] as List<dynamic>;
        final closed = (m['cl'] as num?)?.toInt() == 1;
        final pts    = <Offset>[];
        for (final v in raw) {
          final p = v as List<dynamic>;
          final x = (p[0] as num).toDouble();
          final y = (p[1] as num).toDouble();
          pts.add(Offset(x, y));
          expand(x, y);
        }
        if (pts.length >= 2) polys.add(_Poly(pts, closed, color, layer));

      case 'C':
        final cx = (m['cx'] as num).toDouble();
        final cy = (m['cy'] as num).toDouble();
        final r  = (m['r']  as num).toDouble();
        circles.add(_Circle(cx, cy, r, color, layer));
        expand(cx - r, cy - r); expand(cx + r, cy + r);

      case 'A':
        final cx = (m['cx'] as num).toDouble();
        final cy = (m['cy'] as num).toDouble();
        final r  = (m['r']  as num).toDouble();
        final sa = (m['sa'] as num).toDouble();
        final ea = (m['ea'] as num).toDouble();
        arcs.add(_Arc(cx, cy, r, sa, ea, color, layer));
        expand(cx - r, cy - r); expand(cx + r, cy + r);
    }
  }

  if (minX == double.infinity) {
    return _DxfData([], [], [], [], Rect.zero, layers);
  }

  final w   = maxX - minX;
  final h   = maxY - minY;
  final pad = math.max(w, h) * 0.02;
  final bounds = Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  return _DxfData(lines, polys, circles, arcs, bounds, layers);
}

// ─────────────────────────────────────────────────────────────────────────────
// Measurement
// ─────────────────────────────────────────────────────────────────────────────

class _MeasureResult {
  const _MeasureResult({required this.p1, required this.p2,
      required this.distance, required this.deltaX,
      required this.deltaY, required this.angleDeg});
  final Offset p1, p2;
  final double distance, deltaX, deltaY, angleDeg;

  static _MeasureResult from(Offset p1, Offset p2) {
    final dx   = p2.dx - p1.dx;
    final dy   = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    var   ang  = math.atan2(-dy, dx) * 180.0 / math.pi;
    if (ang < 0) ang += 360.0;
    return _MeasureResult(p1: p1, p2: p2, distance: dist,
        deltaX: dx.abs(), deltaY: dy.abs(), angleDeg: ang);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Snap engine
// ─────────────────────────────────────────────────────────────────────────────

/// Intersezione segmento A-B con segmento C-D in coordinate world.
/// Restituisce null se i segmenti non si intersecano (o sono paralleli).
Offset? _segIntersect(Offset a, Offset b, Offset c, Offset d) {
  final dx1 = b.dx - a.dx, dy1 = b.dy - a.dy;
  final dx2 = d.dx - c.dx, dy2 = d.dy - c.dy;
  final denom = dx1 * dy2 - dy1 * dx2;
  if (denom.abs() < 1e-10) return null; // paralleli
  final dx3 = c.dx - a.dx, dy3 = c.dy - a.dy;
  final t = (dx3 * dy2 - dy3 * dx2) / denom;
  final u = (dx3 * dy1 - dy3 * dx1) / denom;
  if (t < 0 || t > 1 || u < 0 || u > 1) return null; // fuori dai segmenti
  return Offset(a.dx + t * dx1, a.dy + t * dy1);
}

/// Trova il punto snap più vicino al tap (in coordinate world).
/// Considera: endpoint di linee + intersezioni linea-linea.
/// [snapPx] è la soglia in pixel dello schermo.
Offset _snap(Offset worldTap, _DxfData data, double scale, double snapPx) {
  final snapWorld = snapPx / scale; // soglia in unità world
  Offset best     = worldTap;
  double bestDist = snapWorld;

  // Raccoglie tutti i segmenti visibili come coppie di Offset world
  final segs = <(Offset, Offset)>[];

  for (final l in data.lines) {
    if (!(data.layers[l.layer]?.visible ?? true)) continue;
    final a = Offset(l.x1, l.y1);
    final b = Offset(l.x2, l.y2);
    segs.add((a, b));
  }

  for (final p in data.polys) {
    if (!(data.layers[p.layer]?.visible ?? true)) continue;
    for (var i = 0; i < p.pts.length - 1; i++) {
      segs.add((p.pts[i], p.pts[i + 1]));
    }
    if (p.closed && p.pts.length > 2) {
      segs.add((p.pts.last, p.pts.first));
    }
  }

  // 1. Endpoint snap
  for (final s in segs) {
    for (final pt in [s.$1, s.$2]) {
      final d = (pt - worldTap).distance;
      if (d < bestDist) { bestDist = d; best = pt; }
    }
  }

  // 2. Intersezione snap (solo se nessun endpoint trovato vicino)
  // Per limitare il costo O(n²), consideriamo al massimo 300 segmenti
  final limit = segs.length > 300 ? 300 : segs.length;
  for (var i = 0; i < limit; i++) {
    for (var j = i + 1; j < limit; j++) {
      final pt = _segIntersect(segs[i].$1, segs[i].$2, segs[j].$1, segs[j].$2);
      if (pt == null) continue;
      final d = (pt - worldTap).distance;
      if (d < bestDist) { bestDist = d; best = pt; }
    }
  }

  return best;
}



class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.filePath});
  final String filePath;
  @override State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  _DxfData? _data;
  String?   _error;
  bool      _loading = true;

  double _scale = 1.0, _baseScale = 1.0;
  Offset _offset = Offset.zero, _baseOffset = Offset.zero, _focalStart = Offset.zero;

  bool _measureMode = false;
  Offset? _p1, _p2;
  _MeasureResult? _result;
  bool _showLayers = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _load();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final tmp     = await getTemporaryDirectory();
      final dxfPath  = '${tmp.path}/output.dxf';
      final jsonPath = '${tmp.path}/entities.json';

      final ext = widget.filePath.split('.').last.toLowerCase();
      if (ext == 'dwg') {
        await CadNative.convertDwgToDxf(widget.filePath, dxfPath);
      } else {
        await File(widget.filePath).copy(dxfPath);
      }

      await CadNative.parseDxfToFile(dxfPath, jsonPath);
      final json = await File(jsonPath).readAsString();
      final data = _parseJson(json);

      if (data.bounds == Rect.zero) throw Exception('Nessuna entità trovata');

      setState(() { _data = data; _loading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _fitToScreen() {
    if (_data == null || !mounted) return;
    final sz     = MediaQuery.of(context).size;
    final bounds = _data!.bounds;
    const pad    = 40.0;
    final sX = (sz.width  - pad * 2) / bounds.width.clamp(1.0, double.infinity);
    final sY = (sz.height - pad * 2 - kToolbarHeight) / bounds.height.clamp(1.0, double.infinity);
    final s  = math.min(sX, sY);
    final cx = (bounds.left + bounds.right)  / 2;
    final cy = (bounds.top  + bounds.bottom) / 2;
    setState(() {
      _scale  = s;
      _offset = Offset(sz.width / 2 - cx * s, sz.height / 2 + cy * s);
    });
  }

  Offset _s2w(Offset s) => Offset(
      (s.dx - _offset.dx) / _scale, -((s.dy - _offset.dy) / _scale));

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _scale; _baseOffset = _offset; _focalStart = d.focalPoint;
  }
  void _onScaleUpdate(ScaleUpdateDetails d) => setState(() {
    _scale  = (_baseScale * d.scale).clamp(0.001, 100000.0);
    _offset = _baseOffset + (d.focalPoint - _focalStart)
              + (_focalStart - _baseOffset) * (1 - d.scale);
  });
  void _onTap(TapDownDetails d) {
    if (!_measureMode) return;
    final raw      = _s2w(d.localPosition);
    // Snap a endpoint/intersezione entro 20px schermo
    final snapped  = _snap(raw, _data!, _scale, 20.0);
    setState(() {
      if (_p1 == null || _result != null) { _p1 = snapped; _p2 = null; _result = null; }
      else { _p2 = snapped; _result = _MeasureResult.from(_p1!, snapped); }
    });
  }
  void _clearMeasure() => setState(() { _p1 = _p2 = null; _result = null; });

  @override
  Widget build(BuildContext context) {
    final bp = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12122A),
        foregroundColor: Colors.white, elevation: 0,
        title: Text(widget.filePath.split('/').last,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
            overflow: TextOverflow.ellipsis),
        actions: [
          if (_data != null)
            IconButton(
              icon: Icon(Icons.layers,
                  color: _showLayers ? Colors.amber : Colors.white54),
              onPressed: () => setState(() => _showLayers = !_showLayers)),
          IconButton(
            icon: Icon(Icons.straighten,
                color: _measureMode ? Colors.amber : Colors.white54),
            onPressed: () => setState(() {
              _measureMode = !_measureMode;
              if (!_measureMode) _clearMeasure();
            })),
          IconButton(
            icon: const Icon(Icons.fit_screen, color: Colors.white54),
            onPressed: _fitToScreen),
        ]),
      body: _loading ? const _LoadingView()
          : _error  != null ? _ErrorView(msg: _error!)
          : Stack(children: [
              GestureDetector(
                onScaleStart: _onScaleStart, onScaleUpdate: _onScaleUpdate,
                onTapDown: _measureMode ? _onTap : null,
                child: CustomPaint(
                  painter: _Painter(data: _data!, scale: _scale, offset: _offset,
                      measureP1: _p1, measureP2: _p2, measureMode: _measureMode),
                  child: const SizedBox.expand())),
              if (_measureMode && _result == null)
                Positioned(top: 12, left: 0, right: 0,
                  child: Center(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withOpacity(0.5))),
                    child: Text(_p1 == null ? '📍 Tocca il primo punto'
                                            : '📍 Tocca il secondo punto',
                        style: const TextStyle(color: Colors.amber, fontSize: 13))))),
              if (_showLayers && _data != null)
                Positioned(top: 8, right: 8,
                  child: _LayerPanel(layers: _data!.layers,
                      onToggle: (l) => setState(() =>
                          _data!.layers[l]!.visible = !_data!.layers[l]!.visible))),
              if (_result != null)
                Positioned(left: 0, right: 0, bottom: 0,
                  child: _MeasurePanel(result: _result!, onClear: _clearMeasure,
                      bottomPad: bp)),
            ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

class _Painter extends CustomPainter {
  const _Painter({required this.data, required this.scale, required this.offset,
      this.measureP1, this.measureP2, this.measureMode = false});
  final _DxfData data;
  final double   scale;
  final Offset   offset;
  final Offset?  measureP1, measureP2;
  final bool     measureMode;

  Offset _w(double x, double y) =>
      Offset(x * scale + offset.dx, -y * scale + offset.dy);
  Offset _wo(Offset o) => _w(o.dx, o.dy);

  // Spessore adattivo: sottile come in AutoCAD, non esplode con lo zoom
  double get _lw => (0.5 / scale).clamp(0.2, 1.0);

  Paint _p(Color c) => Paint()
    ..color       = c
    ..strokeWidth = _lw
    ..style       = PaintingStyle.stroke
    ..strokeCap   = StrokeCap.round
    ..strokeJoin  = StrokeJoin.round;

  bool _vis(String layer) => data.layers[layer]?.visible ?? true;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0A0A14));

    for (final e in data.lines) {
      if (!_vis(e.layer)) continue;
      canvas.drawLine(_w(e.x1, e.y1), _w(e.x2, e.y2), _p(e.color));
    }

    for (final e in data.polys) {
      if (!_vis(e.layer) || e.pts.isEmpty) continue;
      final path = Path();
      final f = _wo(e.pts.first);
      path.moveTo(f.dx, f.dy);
      for (var i = 1; i < e.pts.length; i++) {
        final p = _wo(e.pts[i]);
        path.lineTo(p.dx, p.dy);
      }
      if (e.closed) path.close();
      canvas.drawPath(path, _p(e.color));
    }

    for (final e in data.circles) {
      if (!_vis(e.layer)) continue;
      canvas.drawCircle(_w(e.cx, e.cy), e.r * scale, _p(e.color));
    }

    for (final e in data.arcs) {
      if (!_vis(e.layer)) continue;
      var sweep = e.ea - e.sa;
      if (sweep <= 0) sweep += 360;
      canvas.drawArc(
        Rect.fromCircle(center: _w(e.cx, e.cy), radius: e.r * scale),
        -e.sa  * math.pi / 180.0,
        -sweep * math.pi / 180.0,
        false, _p(e.color));
    }

    if (measureMode) _drawMeasure(canvas);
  }

  void _drawMeasure(Canvas canvas) {
    if (measureP1 == null) return;
    final s1 = _wo(measureP1!);
    // Punto snap: cerchio vuoto + punto pieno
    canvas.drawCircle(s1, 9, Paint()..color=Colors.amber..style=PaintingStyle.stroke..strokeWidth=1.5);
    canvas.drawCircle(s1, 3, Paint()..color=Colors.amber);
    if (measureP2 == null) return;
    final s2  = _wo(measureP2!);
    canvas.drawCircle(s2, 9, Paint()..color=Colors.amber..style=PaintingStyle.stroke..strokeWidth=1.5);
    canvas.drawCircle(s2, 3, Paint()..color=Colors.amber);
    canvas.drawLine(s1, s2, Paint()
      ..color=Colors.amber..strokeWidth=1.5..style=PaintingStyle.stroke);
    final corner = Offset(s2.dx, s1.dy);
    canvas.drawLine(s1, corner, Paint()
      ..color=Colors.redAccent.withOpacity(0.7)..strokeWidth=1.0..style=PaintingStyle.stroke);
    canvas.drawLine(corner, s2, Paint()
      ..color=Colors.greenAccent.withOpacity(0.7)..strokeWidth=1.0..style=PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_Painter o) =>
      o.scale!=scale||o.offset!=offset||
      o.measureP1!=measureP1||o.measureP2!=measureP2||o.measureMode!=measureMode;
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer Panel
// ─────────────────────────────────────────────────────────────────────────────

class _LayerPanel extends StatelessWidget {
  const _LayerPanel({required this.layers, required this.onToggle});
  final Map<String, _LayerInfo> layers;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    final names = layers.keys.toList()..sort();
    return Container(
      width: 190,
      constraints: const BoxConstraints(maxHeight: 340),
      decoration: BoxDecoration(color: const Color(0xEE121228),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.fromLTRB(12,10,12,6),
          child: Row(children: [
            Icon(Icons.layers, size:14, color:Colors.white54),
            SizedBox(width:6),
            Text('Layer', style:TextStyle(color:Colors.white70, fontSize:12,
                fontWeight:FontWeight.bold)),
          ])),
        const Divider(height:1, color:Colors.white12),
        Flexible(child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical:4),
          shrinkWrap: true,
          itemCount: names.length,
          itemBuilder: (_, i) {
            final name = names[i];
            final info = layers[name]!;
            return InkWell(
              onTap: () => onToggle(name),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal:12, vertical:5),
                child: Row(children: [
                  Container(width:12, height:12,
                    decoration: BoxDecoration(
                      color: info.visible ? info.color : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: info.color, width:1.5))),
                  const SizedBox(width:8),
                  Expanded(child: Text(name, style: TextStyle(
                    color: info.visible ? Colors.white : Colors.white30,
                    fontSize:11), overflow: TextOverflow.ellipsis)),
                  if (!info.visible)
                    const Icon(Icons.visibility_off, size:12, color:Colors.white24),
                ])));
          })),
      ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Measure Panel
// ─────────────────────────────────────────────────────────────────────────────

class _MeasurePanel extends StatelessWidget {
  const _MeasurePanel({required this.result, required this.onClear, required this.bottomPad});
  final _MeasureResult result;
  final VoidCallback onClear;
  final double bottomPad;

  String _f(double v) {
    if (v.abs() >= 10000) return v.toStringAsFixed(0);
    if (v.abs() >= 100)   return v.toStringAsFixed(1);
    if (v.abs() >= 1)     return v.toStringAsFixed(3);
    return v.toStringAsExponential(2);
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: Color(0xFF12122A),
        border: Border(top: BorderSide(color: Colors.amber, width: 1.5))),
    padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Icon(Icons.straighten, color: Colors.amber, size: 16),
        const SizedBox(width: 8),
        const Text('Misura', style: TextStyle(color: Colors.amber,
            fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
        const Spacer(),
        GestureDetector(onTap: onClear,
            child: const Icon(Icons.close, color: Colors.white38, size: 20)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _Tile('Distanza', _f(result.distance), Colors.white),
        _Tile('Delta X',  _f(result.deltaX),   Colors.redAccent),
        _Tile('Delta Y',  _f(result.deltaY),   Colors.greenAccent),
        _Tile('Angolo', '${result.angleDeg.toStringAsFixed(2)}°', Colors.cyanAccent),
      ]),
      const SizedBox(height: 8),
      Text('P1 (${_f(result.p1.dx)}, ${_f(result.p1.dy)})   '
           'P2 (${_f(result.p2.dx)}, ${_f(result.p2.dy)})',
          style: const TextStyle(color: Colors.white30, fontSize: 10),
          textAlign: TextAlign.center),
    ]));
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.color);
  final String label, value; final Color color;
  @override Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    const SizedBox(height: 3),
    Text(value, style: TextStyle(color: color, fontSize: 14,
        fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
  ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / Error
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override Widget build(BuildContext context) => const Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: Colors.amber),
      SizedBox(height: 16),
      Text('Caricamento…', style: TextStyle(color: Colors.white54, fontSize: 13)),
    ]));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.msg});
  final String msg;
  @override Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Text('Errore:\n$msg',
        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        textAlign: TextAlign.center)));
}