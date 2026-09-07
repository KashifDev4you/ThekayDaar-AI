// =============================================================================
// blueprint_painter.dart — 2D blueprint renderer (spec §12)
//
// Renders the structured plan JSON with a CustomPainter — NOT an image.
// Draws: plot boundary, walls, room fills + names + dimensions, doors,
// windows, staircase symbol, parking hatch, and a north arrow. The canvas
// transform (scale + offset) is applied by the InteractiveViewer that hosts
// this painter, so zoom/pan come for free.
//
// Coordinate system: plan feet → logical pixels with [scale] px/ft, origin
// at the plot's top-left (north-west). y grows toward the street/front (s).
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ali_app/house_planner/models/house_plan_models.dart';

class BlueprintPainter extends CustomPainter {
  BlueprintPainter({
    required this.plan,
    required this.floor,
    this.scale = 6,
    this.selectedRoomId,
    this.showDimensions = true,
    this.showOpenings = true,
    this.lineColor = const Color(0xFF0E3B2E),
  });

  final HousePlan plan;
  final int floor;
  final double scale; // px per foot
  final String? selectedRoomId;
  final bool showDimensions;
  final bool showOpenings;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rooms = plan.roomsOn(floor);
    final W = plan.plotWidthFt * scale;
    final L = plan.plotLengthFt * scale;

    // ── background ─────────────────────────────────────────────
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F5EF),
    );

    // ── plot boundary (thick dark) ─────────────────────────────
    final boundary = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(Rect.fromLTWH(0, 0, W, L), boundary);

    // ── rooms ──────────────────────────────────────────────────
    for (final r in rooms) {
      final rect = Rect.fromLTWH(
        r.x * scale,
        r.y * scale,
        r.width * scale,
        r.length * scale,
      );
      final selected = r.id == selectedRoomId;

      // Fill
      canvas.drawRect(
        rect,
        Paint()
          ..color = selected
              ? r.spec.color.withValues(alpha: 0.95)
              : r.spec.color,
      );

      // Walls (double-line feel via thick stroke + inner white line)
      canvas.drawRect(
        rect,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 1.8,
      );

      // Openings punch gaps in the wall (draw wall-colored segment then a
      // white "gap" over it).
      if (showOpenings) {
        _paintDoor(canvas, r, 'door');
        _paintWindow(canvas, r);
      }

      // Parking hatch
      if (r.type == 'car_parking' || r.type == 'garage') {
        _hatch(canvas, rect);
      }

      // Staircase symbol
      if (r.type == 'staircase') {
        _stairs(canvas, rect);
      }

      // Labels
      _label(canvas, r, rect, selected);
    }

    // ── north arrow ────────────────────────────────────────────
    _northArrow(canvas, size);
  }

  // ── helpers ─────────────────────────────────────────────────

  void _paintDoor(Canvas canvas, HousePlanRoom r, String kind) {
    for (final o in r.doors) {
      final seg = _wallSegment(r, o.wall, o.offset, o.width.clamp(1.5, 12));
      if (seg == null) continue;
      // white gap = opening
      canvas.drawLine(
        seg.$1,
        seg.$2,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.butt,
      );
      // door swing (quarter arc)
      final swingPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final a = seg.$1, b = seg.$2;
      final len = (b - a).distance;
      if (len > 4) {
        final radius = len;
        // arc center at one end, opening toward the room interior
        final interior = _interiorDirection(r, o.wall);
        final startAngle = _angleOf(interior.dx, interior.dy);
        canvas.drawArc(
          Rect.fromCircle(center: a, radius: radius),
          startAngle,
          math.pi / 2,
          false,
          swingPaint,
        );
      }
    }
  }

  void _paintWindow(Canvas canvas, HousePlanRoom r) {
    for (final o in r.windows) {
      final seg = _wallSegment(r, o.wall, o.offset, o.width.clamp(1, 12));
      if (seg == null) continue;
      // white gap then thin double line = window
      canvas.drawLine(
        seg.$1,
        seg.$2,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 6,
      );
      canvas.drawLine(
        seg.$1,
        seg.$2,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.4,
      );
    }
  }

  /// Returns the two endpoints of an opening on wall [wall] of room [r].
  (Offset, Offset)? _wallSegment(
      HousePlanRoom r, String wall, double offsetC, double width) {
    final along = (wall == 'n' || wall == 's') ? r.width : r.length;
    final half = (width / 2).clamp(0, along / 2).toDouble();
    final c = offsetC.clamp(half, along - half).toDouble();

    double x1, y1, x2, y2;
    switch (wall) {
      case 'n':
        x1 = r.x + c - half;
        y1 = r.y;
        x2 = r.x + c + half;
        y2 = r.y;
      case 's':
        x1 = r.x + c - half;
        y1 = r.y + r.length;
        x2 = r.x + c + half;
        y2 = r.y + r.length;
      case 'w':
        x1 = r.x;
        y1 = r.y + c - half;
        x2 = r.x;
        y2 = r.y + c + half;
      case 'e':
        x1 = r.x + r.width;
        y1 = r.y + c - half;
        x2 = r.x + r.width;
        y2 = r.y + c + half;
      default:
        return null;
    }
    return (
      Offset(x1 * scale, y1 * scale),
      Offset(x2 * scale, y2 * scale),
    );
  }

  Offset _interiorDirection(HousePlanRoom r, String wall) {
    switch (wall) {
      case 'n':
        return const Offset(0, 1);
      case 's':
        return const Offset(0, -1);
      case 'w':
        return const Offset(1, 0);
      default: // 'e'
        return const Offset(-1, 0);
    }
  }

  double _angleOf(double dx, double dy) => math.atan2(dy, dx);

  void _hatch(Canvas canvas, Rect rect) {
    final p = Paint()
      ..color = lineColor.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    const step = 14.0;
    for (var d = -rect.height; d < rect.width; d += step) {
      canvas.drawLine(
        Offset(rect.left + d, rect.bottom),
        Offset(rect.left + d + rect.height, rect.top),
        p,
      );
    }
  }

  void _stairs(Canvas canvas, Rect rect) {
    final p = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2;
    final treads = (rect.height / 9).floor().clamp(3, 12);
    for (var i = 1; i < treads; i++) {
      final y = rect.top + rect.height * i / treads;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), p);
    }
    // direction arrow
    final c = rect.center;
    final a = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..moveTo(c.dx, rect.top + 6)
      ..lineTo(c.dx, rect.bottom - 6);
    canvas.drawPath(path, a);
  }

  void _label(Canvas canvas, HousePlanRoom r, Rect rect, bool selected) {
    final tp = TextPainter(
      text: TextSpan(
        text: r.name,
        style: TextStyle(
          color: selected ? Colors.white : lineColor,
          fontSize: _fontSizeFor(rect),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: rect.width - 6);

    var top = rect.center.dy - tp.height / 2;
    if (showDimensions && rect.height > tp.height + 26) {
      top = rect.top + rect.height * 0.32;
    }
    tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, top));

    if (showDimensions && rect.width > 42 && rect.height > 30) {
      final dim = TextPainter(
        text: TextSpan(
          text: _dimLabel(r),
          style: TextStyle(
            color: lineColor.withValues(alpha: 0.65),
            fontSize: _fontSizeFor(rect) - 2,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dim.paint(
        canvas,
        Offset(rect.center.dx - dim.width / 2, top + tp.height + 3),
      );
    }
  }

  String _dimLabel(HousePlanRoom r) {
    final w = plan.unit == 'm' ? r.width / kMetersToFeet : r.width;
    final l = plan.unit == 'm' ? r.length / kMetersToFeet : r.length;
    return "${_fmt(w)}' × ${_fmt(l)}'";
  }

  String _fmt(double v) =>
      v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  double _fontSizeFor(Rect rect) {
    if (rect.width < 50 || rect.height < 34) return 8;
    if (rect.width < 90 || rect.height < 55) return 10;
    return 12;
  }

  void _northArrow(Canvas canvas, Size size) {
    final c = Offset(size.width - 34, 34);
    final p = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final fill = Paint()..color = lineColor;
    final path = Path()
      ..moveTo(c.dx, c.dy - 14)
      ..lineTo(c.dx - 5, c.dy + 6)
      ..lineTo(c.dx, c.dy + 2)
      ..lineTo(c.dx + 5, c.dy + 6)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawCircle(c, 16, p);
    final tp = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: lineColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy + 8));
  }

  @override
  bool shouldRepaint(covariant BlueprintPainter old) =>
      old.plan != plan ||
      old.floor != floor ||
      old.selectedRoomId != selectedRoomId ||
      old.showDimensions != showDimensions ||
      old.showOpenings != showOpenings ||
      old.scale != scale;
}
