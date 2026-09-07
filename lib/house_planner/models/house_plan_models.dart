// =============================================================================
// house_plan_models.dart — AI House Planner data models
//
// The structured plan JSON is the SOURCE OF TRUTH for the blueprint, the
// editor, the procedural 3D model and the room-dimension tables. AI-generated
// imagery (when enabled) is purely conceptual and never used as geometry.
//
// Schema (see spec §9):
// {
//   "plot":     {"width": 30, "length": 60, "unit": "ft"},
//   "floors":   [{"floor": 0, "rooms": [ {id,type,name,x,y,width,length,
//                floor,doors:[{wall,offset,width}],windows:[...]} ]}],
//   "generatedBy": "rule_based" | "ai",
//   "schemaVersion": 1
// }
//
// All geometry is stored in FEET internally (meters are converted on input);
// the user's original unit is preserved in PlotDetails.unit.
// =============================================================================

import 'dart:ui' show Color;

/// Meters → feet.
const double kMetersToFeet = 3.280839895;

/// Anything below this (ft) is treated as a degenerate room.
const double kMinRoomSide = 3.0;

// ─────────────────────────────────────────────────────────────
// ROOM TYPE CATALOG
// ─────────────────────────────────────────────────────────────

class RoomSpec {
  const RoomSpec({
    required this.type,
    required this.label,
    required this.defWidth,
    required this.defLength,
    required this.color,
    required this.group,
    this.userSelectable = true,
    this.minSide = kMinRoomSide,
  });

  final String type; // snake_case key, e.g. 'master_bedroom'
  final String label; // human label, e.g. 'Master Bedroom'
  final double defWidth; // default size in ft
  final double defLength; // default size in ft
  final Color color; // light fill used by the blueprint painter
  final RoomGroup group; // drives floor assignment + rendering hints
  final bool userSelectable; // false → planner-internal types
  final double minSide; // minimum side in ft (parking needs more)
}

enum RoomGroup { bedroom, bathroom, kitchen, living, service, outdoor, passage }

const Color _cBedroom = Color(0xFFFDEBD0);
const Color _cBathroom = Color(0xFFD6EAF8);
const Color _cKitchen = Color(0xFFD5F5E3);
const Color _cLiving = Color(0xFFFCF3CF);
const Color _cService = Color(0xFFF2F4F4);
const Color _cOutdoor = Color(0xFFEAFAF1);
const Color _cPrayer = Color(0xFFF5EEF8);

const List<RoomSpec> kRoomCatalog = [
  RoomSpec(type: 'master_bedroom', label: 'Master Bedroom', defWidth: 14, defLength: 16, color: _cBedroom, group: RoomGroup.bedroom),
  RoomSpec(type: 'bedroom', label: 'Bedroom', defWidth: 12, defLength: 13, color: _cBedroom, group: RoomGroup.bedroom),
  RoomSpec(type: 'bathroom', label: 'Bathroom', defWidth: 6, defLength: 8, color: _cBathroom, group: RoomGroup.bathroom),
  RoomSpec(type: 'kitchen', label: 'Kitchen', defWidth: 10, defLength: 12, color: _cKitchen, group: RoomGroup.kitchen),
  RoomSpec(type: 'living_room', label: 'Living Room', defWidth: 13, defLength: 16, color: _cLiving, group: RoomGroup.living),
  RoomSpec(type: 'tv_lounge', label: 'TV Lounge', defWidth: 14, defLength: 18, color: _cLiving, group: RoomGroup.living),
  RoomSpec(type: 'drawing_room', label: 'Drawing Room', defWidth: 14, defLength: 16, color: _cLiving, group: RoomGroup.living),
  RoomSpec(type: 'dining_room', label: 'Dining Room', defWidth: 10, defLength: 12, color: _cLiving, group: RoomGroup.living),
  RoomSpec(type: 'guest_room', label: 'Guest Room', defWidth: 11, defLength: 12, color: _cBedroom, group: RoomGroup.bedroom),
  RoomSpec(type: 'study_room', label: 'Study Room', defWidth: 10, defLength: 10, color: _cService, group: RoomGroup.service),
  RoomSpec(type: 'office', label: 'Office', defWidth: 10, defLength: 10, color: _cService, group: RoomGroup.service),
  RoomSpec(type: 'store', label: 'Store', defWidth: 6, defLength: 8, color: _cService, group: RoomGroup.service),
  RoomSpec(type: 'laundry', label: 'Laundry', defWidth: 6, defLength: 8, color: _cService, group: RoomGroup.service),
  RoomSpec(type: 'prayer_room', label: 'Prayer Room', defWidth: 8, defLength: 8, color: _cPrayer, group: RoomGroup.service),
  RoomSpec(type: 'garage', label: 'Garage', defWidth: 10, defLength: 18, color: _cOutdoor, group: RoomGroup.outdoor, minSide: 8),
  RoomSpec(type: 'car_parking', label: 'Car Porch', defWidth: 10, defLength: 18, color: _cOutdoor, group: RoomGroup.outdoor, minSide: 8),
  RoomSpec(type: 'staircase', label: 'Staircase', defWidth: 8, defLength: 10, color: _cService, group: RoomGroup.service, userSelectable: false),
  RoomSpec(type: 'balcony', label: 'Balcony', defWidth: 10, defLength: 4, color: _cOutdoor, group: RoomGroup.outdoor),
  RoomSpec(type: 'terrace', label: 'Terrace', defWidth: 12, defLength: 10, color: _cOutdoor, group: RoomGroup.outdoor),
  RoomSpec(type: 'courtyard', label: 'Courtyard', defWidth: 10, defLength: 12, color: _cOutdoor, group: RoomGroup.outdoor),
  RoomSpec(type: 'garden', label: 'Garden', defWidth: 12, defLength: 10, color: _cOutdoor, group: RoomGroup.outdoor),
  RoomSpec(type: 'other', label: 'Other Room', defWidth: 10, defLength: 10, color: _cService, group: RoomGroup.service),
  // Planner-internal circulation space between rooms and the stair strip.
  RoomSpec(type: 'passage', label: 'Passage', defWidth: 8, defLength: 10, color: _cService, group: RoomGroup.passage, userSelectable: false),
];

RoomSpec roomSpecOf(String type) => kRoomCatalog.firstWhere(
      (r) => r.type == type,
      orElse: () => kRoomCatalog.firstWhere((r) => r.type == 'other'),
    );

List<RoomSpec> get kSelectableRoomTypes =>
    kRoomCatalog.where((r) => r.userSelectable).toList();

// ─────────────────────────────────────────────────────────────
// OPENINGS (doors / windows)
// ─────────────────────────────────────────────────────────────

/// A door or window on one wall of a room.
///
/// [wall] is one of 'n' (back, y=0 side), 's' (front), 'w' (left, x=0 side),
/// 'e' (right). [offset] is the CENTER of the opening measured along the wall
/// from the room's min corner, in feet. [width] is the opening width in feet.
class PlanOpening {
  const PlanOpening({required this.wall, required this.offset, required this.width});

  final String wall;
  final double offset;
  final double width;

  Map<String, dynamic> toJson() => {'wall': wall, 'offset': offset, 'width': width};

  static PlanOpening fromJson(Map<String, dynamic> j) => PlanOpening(
        wall: (j['wall'] as String?) ?? 'n',
        offset: _asDouble(j['offset']),
        width: _asDouble(j['width']).clamp(1.5, 12),
      );

  PlanOpening copyWith({String? wall, double? offset, double? width}) =>
      PlanOpening(
        wall: wall ?? this.wall,
        offset: offset ?? this.offset,
        width: width ?? this.width,
      );

  static double _asDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}

// ─────────────────────────────────────────────────────────────
// ROOM
// ─────────────────────────────────────────────────────────────

class HousePlanRoom {
  HousePlanRoom({
    required this.id,
    required this.type,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.length,
    required this.floor,
    List<PlanOpening>? doors,
    List<PlanOpening>? windows,
  })  : doors = doors ?? [],
        windows = windows ?? [];

  final String id;
  String type;
  String name;
  double x, y, width, length;
  int floor;
  List<PlanOpening> doors;
  List<PlanOpening> windows;

  RoomSpec get spec => roomSpecOf(type);

  double get area => width * length;

  double get right => x + width;
  double get bottom => y + length;

  HousePlanRoom copy() => HousePlanRoom(
        id: id,
        type: type,
        name: name,
        x: x,
        y: y,
        width: width,
        length: length,
        floor: floor,
        doors: List.of(doors),
        windows: List.of(windows),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'x': _round(x),
        'y': _round(y),
        'width': _round(width),
        'length': _round(length),
        'floor': floor,
        'doors': doors.map((d) => d.toJson()).toList(),
        'windows': windows.map((w) => w.toJson()).toList(),
      };

  /// Lenient parser — clamps bad AI output instead of crashing (spec §10).
  static HousePlanRoom? fromJson(Map<String, dynamic> j) {
    final width = _pos(_asDouble(j['width']));
    final length = _pos(_asDouble(j['length']));
    if (width < 1 || length < 1) return null; // unrecoverable
    return HousePlanRoom(
      id: (j['id'] as String?)?.isNotEmpty == true
          ? j['id'] as String
          : 'room_${_asDouble(j['x']).round()}_${_asDouble(j['y']).round()}',
      type: (j['type'] as String?) ?? 'other',
      name: (j['name'] as String?)?.isNotEmpty == true
          ? j['name'] as String
          : roomSpecOf((j['type'] as String?) ?? 'other').label,
      x: _asDouble(j['x']),
      y: _asDouble(j['y']),
      width: width,
      length: length,
      floor: (j['floor'] is int) ? j['floor'] as int : 0,
      doors: _openings(j['doors']),
      windows: _openings(j['windows']),
    );
  }

  static List<PlanOpening> _openings(dynamic raw) => (raw as List? ?? [])
      .whereType<Map>()
      .map((m) => PlanOpening.fromJson(Map<String, dynamic>.from(m)))
      .toList();

  static double _asDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  static double _pos(double v) => v.isFinite && v > 0 ? v : 0;
}

double _round(double v) => (v * 100).round() / 100;

double _numOf(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

// ─────────────────────────────────────────────────────────────
// FLOOR + PLAN
// ─────────────────────────────────────────────────────────────

class HousePlanFloor {
  HousePlanFloor({required this.floor, required this.rooms});

  final int floor; // -1 basement, 0 ground, 1 first, 2 second
  List<HousePlanRoom> rooms;

  int get roomCount => rooms.length;
  double get coveredArea => rooms.fold(0, (a, r) => a + r.area);

  Map<String, dynamic> toJson() => {
        'floor': floor,
        'rooms': rooms.map((r) => r.toJson()).toList(),
      };

  static HousePlanFloor fromJson(Map<String, dynamic> j) => HousePlanFloor(
        floor: (j['floor'] is int) ? j['floor'] as int : 0,
        rooms: (j['rooms'] as List? ?? [])
            .whereType<Map>()
            .map((m) => HousePlanRoom.fromJson(Map<String, dynamic>.from(m)))
            .whereType<HousePlanRoom>()
            .toList(),
      );

  static String floorLabel(int f) {
    switch (f) {
      case -1:
        return 'Basement';
      case 0:
        return 'Ground Floor';
      case 1:
        return 'First Floor';
      case 2:
        return 'Second Floor';
      default:
        return 'Floor $f';
    }
  }
}

class HousePlan {
  HousePlan({
    required this.plotWidthFt,
    required this.plotLengthFt,
    required this.unit,
    required this.floors,
    this.generatedBy = 'rule_based',
    this.schemaVersion = 1,
  });

  final double plotWidthFt;
  final double plotLengthFt;
  String unit; // user-facing unit: 'ft' | 'm'
  final List<HousePlanFloor> floors;
  String generatedBy;
  int schemaVersion;

  int get totalRooms => floors.fold(0, (a, f) => a + f.roomCount);

  double get plotArea => plotWidthFt * plotLengthFt;

  double get coveredArea => floors.fold(0, (a, f) => a + f.coveredArea);

  List<HousePlanRoom> roomsOn(int floor) {
    final f = floorIndexOf(floor);
    return f == -1 ? <HousePlanRoom>[] : floors[f].rooms;
  }

  int floorIndexOf(int floor) {
    for (int i = 0; i < floors.length; i++) {
      if (floors[i].floor == floor) return i;
    }
    return -1;
  }

  HousePlan copy() => HousePlan(
        plotWidthFt: plotWidthFt,
        plotLengthFt: plotLengthFt,
        unit: unit,
        generatedBy: generatedBy,
        schemaVersion: schemaVersion,
        floors: floors
            .map((f) => HousePlanFloor(
                  floor: f.floor,
                  rooms: f.rooms.map((r) => r.copy()).toList(),
                ))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'plot': {'width': _round(plotWidthFt), 'length': _round(plotLengthFt), 'unit': 'ft'},
        'userUnit': unit,
        'floors': floors.map((f) => f.toJson()).toList(),
        'generatedBy': generatedBy,
        'schemaVersion': schemaVersion,
      };

  /// Lenient parser: accepts the AI schema (plot.width/length in ANY unit as
  /// long as rooms use the same unit) plus our own schema. Rooms outside the
  /// plot are clamped in; unreadable rooms are dropped — never crash (§10).
  static HousePlan? fromJson(Map<String, dynamic> j) {
    final plot = (j['plot'] as Map?) ?? const {};
    double w = _num(plot['width']);
    double l = _num(plot['length']);
    final unit = (j['userUnit'] as String?) ?? (plot['unit'] as String?) ?? 'ft';
    if (unit == 'm') {
      w *= kMetersToFeet;
      l *= kMetersToFeet;
    }
    if (w < 6 || l < 6) return null; // too small / unparseable

    final floors = (j['floors'] as List? ?? [])
        .whereType<Map>()
        .map((m) => HousePlanFloor.fromJson(Map<String, dynamic>.from(m)))
        .where((f) => f.rooms.isNotEmpty)
        .toList();
    if (floors.isEmpty) return null;

    final plan = HousePlan(
      plotWidthFt: w,
      plotLengthFt: l,
      unit: unit == 'm' ? 'm' : 'ft',
      generatedBy: (j['generatedBy'] as String?) ?? 'ai',
      schemaVersion: (j['schemaVersion'] is int) ? j['schemaVersion'] as int : 1,
      floors: floors,
    );
    plan.clampToPlot();
    return plan;
  }

  /// Repair pass: pull rooms back inside the plot (spec §10).
  void clampToPlot() {
    for (final f in floors) {
      for (final r in f.rooms) {
        r.width = r.width.clamp(1, plotWidthFt);
        r.length = r.length.clamp(1, plotLengthFt);
        r.x = r.x.clamp(0, plotWidthFt - r.width);
        r.y = r.y.clamp(0, plotLengthFt - r.length);
        r.floor = f.floor;
      }
    }
  }

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}

// ─────────────────────────────────────────────────────────────
// PLOT DETAILS (wizard input)
// ─────────────────────────────────────────────────────────────

class PlotDetails {
  PlotDetails({
    required this.width,
    required this.length,
    required this.unit,
    required this.includedFloors,
    this.facing = 'North',
    this.cornerPlot = false,
    this.parkingRequired = true,
    this.gardenRequired = false,
    this.frontRoadWidth,
  });

  double width; // in [unit]
  double length; // in [unit]
  String unit; // 'ft' | 'm'
  List<int> includedFloors; // e.g. [0], [0, 1], [-1, 0, 1, 2]
  String facing; // North / South / East / West
  bool cornerPlot;
  bool parkingRequired;
  bool gardenRequired;
  double? frontRoadWidth; // in [unit]

  double get widthFt => unit == 'm' ? width * kMetersToFeet : width;
  double get lengthFt => unit == 'm' ? length * kMetersToFeet : length;

  bool get multiFloor => includedFloors.where((f) => f >= 1).isNotEmpty;

  String get sizeLabel {
    final w = width.toStringAsFixed(width.truncateToDouble() == width ? 0 : 1);
    final l = length.toStringAsFixed(length.truncateToDouble() == length ? 0 : 1);
    return '$w × $l ${unit == 'm' ? 'm' : 'ft'}';
  }

  Map<String, dynamic> toJson() => {
        'width': width,
        'length': length,
        'unit': unit,
        'widthFt': widthFt,
        'lengthFt': lengthFt,
        'includedFloors': includedFloors,
        'facing': facing,
        'cornerPlot': cornerPlot,
        'parkingRequired': parkingRequired,
        'gardenRequired': gardenRequired,
        'frontRoadWidth': frontRoadWidth,
      };

  static PlotDetails fromJson(Map<String, dynamic> j) => PlotDetails(
        width: _numOf(j['width']),
        length: _numOf(j['length']),
        unit: (j['unit'] as String?) == 'm' ? 'm' : 'ft',
        includedFloors: (j['includedFloors'] as List? ?? [])
            .map((f) => f is int ? f : int.tryParse('$f') ?? 0)
            .toList(),
        facing: (j['facing'] as String?) ?? 'North',
        cornerPlot: j['cornerPlot'] == true,
        parkingRequired: j['parkingRequired'] != false,
        gardenRequired: j['gardenRequired'] == true,
        frontRoadWidth: j['frontRoadWidth'] == null
            ? null
            : _numOf(j['frontRoadWidth']),
      );
}

// ─────────────────────────────────────────────────────────────
// ROOM REQUIREMENT (wizard input)
// ─────────────────────────────────────────────────────────────

class RoomRequirement {
  RoomRequirement({
    required this.type,
    this.name,
    this.quantity = 1,
    this.minWidth,
    this.minLength,
    this.preferredFloor,
    this.attachedBathroom = false,
    this.windowRequired = true,
    this.notes = '',
  });

  final String type; // RoomSpec.type
  String? name; // custom display name
  int quantity;
  double? minWidth; // ft (user intent, advisory)
  double? minLength; // ft
  int? preferredFloor; // null = auto
  bool attachedBathroom;
  bool windowRequired;
  String notes;

  RoomSpec get spec => roomSpecOf(type);

  String get label => (name?.isNotEmpty == true) ? name! : spec.label;

  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'quantity': quantity,
        'minWidth': minWidth,
        'minLength': minLength,
        'preferredFloor': preferredFloor,
        'attachedBathroom': attachedBathroom,
        'windowRequired': windowRequired,
        'notes': notes,
      };

  static RoomRequirement fromJson(Map<String, dynamic> j) => RoomRequirement(
        type: (j['type'] as String?) ?? 'other',
        name: j['name'] as String?,
        quantity: (j['quantity'] is int)
            ? j['quantity'] as int
            : int.tryParse('${j['quantity']}') ?? 1,
        minWidth: j['minWidth'] == null ? null : _numOf(j['minWidth']),
        minLength: j['minLength'] == null ? null : _numOf(j['minLength']),
        preferredFloor: j['preferredFloor'] == null
            ? null
            : (j['preferredFloor'] is int
                ? j['preferredFloor'] as int
                : int.tryParse('${j['preferredFloor']}')),
        attachedBathroom: j['attachedBathroom'] == true,
        windowRequired: j['windowRequired'] != false,
        notes: (j['notes'] as String?) ?? '',
      );
}
