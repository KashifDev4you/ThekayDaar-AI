// =============================================================================
// panorama_screen.dart — 360° / panoramic visualization (spec §17)
//
// A first-person, look-around panorama generated ON-DEVICE from the structured
// blueprint JSON (cylindrical projection on CustomPainter). Zero external
// packages, zero paid APIs — always available offline.
//
// Placeholder architecture (spec §17): when a backend 360 render becomes
// available it can be attached via HousePlanService.setPanoramaUrl(...) and
// shown here in addition to / instead of the procedural view — the screen's
// [panoramaUrl] parameter is already plumbed for it.
//
// Client-only surface (spec §2/§28): the contractor flow never routes here.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ali_app/house_planner/models/house_plan_models.dart';

class PanoramaScreen extends StatefulWidget {
  const PanoramaScreen({
    super.key,
    required this.plan,
    this.floor = 0,
    this.panoramaUrl,
  });

  final HousePlan plan;
  final int floor;

  /// Optional backend-rendered 360 image (future enhancement). When null the
  /// procedural on-device panorama is shown.
  final String? panoramaUrl;

  @override
  State<PanoramaScreen> createState() => _PanoramaScreenState();
}

class _PanoramaScreenState extends State<PanoramaScreen> {
  late int _floor;
  late Offset _eye; // position in plan feet (x, y)
  double _yaw = 0; // radians, 0 = looking north (−y)
  bool _autoRotate = false;

  static const double _wallH = 9.5; // ft
  static const double _eyeH = 5.0; // ft
  static const double _fov = 100 * math.pi / 180; // horizontal field of view

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _amberD = Color(0xFFA8861D);
  static const _amberL = Color(0xFFFBF6E3);
  static const _white = Colors.white;
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);

  @override
  void initState() {
    super.initState();
    _floor = widget.floor;
    _eye = _initialEye();
    if (_autoRotate) _tick();
  }

  void _tick() {
    Future.delayed(const Duration(milliseconds: 33), () {
      if (!mounted || !_autoRotate) return;
      setState(() => _yaw += 0.004);
      _tick();
    });
  }

  /// Stand in the biggest INDOOR room of the floor — porch / garden /
  /// other outdoor areas are skipped so the walk-through starts INSIDE the
  /// house (the car porch is often the biggest room and would otherwise put
  /// the eye in the parking area). Falls back to the biggest room overall,
  /// then the plot center.
  Offset _initialEye() {
    final rooms = widget.plan.roomsOn(_floor);
    if (rooms.isEmpty) {
      return Offset(widget.plan.plotWidthFt / 2, widget.plan.plotLengthFt / 2);
    }
    HousePlanRoom? best;
    var bestArea = -1.0;
    for (final r in rooms) {
      if (r.spec.group == RoomGroup.outdoor) continue;
      if (r.area > bestArea) {
        bestArea = r.area;
        best = r;
      }
    }
    best ??= rooms.reduce((a, b) => a.area >= b.area ? a : b);
    return Offset(best.x + best.width / 2, best.y + best.length / 2);
  }

  /// Room the eye currently stands in (null = outside every room).
  HousePlanRoom? _roomAtEye() {
    for (final r in widget.plan.roomsOn(_floor)) {
      if (_eye.dx >= r.x && _eye.dx <= r.right &&
          _eye.dy >= r.y && _eye.dy <= r.bottom) {
        return r;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final floors = widget.plan.floors.map((f) => f.floor).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF101410),
      appBar: AppBar(
        backgroundColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('360° View',
            style: TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w800)),
        actions: [
          if (floors.length > 1)
            PopupMenuButton<int>(
              icon: const Icon(Icons.layers_rounded, color: _white),
              onSelected: (f) => setState(() {
                _floor = f;
                _eye = _initialEye();
              }),
              itemBuilder: (_) => floors
                  .map((f) => PopupMenuItem(
                        value: f,
                        child: Text(HousePlanFloor.floorLabel(f)),
                      ))
                  .toList(),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── compass strip ─────────────────────────────────────
          Container(
            color: _navy,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: CustomPaint(
              painter: _CompassStripPainter(yaw: _yaw),
              size: const Size(double.infinity, 26),
            ),
          ),

          // ── panorama canvas ───────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) {
                      _autoRotate = false;
                      setState(() => _yaw -= d.delta.dx * 0.0035);
                    },
                    child: CustomPaint(
                      painter: _PanoramaPainter(
                        plan: widget.plan,
                        floor: _floor,
                        eye: _eye,
                        yaw: _yaw,
                        fov: _fov,
                        wallHeight: _wallH,
                        eyeHeight: _eyeH,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),

                // eye position minimap (draggable)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _MiniMap(
                    plan: widget.plan,
                    floor: _floor,
                    eye: _eye,
                    yaw: _yaw,
                    onMove: (p) => setState(() => _eye = p),
                  ),
                ),

                // hint chip + current-room chip
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Drag to look around · move the dot to walk',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(builder: (_) {
                        final room = _roomAtEye();
                        final inside = room != null &&
                            room.spec.group != RoomGroup.outdoor;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: inside
                                ? _amber
                                : Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            inside
                                ? 'You are in · ${room.name}'
                                : 'Outside the house — drag the dot on the '
                                    'mini-map to walk inside',
                            style: TextStyle(
                                color: inside ? _navy : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w800),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── footer ────────────────────────────────────────────
          Container(
            color: _white,
            padding: EdgeInsets.fromLTRB(16, 10, 16,
                12 + MediaQuery.of(context).padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Procedural 360 preview — rendered on your device '
                        'from the blueprint.',
                        style: const TextStyle(
                            fontSize: 10.5, height: 1.4, color: _textSec),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() {
                        _autoRotate = !_autoRotate;
                        if (_autoRotate) _tick();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _autoRotate ? _amber : _amberL,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _autoRotate
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 16,
                              color: _autoRotate ? _navy : _amberD,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _autoRotate ? 'Pause' : 'Auto-rotate',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _autoRotate ? _navy : _amberD),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANORAMA PAINTER — cylindrical first-person projection
// ─────────────────────────────────────────────────────────────

class _PanoramaPainter extends CustomPainter {
  _PanoramaPainter({
    required this.plan,
    required this.floor,
    required this.eye,
    required this.yaw,
    required this.fov,
    required this.wallHeight,
    required this.eyeHeight,
  });

  final HousePlan plan;
  final int floor;
  final Offset eye;
  final double yaw;
  final double fov;
  final double wallHeight;
  final double eyeHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.52;
    final pxPerRad = w / fov;

    // ── ceiling + floor ────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTRB(0, 0, w, horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3E443B), Color(0xFFD8D4C4)],
        ).createShader(Rect.fromLTRB(0, 0, w, horizon)),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, horizon, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A8062), Color(0xFF2A2A22)],
        ).createShader(Rect.fromLTRB(0, horizon, w, h)),
    );

    // ── collect wall pieces ────────────────────────────────────
    final pieces = <_WallPiece>[];
    for (final room in plan.roomsOn(floor)) {
      _addWall(pieces: pieces, room: room);
    }
    pieces.sort((a, b) => b.dist.compareTo(a.dist)); // far → near

    // ── draw ───────────────────────────────────────────────────
    for (final p in pieces) {
      final x0 = w / 2 + _angDiff(p.a0, yaw) * pxPerRad;
      final x1 = w / 2 + _angDiff(p.a1, yaw) * pxPerRad;
      if ((x0 < -80 && x1 < -80) || (x0 > w + 80 && x1 > w + 80)) continue;

      final d = p.dist.clamp(0.6, 400).toDouble();
      final focal = pxPerRad;
      final top = horizon - (wallHeight - eyeHeight) * focal / d;
      final bottom = horizon + eyeHeight * focal / d;

      final left = math.min(x0, x1);
      final right = math.max(x0, x1);
      if (right - left < 0.5) continue;

      // shade by distance (simple fog)
      final t = (d / 90).clamp(0.0, 0.75).toDouble();
      // orientation shading — walls facing different compass directions get
      // slightly different brightness so corners/depth are readable instead
      // of one flat identical color everywhere.
      final base = Color.lerp(
          Color.lerp(p.color, Colors.black, p.shade)!,
          const Color(0xFF9AA294),
          t)!;

      final rect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(rect, Paint()..color = base);

      // baseboard (dark strip at the floor) + ceiling trim — cheap interior
      // depth cues that make the wall read as a room, not a flat block.
      final hgt = bottom - top;
      canvas.drawRect(
        Rect.fromLTRB(left, bottom - hgt * 0.07, right, bottom),
        Paint()..color = Colors.black.withValues(alpha: 0.28),
      );
      canvas.drawRect(
        Rect.fromLTRB(left, top, right, top + hgt * 0.045),
        Paint()..color = Colors.white.withValues(alpha: 0.16),
      );

      // subtle wall edge highlight
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withValues(alpha: 0.12),
      );

      // door / window frames
      if (p.opening == 'door') {
        canvas.drawRect(
          Rect.fromLTRB(left, top + (bottom - top) * 0.18, right, bottom),
          Paint()..color = const Color(0xFF241A0E).withValues(alpha: 0.92),
        );
      } else if (p.opening == 'window') {
        canvas.drawRect(
          Rect.fromLTRB(
              left, top + (bottom - top) * 0.15, right, bottom - (bottom - top) * 0.28),
          Paint()..color = const Color(0xFFBFE3F5).withValues(alpha: 0.95),
        );
      }
    }
  }

  void _addWall({
    required List<_WallPiece> pieces,
    required HousePlanRoom room,
  }) {
    // Wall endpoints (plan ft), counter-clockwise: n, e, s, w.
    final walls = <List<Offset>>[
      [Offset(room.x, room.y), Offset(room.right, room.y)], // n
      [Offset(room.right, room.y), Offset(room.right, room.bottom)], // e
      [Offset(room.right, room.bottom), Offset(room.x, room.bottom)], // s
      [Offset(room.x, room.bottom), Offset(room.x, room.y)], // w
    ];
    const wallKeys = ['n', 'e', 's', 'w'];

    for (var wi = 0; wi < walls.length; wi++) {
      final a = walls[wi][0];
      final b = walls[wi][1];
      final len = (b - a).distance;
      if (len < 0.01) continue;

      // openings for this wall
      final openings = [
        ...room.doors.where((o) => o.wall == wallKeys[wi]).map((o) => (o, 'door')),
        ...room.windows.where((o) => o.wall == wallKeys[wi]).map((o) => (o, 'window')),
      ];

      final dir = (b - a) / len;
      const step = 0.75; // ft per piece — smaller = smoother near walls
      // deterministic per-wall brightness (sun from the north-west):
      // n-walls darkest, s-walls brightest, e/w in between.
      final shade = const [0.16, 0.10, 0.0, 0.05][wi];
      for (var t = 0.0; t < len; t += step) {
        final t2 = math.min(t + step, len);
        final mid = a + dir * ((t + t2) / 2);
        final rel = mid - eye;
        final dist = rel.distance;
        final midAngle = math.atan2(rel.dy, rel.dx);
        // skip pieces fully outside the FOV
        final angMid = _angDiff(midAngle, yaw);
        if (angMid.abs() > fov / 2 + 0.6) continue;

        // opening at this piece? (offset = center along wall)
        String? opening;
        for (final (o, kind) in openings) {
          final s0 = o.offset - o.width / 2;
          final s1 = o.offset + o.width / 2;
          if ((t + t2) / 2 >= s0 && (t + t2) / 2 <= s1) {
            opening = kind;
            break;
          }
        }

        final pa = a + dir * t;
        final pb = a + dir * t2;
        pieces.add(_WallPiece(
          a0: math.atan2((pa - eye).dy, (pa - eye).dx),
          a1: math.atan2((pb - eye).dy, (pb - eye).dx),
          dist: dist,
          color: _wallColor(room),
          shade: shade,
          opening: opening,
        ));
      }
    }
  }

  Color _wallColor(HousePlanRoom room) {
    switch (room.spec.group) {
      case RoomGroup.bedroom:
        return const Color(0xFFE8DCC2);
      case RoomGroup.bathroom:
        return const Color(0xFFD3E5EE);
      case RoomGroup.kitchen:
        return const Color(0xFFD9EBDD);
      case RoomGroup.living:
        return const Color(0xFFEFE5C8);
      case RoomGroup.outdoor:
        return const Color(0xFFCFE8D8);
      case RoomGroup.passage:
        return const Color(0xFFE2DFD2);
      case RoomGroup.service:
        return const Color(0xFFE4E6E1);
    }
  }

  double _angDiff(double a, double ref) {
    var d = (a - ref) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    return d;
  }

  @override
  bool shouldRepaint(_PanoramaPainter old) =>
      old.eye != eye || old.yaw != yaw || old.floor != floor;
}

class _WallPiece {
  _WallPiece({
    required this.a0,
    required this.a1,
    required this.dist,
    required this.color,
    required this.shade,
    this.opening,
  });

  final double a0; // bearing of start (rad)
  final double a1; // bearing of end (rad)
  final double dist; // ft from eye to piece midpoint
  final Color color;
  final double shade; // orientation darkening 0..0.25
  final String? opening; // 'door' | 'window' | null
}

// ─────────────────────────────────────────────────────────────
// COMPASS STRIP — N/E/S/W ticks driven by yaw
// ─────────────────────────────────────────────────────────────

class _CompassStripPainter extends CustomPainter {
  _CompassStripPainter({required this.yaw});

  final double yaw;

  @override
  void paint(Canvas canvas, Size size) {
    // Plan "north" is −y. yaw 0 → looking north.
    // World bearing of screen center = yaw (atan2 convention: +x east, +y south).
    // Compass angle (0=N, 90=E) of a bearing θ = (90 + θ°) mod 360.
    final w = size.width;
    final h = size.height;
    final mid = Offset(w / 2, h / 2);

    final p = TextPainter(textDirection: TextDirection.ltr);
    for (var deg = 0; deg < 360; deg += 45) {
      // compass angle of this cardinal, relative to view center
      final viewDeg = (deg - (90 + yaw * 180 / math.pi)) % 360;
      var dd = viewDeg;
      if (dd > 180) dd -= 360;
      if (dd < -180) dd += 360;
      // map ±90° of compass difference across the strip width
      final x = mid.dx + (dd / 90) * (w / 2 - 24);
      if (x < 16 || x > w - 16) continue;

      final isCardinal = deg % 90 == 0;
      final label = switch (deg) {
        0 => 'N',
        90 => 'E',
        180 => 'S',
        270 => 'W',
        _ => '·',
      };
      p.text = TextSpan(
        text: label,
        style: TextStyle(
          color: isCardinal ? const Color(0xFFC9A227) : Colors.white38,
          fontSize: isCardinal ? 12 : 9,
          fontWeight: FontWeight.w800,
        ),
      );
      p.layout();
      p.paint(canvas, Offset(x - p.width / 2, h / 2 - p.height / 2));
    }

    // center marker
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: mid, width: 3, height: 14),
          const Radius.circular(2)),
      Paint()..color = const Color(0xFFC9A227),
    );
  }

  @override
  bool shouldRepaint(_CompassStripPainter old) => old.yaw != yaw;
}

// ─────────────────────────────────────────────────────────────
// MINIMAP — draggable eye position
// ─────────────────────────────────────────────────────────────

class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.plan,
    required this.floor,
    required this.eye,
    required this.yaw,
    required this.onMove,
  });

  final HousePlan plan;
  final int floor;
  final Offset eye;
  final double yaw;
  final void Function(Offset) onMove;

  static const double _size = 132;

  @override
  Widget build(BuildContext context) {
    final scale = _size /
        math.max(plan.plotWidthFt, plan.plotLengthFt).clamp(1, double.infinity);

    return GestureDetector(
      onPanUpdate: (d) => onMove(Offset(
        (eye.dx + d.delta.dx / scale)
            .clamp(0.5, plan.plotWidthFt - 0.5),
        (eye.dy + d.delta.dy / scale)
            .clamp(0.5, plan.plotLengthFt - 0.5),
      )),
      onTapUp: (d) => onMove(Offset(
        (d.localPosition.dx / scale).clamp(0.5, plan.plotWidthFt - 0.5),
        (d.localPosition.dy / scale).clamp(0.5, plan.plotLengthFt - 0.5),
      )),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(
            painter: _MiniMapPainter(
              plan: plan,
              floor: floor,
              eye: eye,
              yaw: yaw,
              scale: scale,
            ),
            size: const Size(_size, _size),
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.plan,
    required this.floor,
    required this.eye,
    required this.yaw,
    required this.scale,
  });

  final HousePlan plan;
  final int floor;
  final Offset eye;
  final double yaw;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    // plot boundary
    canvas.drawRect(
      Rect.fromLTWH(0, 0, plan.plotWidthFt * scale, plan.plotLengthFt * scale),
      Paint()..color = const Color(0xFFE9E6DA),
    );

    // rooms
    for (final r in plan.roomsOn(floor)) {
      canvas.drawRect(
        Rect.fromLTWH(r.x * scale, r.y * scale, r.width * scale,
            r.length * scale),
        Paint()..color = r.spec.color,
      );
      canvas.drawRect(
        Rect.fromLTWH(r.x * scale, r.y * scale, r.width * scale,
            r.length * scale),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFF0E3B2E).withValues(alpha: 0.4),
      );
    }

    // view cone (yaw: atan2 convention; north = −y)
    final eyePx = Offset(eye.dx * scale, eye.dy * scale);
    const coneHalf = 0.8;
    final cone = Path()
      ..moveTo(eyePx.dx, eyePx.dy)
      ..lineTo(eyePx.dx + 26 * math.cos(yaw - coneHalf),
          eyePx.dy + 26 * math.sin(yaw - coneHalf))
      ..lineTo(eyePx.dx + 26 * math.cos(yaw + coneHalf),
          eyePx.dy + 26 * math.sin(yaw + coneHalf))
      ..close();
    canvas.drawPath(
      cone,
      Paint()..color = const Color(0xFFC9A227).withValues(alpha: 0.35),
    );

    // eye dot
    canvas.drawCircle(
      eyePx,
      4.5,
      Paint()..color = const Color(0xFF0E3B2E),
    );
    canvas.drawCircle(
      eyePx,
      2,
      Paint()..color = const Color(0xFFC9A227),
    );
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) =>
      old.eye != eye || old.yaw != yaw || old.floor != floor;
}
