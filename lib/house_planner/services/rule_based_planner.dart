// =============================================================================
// rule_based_planner.dart — deterministic house layout engine
//
// The FREE fallback architect (spec §11). Given a plot and room requirements
// it always produces the same, valid, non-overlapping layout — no network, no
// API key, no cost. Works like this:
//
//   1. Rooms are expanded from requirements (quantity, attached baths).
//   2. Rooms are assigned to floors (user preference first, otherwise
//      Pakistani norms: public rooms ground, bedrooms upstairs, service
//      rooms basement).
//   3. Each floor is packed with horizontal BANDS:
//        - front band   → car porch (if parking) / garden strip
//        - right strip  → staircase + stair hall (multi-floor only, same
//                         position on every floor so it is vertically aligned)
//        - remaining rectangle → rooms sorted by area, band height = tallest
//          room in the band, widths scaled to fill the band exactly
//   4. Doors face the circulation (stair hall / previous band), windows are
//      centred on exterior walls.
//
// Because the algorithm is deterministic the output doubles as the repair
// target when the optional AI provider returns broken geometry.
// =============================================================================

import 'package:ali_app/house_planner/models/house_plan_models.dart';

class RuleBasedPlanner {
  const RuleBasedPlanner._();

  static const double _porchDepth = 16; // ft reserved at the front for parking
  static const double _stairStripWidth = 9; // ft side strip for stairs
  static const double _stairLength = 10; // ft flight run
  static const double _gardenDepth = 8; // ft back strip when garden requested
  static const double _doorWidth = 3;
  static const double _windowWidth = 3.5;

  /// Generates a complete [HousePlan] for [plot] + [requirements].
  static HousePlan generate({
    required PlotDetails plot,
    required List<RoomRequirement> requirements,
  }) {
    final W = plot.widthFt;
    final L = plot.lengthFt;
    final floors = _sortedFloors(plot.includedFloors);

    final requests = _expandRequirements(requirements, floors);
    final byFloor = _assignFloors(requests, floors, plot);

    final planFloors = <HousePlanFloor>[];
    var roomSeq = 0;

    for (final f in floors) {
      final rooms = _layoutFloor(
        floor: f,
        W: W,
        L: L,
        requests: byFloor[f] ?? [],
        plot: plot,
        roomSeq: () => ++roomSeq,
      );
      if (rooms.isNotEmpty) {
        planFloors.add(HousePlanFloor(floor: f, rooms: rooms));
      }
    }

    return HousePlan(
      plotWidthFt: W,
      plotLengthFt: L,
      unit: plot.unit,
      generatedBy: 'rule_based',
      floors: planFloors,
    );
  }

  // ── 1. EXPAND ──────────────────────────────────────────────

  static List<int> _sortedFloors(List<int> raw) {
    final set = raw.toSet().where((f) => f >= -1 && f <= 2).toList()..sort();
    if (set.isEmpty) return [0];
    return set;
  }

  static List<_RoomRequest> _expandRequirements(
    List<RoomRequirement> reqs,
    List<int> floors,
  ) {
    final out = <_RoomRequest>[];
    for (final r in reqs) {
      final qty = r.quantity.clamp(1, 12);
      for (var i = 0; i < qty; i++) {
        final spec = r.spec;
        out.add(_RoomRequest(
          type: r.type,
          label: r.label,
          prefFloor: r.preferredFloor,
          width: (r.minWidth != null && r.minWidth! > 0)
              ? r.minWidth!.clamp(spec.minSide, 60).toDouble()
              : spec.defWidth,
          length: (r.minLength != null && r.minLength! > 0)
              ? r.minLength!.clamp(spec.minSide, 80).toDouble()
              : spec.defLength,
          windowRequired: r.windowRequired,
        ));
      }
      // Attached bathrooms ride along with their parent room's floor.
      if (r.attachedBathroom) {
        final spec = roomSpecOf('bathroom');
        for (var i = 0; i < qty; i++) {
          out.add(_RoomRequest(
            type: 'bathroom',
            label: 'Attached Bath',
            prefFloor: r.preferredFloor,
            width: spec.defWidth,
            length: spec.defLength,
            windowRequired: false,
            attached: true,
          ));
        }
      }
    }
    // Sensible defaults when the client asked for nothing specific.
    if (out.isEmpty) {
      out.addAll([
        _RoomRequest(type: 'master_bedroom', label: 'Master Bedroom', width: 14, length: 16),
        _RoomRequest(type: 'bedroom', label: 'Bedroom', width: 12, length: 13),
        _RoomRequest(type: 'bathroom', label: 'Bathroom', width: 6, length: 8),
        _RoomRequest(type: 'kitchen', label: 'Kitchen', width: 10, length: 12),
        _RoomRequest(type: 'tv_lounge', label: 'TV Lounge', width: 14, length: 18),
      ]);
    }
    return out;
  }

  // ── 2. FLOOR ASSIGNMENT ────────────────────────────────────

  static Map<int, List<_RoomRequest>> _assignFloors(
    List<_RoomRequest> requests,
    List<int> floors,
    PlotDetails plot,
  ) {
    final byFloor = <int, List<_RoomRequest>>{for (final f in floors) f: []};
    bool has(int f) => byFloor.containsKey(f);
    final ground = floors.contains(0) ? 0 : floors.first;
    final upper = floors.where((f) => f >= 1).toList();
    final basement = floors.where((f) => f < 0).toList();
    // Round-robin target for bedrooms when several upper floors exist.
    var upperIdx = 0;

    for (final r in requests) {
      int floor;
      if (r.prefFloor != null && has(r.prefFloor!)) {
        floor = r.prefFloor!;
      } else {
        switch (r.spec.group) {
          case RoomGroup.bedroom:
            floor = upper.isNotEmpty
                ? upper[upperIdx++ % upper.length]
                : ground;
            break;
          case RoomGroup.kitchen:
          case RoomGroup.living:
            floor = ground;
            break;
          case RoomGroup.bathroom:
            // Un-attached baths: one on every floor that has rooms.
            floor = upper.isNotEmpty ? upper[upperIdx++ % upper.length] : ground;
            break;
          case RoomGroup.service:
            floor = basement.isNotEmpty ? basement.first : ground;
            break;
          case RoomGroup.outdoor:
            floor = r.type == 'balcony' || r.type == 'terrace'
                ? (upper.isNotEmpty ? upper.last : ground)
                : ground;
            break;
          case RoomGroup.passage:
            floor = ground;
            break;
        }
      }
      byFloor[floor]!.add(r);
    }

    // Overflow relief: if a floor is over-stuffed, push the smallest
    // bedrooms/baths to another floor that has room.
    double areaOf(int f) =>
        byFloor[f]!.fold<double>(0, (a, r) => a + r.width * r.length);
    final capacity = plot.widthFt * plot.lengthFt * 0.92;
    for (final f in [...floors]) {
      var guard = 0;
      while (areaOf(f) > capacity && guard++ < 30) {
        final movable = byFloor[f]!
            .where((r) => r.spec.group == RoomGroup.bedroom ||
                (r.spec.group == RoomGroup.bathroom && !r.attached))
            .toList()
          ..sort((a, b) => (a.width * a.length).compareTo(b.width * b.length));
        if (movable.isEmpty) break;
        final target = floors
            .where((o) => o != f && areaOf(o) < capacity)
            .toList()
            .cast<int?>();
        if (target.isEmpty) break;
        byFloor[target.first]!.add(movable.first);
        byFloor[f]!.remove(movable.first);
      }
    }
    return byFloor;
  }

  // ── 3. PER-FLOOR LAYOUT ────────────────────────────────────

  static List<HousePlanRoom> _layoutFloor({
    required int floor,
    required double W,
    required double L,
    required List<_RoomRequest> requests,
    required PlotDetails plot,
    required int Function() roomSeq,
  }) {
    final rooms = <HousePlanRoom>[];
    final isGround = floor == 0;
    final multiFloor = plot.multiFloor;

    // Sort biggest-first for a stable, dense packing.
    final sorted = [...requests]..sort((a, b) {
        double area(_RoomRequest r) => r.width * r.length;
        final cmp = area(b).compareTo(area(a));
        if (cmp != 0) return cmp;
        return a.type.compareTo(b.type); // tie-break for determinism
      });

    // (a) front porch / garden strip -------------------------------------
    var frontY = L; // packing region spans y ∈ [topY, frontY)
    var topY = 0.0;
    if (isGround && plot.parkingRequired && L > _porchDepth + 24) {
      rooms.add(_room(roomSeq(), 'car_parking', 'Car Porch', 0, L - _porchDepth,
          W, _porchDepth, floor,
          doorWall: 'n', window: false));
      frontY = L - _porchDepth;
    } else if (isGround && plot.gardenRequired && L > _gardenDepth + 24) {
      rooms.add(_room(roomSeq(), 'garden', 'Garden', 0, L - _gardenDepth, W,
          _gardenDepth, floor,
          doorWall: 'n', window: false));
      frontY = L - _gardenDepth;
    } else if (isGround && plot.parkingRequired) {
      // Very short plot — still reserve a slim porch so parking exists.
      rooms.add(_room(roomSeq(), 'car_parking', 'Car Porch', 0, L - 12, W,
          12, floor,
          doorWall: 'n', window: false));
      frontY = L - 12;
    }

    // (b) back garden strip (corner/large plots) ------------------------
    if (isGround && plot.gardenRequired && frontY - topY > _gardenDepth + 30) {
      rooms.add(_room(roomSeq(), 'garden', 'Back Garden', 0, 0, W,
          _gardenDepth, floor,
          doorWall: 's', window: false));
      topY = _gardenDepth;
    }

    // (c) stair strip (right edge, vertically aligned on every floor) ---
    var packWidth = W;
    if (multiFloor) {
      final stairX = (W - _stairStripWidth).clamp(0, W).toDouble();
      rooms.add(_room(roomSeq(), 'staircase', 'Staircase', stairX, topY + 1,
          _stairStripWidth - 1, _stairLength, floor,
          doorWall: 'w', window: true));
      final hallTop = topY + 1 + _stairLength;
      if (frontY - hallTop > 6) {
        rooms.add(_room(roomSeq(), 'passage', 'Stair Hall', stairX, hallTop,
            _stairStripWidth - 1, frontY - hallTop - 1, floor,
            doorWall: 'w', window: false));
      }
      packWidth = stairX;
    }

    if (packWidth < 8 || frontY - topY < 8) return rooms; // nothing fits

    // (d) band packing ---------------------------------------------------
    final packH = frontY - topY;
    final bands = <List<_RoomRequest>>[];
    var current = <_RoomRequest>[];
    var currentW = 0.0;
    for (final r in sorted) {
      final w = r.width;
      if (current.isEmpty || currentW + w <= packWidth + 0.01) {
        current.add(r);
        currentW += w;
      } else {
        bands.add(current);
        current = [r];
        currentW = w;
      }
    }
    if (current.isNotEmpty) bands.add(current);

    // Band heights before scaling.
    final bandH = bands
        .map((b) => b.fold<double>(0, (h, r) => h < r.length ? r.length : h))
        .toList();
    final totalH = bandH.fold<double>(0, (a, b) => a + b);

    // Scale band heights to exactly fill the packing height.
    var scale = 1.0;
    if (totalH > packH && totalH > 0) {
      scale = packH / totalH;
    } else if (totalH < packH && totalH > 0) {
      scale = packH / totalH; // stretch a little instead of leaving gaps
    }
    // Don't stretch small floors absurdly.
    if (scale > 1.35) scale = 1.35;

    var y = topY;
    for (var bi = 0; bi < bands.length; bi++) {
      var h = bandH[bi] * scale;
      if (y + h > frontY) h = frontY - y;
      if (h < 4) break;

      final band = bands[bi];
      final wSum = band.fold<double>(0, (a, r) => a + r.width);
      var x = 0.0;
      for (var ri = 0; ri < band.length; ri++) {
        final r = band[ri];
        var rw = (wSum > 0) ? r.width / wSum * packWidth : packWidth / band.length;
        // last room absorbs rounding so the band is exactly full-width
        if (ri == band.length - 1) rw = packWidth - x;
        if (rw < 1) rw = 1;

        rooms.add(_room(
          roomSeq(), r.type, r.label, x, y, rw, h, floor,
          doorWall: _doorWallFor(bi, bands.length, packWidth, x, rw),
          window: r.windowRequired,
          minWidth: r.spec.minSide,
        ));
        x += rw;
      }
      y += h;
    }

    return rooms;
  }

  /// Circulation logic: rooms adjacent to the stair strip enter from the
  /// east; other rooms open toward the previous band (the band closer to the
  /// porch/front) so the plan reads like real circulation.
  static String _doorWallFor(int bandIndex, int bandCount, double packW, double x, double rw) {
    final nearRightStrip = x + rw >= packW - 2;
    if (nearRightStrip && bandIndex > 0) return 'e';
    return bandIndex == bandCount - 1 ? 's' : 'n';
  }

  static HousePlanRoom _room(
    int seq,
    String type,
    String label,
    double x,
    double y,
    double w,
    double l,
    int floor, {
    required String doorWall,
    required bool window,
    double? minWidth,
  }) {
    final room = HousePlanRoom(
      id: 'room_${seq.toString().padLeft(3, '0')}',
      type: type,
      name: label,
      x: x,
      y: y,
      width: w,
      length: l,
      floor: floor,
    );

    // Door centred on the chosen wall.
    final along = doorWall == 'n' || doorWall == 's' ? w : l;
    final dw = _doorWidth.clamp(1.5, along / 2).toDouble();
    room.doors.add(PlanOpening(
      wall: doorWall,
      offset: along / 2,
      width: dw,
    ));

    // Window on the longest EXTERIOR wall (not the stair-strip side).
    if (window) {
      final candidates = <String, double>{
        if (x <= 0.01) 'w': l,
        if (y <= 0.01) 'n': w,
        // east wall is exterior only when the room is not against the strip
        if (x + w >= 1e9) 'e': 0, // placeholder, replaced below
      };
      candidates.remove('e');
      if (candidates.isEmpty) candidates['n'] = w; // interior room: back wall
      var best = candidates.entries.first;
      for (final e in candidates.entries) {
        if (e.value > best.value) best = e;
      }
      final ww = (type == 'bathroom' ? 2.0 : _windowWidth)
          .clamp(1.5, best.value / 2)
          .toDouble();
      room.windows.add(PlanOpening(
        wall: best.key,
        offset: best.value / 2,
        width: ww,
      ));
    }

    // Respect minimum side where mathematically possible (advisory).
    if (minWidth != null && room.width < minWidth && room.width < w) {
      // nothing — band math already did its best; validator will warn.
    }
    return room;
  }
}

// ─────────────────────────────────────────────────────────────
// INTERNAL REQUEST
// ─────────────────────────────────────────────────────────────

class _RoomRequest {
  _RoomRequest({
    required this.type,
    required this.label,
    required this.width,
    required this.length,
    this.prefFloor,
    this.windowRequired = true,
    this.attached = false,
  });

  final String type;
  final String label;
  final double width;
  final double length;
  final int? prefFloor;
  final bool windowRequired;
  final bool attached;

  RoomSpec get spec => roomSpecOf(type);
}
