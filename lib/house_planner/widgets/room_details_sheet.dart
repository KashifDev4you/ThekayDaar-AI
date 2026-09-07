// =============================================================================
// room_details_sheet.dart — full room description card (bottom sheet)
//
// Shows everything about one room in plain language: dimensions, area in
// Pakistani units (sq ft / sq yd gaz / Marla / Kanal), position on the plot
// (front / middle / back · left / centre / right), which outer walls touch
// the plot boundary, entrance doors with widths and wall side, windows with
// widths, and a short description of the room type.
//
// Shared by:
//   • the 360° walk-through "You are in …" chip   (panorama_screen)
//   • the 3D viewer room menu                     (house3d_painter)
//   • the blueprint viewer dimensions sheet       (blueprint_view_screen)
//   • the client project detail room chips        (client_project_detail)
// =============================================================================

import 'package:flutter/material.dart';

import 'package:ali_app/house_planner/models/house_plan_models.dart';
import 'package:ali_app/house_planner/utils/plot_units.dart';

const _navy = Color(0xFF0E3B2E);
const _amberD = Color(0xFFA8861D);
const _amberL = Color(0xFFFBF6E3);
const _surface = Color(0xFFF7F5EF);
const _white = Colors.white;
const _textSec = Color(0xFF5D6B64);
const _border = Color(0xFFE3E0D5);

Future<void> showRoomDetailsSheet(
  BuildContext context, {
  required HousePlanRoom room,
  required HousePlan plan,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: _white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.78,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            // grab handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // header
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: room.spec.color,
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    room.name,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _navy),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    HousePlanFloor.floorLabel(room.floor),
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _amberD),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _groupDescription(room),
              style: const TextStyle(
                  fontSize: 11.5, height: 1.4, color: _textSec),
            ),
            const SizedBox(height: 14),

            // dimensions hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _amberL,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    '${room.width.round()} × ${room.length.round()} ft',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _navy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    PlotUnits.formatArea(room.area),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                        color: _amberD),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _row(Icons.place_rounded, 'POSITION ON PLOT',
                _positionLabel(room, plan)),
            _row(Icons.crop_square_rounded, 'OUTER WALLS',
                _outerWalls(room, plan)),
            _row(Icons.door_front_door, 'ENTRANCE', _entrance(room)),
            _row(Icons.window_rounded, 'WINDOWS & VENTILATION',
                _windows(room)),

            if (room.spec.group == RoomGroup.outdoor) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: _amberD),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Open / semi-open space — not counted in the covered '
                        'area of the house.',
                        style: TextStyle(
                            fontSize: 11, height: 1.5, color: _textSec),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ── row card ─────────────────────────────────────────────────────────────

Widget _row(IconData icon, String label, String value) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: _amberD),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: _textSec)),
              const SizedBox(height: 3),
              Text(value,
                  style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: _navy)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── plain-language descriptions ──────────────────────────────────────────

String _groupDescription(HousePlanRoom r) => switch (r.spec.group) {
      RoomGroup.bedroom => 'Private sleeping area with space for beds and '
          'wardrobes.',
      RoomGroup.bathroom => 'Washroom / bath — plumbing wall required.',
      RoomGroup.kitchen => 'Cooking and food preparation area.',
      RoomGroup.living => 'Family living and gathering space.',
      RoomGroup.outdoor => 'Outdoor space — car porch, garden or terrace.',
      RoomGroup.passage => 'Circulation space connecting the rooms.',
      RoomGroup.service => 'Utility / service area (store, laundry, stairs).',
    };

/// 'n' = back, 's' = front (road side), 'w' = left, 'e' = right.
String _wallName(String w) => switch (w) {
      'n' => 'back wall',
      's' => 'front wall (road side)',
      'w' => 'left wall',
      'e' => 'right wall',
      _ => 'wall',
    };

String _positionLabel(HousePlanRoom r, HousePlan plan) {
  final cy = r.y + r.length / 2;
  final cx = r.x + r.width / 2;
  final v = cy > plan.plotLengthFt * 0.62
      ? 'front'
      : cy < plan.plotLengthFt * 0.38
          ? 'back'
          : 'middle';
  final h = cx > plan.plotWidthFt * 0.62
      ? 'right'
      : cx < plan.plotWidthFt * 0.38
          ? 'left'
          : 'centre';
  return 'Located at the $v · $h of the plot';
}

String _outerWalls(HousePlanRoom r, HousePlan plan) {
  final sides = <String>[];
  if (r.y <= 0.5) sides.add('back');
  if (r.bottom >= plan.plotLengthFt - 0.5) sides.add('front');
  if (r.x <= 0.5) sides.add('left');
  if (r.right >= plan.plotWidthFt - 0.5) sides.add('right');
  if (sides.isEmpty) {
    return 'None — interior room, no wall touches the plot boundary';
  }
  return 'On the plot boundary: ${sides.join(', ')} side(s) — natural light '
      'and ventilation possible from these walls';
}

String _entrance(HousePlanRoom r) {
  if (r.spec.group == RoomGroup.outdoor) {
    return 'Open space — direct access from the front of the plot';
  }
  if (r.doors.isEmpty) {
    return 'No separate door shown (open-plan access)';
  }
  return r.doors
      .map((d) => 'Door ${_dec(d.width)} ft wide · ${_wallName(d.wall)}')
      .join('\n');
}

String _windows(HousePlanRoom r) {
  if (r.spec.group == RoomGroup.outdoor) return 'Open to sky';
  if (r.windows.isEmpty) {
    return 'No window in this layout (interior wall)';
  }
  return r.windows
      .map((w) => 'Window ${_dec(w.width)} ft wide · ${_wallName(w.wall)}')
      .join('\n');
}

String _dec(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
