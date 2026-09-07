// =============================================================================
// house3d_painter.dart — procedural 3D model renderer (spec §15, §16)
//
// Generates the 3D house model FROM THE STRUCTURED BLUEPRINT JSON — never
// from an AI image (spec: blueprint is the source of truth). The geometry
// (walls, floors, doors, windows, roof) is built procedurally and projected
// with a lightweight isometric/perspective camera implemented on
// CustomPainter — zero external packages, zero paid APIs, fully offline.
//
// The same painter powers the panorama screen: it can render with a
// 360°-style rotating camera for the "View 360" experience.
//
// A future backend exporter can convert the same room rects into a GLB
// (three.js/Blender) without touching this file's callers.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ali_app/house_planner/models/house_plan_models.dart';

/// Camera for the mini 3D engine.
class House3dCamera {
  House3dCamera({
    this.yaw = -0.7, // rotation around the vertical axis (radians)
    this.pitch = 0.55, // elevation angle
    this.distance = 1.6, // multiplied by model radius
    this.zoom = 1.0,
  });

  double yaw;
  double pitch;
  double distance;
  double zoom;

  void reset() {
    yaw = -0.7;
    pitch = 0.55;
    distance = 1.6;
    zoom = 1.0;
  }
}

class House3dPainter extends CustomPainter {
  House3dPainter({
    required this.plan,
    required this.camera,
    this.floor = 0,
    this.showAllFloors = false,
    this.wallHeight = 9.5, // ft per storey
    this.lineColor = const Color(0xFF0E3B2E),
  });

  final HousePlan plan;
  final House3dCamera camera;
  final int floor;
  final bool showAllFloors;
  final double wallHeight;
  final Color lineColor;

  // ── 3D MATH ────────────────────────────────────────────────

  late final double _cx = plan.plotWidthFt / 2;
  late final double _cy = plan.plotLengthFt / 2;
  late final double _radius =
      math.sqrt(_cx * _cx + _cy * _cy).clamp(1, double.infinity);

  /// Projects a world point (x, y, z) to screen space.
  /// World: x → west-east, y → north-south (front), z → up.
  Offset _project(double x, double y, double z, Size size) {
    // center on model
    final dx = x - _cx;
    final dy = y - _cy;

    // yaw rotation
    final cosY = math.cos(camera.yaw);
    final sinY = math.sin(camera.yaw);
    final rx = dx * cosY - dy * sinY;
    final ry = dx * sinY + dy * cosY;

    // pitch rotation around the x axis
    final cosP = math.cos(camera.pitch);
    final sinP = math.sin(camera.pitch);
    final ry2 = ry * cosP - z * sinP;
    final rz = ry * sinP + z * cosP;

    // perspective
    final camDist = _radius * camera.distance;
    final depth = camDist - ry2; // distance from camera plane
    final f = (depth > 0.1) ? (camDist * 0.9) / depth : 1000.0;

    final scale = size.shortestSide / (_radius * 2.4) * camera.zoom * f;
    return Offset(
      size.width / 2 + rx * scale,
      size.height / 2 - rz * scale, // screen y is inverted
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── ground slab ───────────────────────────────────────────
    _quad(
      canvas,
      size,
      [Offset(0, 0), Offset(plan.plotWidthFt, 0),
       Offset(plan.plotWidthFt, plan.plotLengthFt), Offset(0, plan.plotLengthFt)],
      0,
      fill: const Color(0xFFE9E5D8),
      stroke: lineColor.withValues(alpha: 0.5),
      strokeWidth: 1.5,
    );

    final floorsToDraw = showAllFloors
        ? plan.floors.map((f) => f.floor).toList()
        : [floor];

    for (final f in floorsToDraw) {
      final baseZ = (f < 0 ? -1 : f) * wallHeight;
      for (final room in plan.roomsOn(f)) {
        _drawRoom(canvas, size, room, baseZ);
      }
    }
  }

  void _drawRoom(Canvas canvas, Size size, HousePlanRoom room, double baseZ) {
    final topZ = baseZ + wallHeight * (room.spec.group == RoomGroup.outdoor ? 0.12 : 1);

    // Vertical wall quads (4 walls per room)
    final corners = [
      Offset(room.x, room.y),
      Offset(room.right, room.y),
      Offset(room.right, room.bottom),
      Offset(room.x, room.bottom),
    ];
    for (var i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      _quad(
        canvas,
        size,
        [a, b],
        baseZ,
        topZ: topZ,
        fill: room.spec.color.withValues(alpha: 0.92),
        stroke: lineColor,
        strokeWidth: 1,
      );
    }

    // Roof/floor slab
    _quad(
      canvas,
      size,
      corners,
      topZ,
      fill: room.spec.color.withValues(alpha: 0.55),
      stroke: lineColor,
      strokeWidth: 1.2,
    );

    // Windows: light band on exterior walls
    _drawOpenings(canvas, size, room, baseZ, topZ);
  }

  void _drawOpenings(
      Canvas canvas, Size size, HousePlanRoom room, double baseZ, double topZ) {
    final winPaint = Paint()
      ..color = const Color(0xFFBFE3F5)
      ..style = PaintingStyle.fill;
    final doorPaint = Paint()
      ..color = const Color(0xFF8D6E63);

    void band(PlanOpening o, Paint p, double zFrom, double zTo) {
      final along = (o.wall == 'n' || o.wall == 's') ? room.width : room.length;
      final half = (o.width / 2).clamp(0, along / 2).toDouble();
      final c = o.offset.clamp(half, along - half).toDouble();
      double x1, y1, x2, y2;
      switch (o.wall) {
        case 'n':
          x1 = room.x + c - half; y1 = room.y; x2 = room.x + c + half; y2 = room.y;
        case 's':
          x1 = room.x + c - half; y1 = room.bottom; x2 = room.x + c + half; y2 = room.bottom;
        case 'w':
          x1 = room.x; y1 = room.y + c - half; x2 = room.x; y2 = room.y + c + half;
        default:
          x1 = room.right; y1 = room.y + c - half; x2 = room.right; y2 = room.y + c + half;
      }
      _quad(canvas, size, [Offset(x1, y1), Offset(x2, y2)], zFrom,
          topZ: zTo, fill: p.color, stroke: lineColor.withValues(alpha: 0.4), strokeWidth: 0.6);
    }

    for (final w in room.windows) {
      band(w, winPaint, baseZ + wallHeight * 0.45, baseZ + wallHeight * 0.8);
    }
    for (final d in room.doors) {
      band(d, doorPaint, baseZ, baseZ + wallHeight * 0.42);
    }
  }

  /// Draws a quad. If [topZ] is null, [points] are 2D ground corners at
  /// height [z]. Otherwise a vertical wall between [z] and [topZ].
  void _quad(
    Canvas canvas,
    Size size,
    List<Offset> points,
    double z, {
    double? topZ,
    Color? fill,
    Color? stroke,
    double strokeWidth = 1,
  }) {
    if (points.length < 2) return;

    List<Offset> projected;
    if (topZ == null) {
      // horizontal polygon at height z
      projected = points.map((p) => _project(p.dx, p.dy, z, size)).toList();
    } else if (points.length == 2) {
      // vertical wall between two ground points
      final a = points[0], b = points[1];
      projected = [
        _project(a.dx, a.dy, z, size),
        _project(b.dx, b.dy, z, size),
        _project(b.dx, b.dy, topZ, size),
        _project(a.dx, a.dy, topZ, size),
      ];
    } else {
      return;
    }

    final path = Path()..moveTo(projected[0].dx, projected[0].dy);
    for (var i = 1; i < projected.length; i++) {
      path.lineTo(projected[i].dx, projected[i].dy);
    }
    path.close();

    if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill);
    }
    if (stroke != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant House3dPainter old) =>
      old.plan != plan ||
      old.floor != floor ||
      old.showAllFloors != showAllFloors ||
      old.camera.yaw != camera.yaw ||
      old.camera.pitch != camera.pitch ||
      old.camera.zoom != camera.zoom;
}

// ─────────────────────────────────────────────────────────────
// 3D VIEWER SCREEN (spec §16)
// ─────────────────────────────────────────────────────────────

class House3dViewerScreen extends StatefulWidget {
  const House3dViewerScreen({super.key, required this.plan, this.floor = 0});

  final HousePlan plan;
  final int floor;

  @override
  State<House3dViewerScreen> createState() => _House3dViewerScreenState();
}

class _House3dViewerScreenState extends State<House3dViewerScreen> {
  late final House3dCamera _camera;
  late int _floor;
  bool _showAllFloors = false;
  bool _autoRotate = true;

  static const _navy = Color(0xFF0E3B2E);
  static const _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _camera = House3dCamera();
    _floor = widget.floor;
    _tick();
  }

  void _tick() {
    // lightweight auto-rotate loop
    Future.delayed(const Duration(milliseconds: 33), () {
      if (!mounted) return;
      if (_autoRotate) {
        setState(() => _camera.yaw += 0.006);
      }
      _tick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final floors = widget.plan.floors.map((f) => f.floor).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: _navy,
        title: const Text('3D View',
            style: TextStyle(color: _white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (floors.length > 1)
            PopupMenuButton<int>(
              icon: const Icon(Icons.layers_rounded, color: _white),
              onSelected: (f) => setState(() {
                _floor = f;
                _showAllFloors = false;
              }),
              itemBuilder: (_) => [
                ...floors.map((f) => PopupMenuItem(
                      value: f,
                      child: Text(HousePlanFloor.floorLabel(f)),
                    )),
                const PopupMenuItem(
                  value: 99,
                  child: Text('All floors'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // header strip
          Container(
            width: double.infinity,
            color: _white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '${widget.plan.plotWidthFt.round()} × ${widget.plan.plotLengthFt.round()} ft · '
              '${_showAllFloors ? 'All floors' : HousePlanFloor.floorLabel(_floor)} · '
              '${widget.plan.totalRooms} rooms',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D6B64),
              ),
            ),
          ),
          // canvas with gestures
          // NOTE: use ONLY the scale recognizer here — registering both pan
          // and scale on one GestureDetector throws a Flutter assertion
          // ("scale is a superset of pan"). One finger drags via
          // focalPointDelta, two fingers pinch-zoom via scale.
          Expanded(
            child: GestureDetector(
              onScaleUpdate: (s) => setState(() {
                _autoRotate = false;
                if (s.pointerCount == 1) {
                  _camera.yaw += s.focalPointDelta.dx * 0.008;
                  _camera.pitch =
                      (_camera.pitch - s.focalPointDelta.dy * 0.006)
                          .clamp(0.1, 1.4);
                } else {
                  _camera.zoom =
                      (_camera.zoom * s.scale).clamp(0.4, 4);
                }
              }),
              child: CustomPaint(
                painter: House3dPainter(
                  plan: widget.plan,
                  camera: _camera,
                  floor: _floor,
                  showAllFloors: _showAllFloors,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          // controls
          Container(
            color: _white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Row(
              children: [
                _ctrl(Icons.play_arrow_rounded, _autoRotate ? 'Pause' : 'Rotate',
                    () => setState(() => _autoRotate = !_autoRotate)),
                const SizedBox(width: 8),
                _ctrl(Icons.zoom_in_rounded, 'Zoom', () => setState(() {
                      _camera.zoom = (_camera.zoom * 1.2).clamp(0.4, 4);
                    })),
                const SizedBox(width: 8),
                _ctrl(Icons.zoom_out_rounded, 'Zoom', () => setState(() {
                      _camera.zoom = (_camera.zoom / 1.2).clamp(0.4, 4);
                    })),
                const SizedBox(width: 8),
                _ctrl(Icons.restart_alt_rounded, 'Reset', () {
                  setState(() {
                    _camera.reset();
                    _autoRotate = true;
                  });
                }),
                const Spacer(),
                if (floors.length > 1)
                  _ctrl(Icons.layers_clear_rounded,
                      _showAllFloors ? 'One floor' : 'All floors',
                      () => setState(() => _showAllFloors = !_showAllFloors)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctrl(IconData icon, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF6E3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE3E0D5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFFA8861D)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _navy),
              ),
            ],
          ),
        ),
      );
}
