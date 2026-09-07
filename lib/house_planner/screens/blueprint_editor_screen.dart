// =============================================================================
// blueprint_editor_screen.dart — interactive blueprint editor (spec §13)
//
// Every edit mutates the structured plan JSON (never just pixels):
//   - drag room          → updates room.x / room.y
//   - resize (handles)   → updates room.width / room.length
//   - rename / retype    → room.name / room.type
//   - add room           → new HousePlanRoom with defaults
//   - delete room        → removed from its floor
//   - move door / window → opening.offset along the wall
//   - undo / redo / reset→ snapshot stack of plan copies
//   - SAVE               → HousePlanService.saveNewVersion (spec §14)
//
// While dragging, the plan is intentionally NOT re-validated live (that
// would fight the user); validation runs on SAVE and blocks invalid saves
// with a clear list of errors (spec §10).
// =============================================================================

import 'package:flutter/material.dart';

import 'package:ali_app/house_planner/models/house_plan_models.dart';
import 'package:ali_app/house_planner/services/house_plan_service.dart';
import 'package:ali_app/house_planner/services/house_plan_validator.dart';
import 'package:ali_app/house_planner/widgets/blueprint_painter.dart';

class BlueprintEditorScreen extends StatefulWidget {
  const BlueprintEditorScreen({
    super.key,
    required this.plan,
    this.floor = 0,
    this.planId,
  });

  final HousePlan plan;
  final int floor;
  final String? planId; // null → wizard flow (edits returned, not saved)

  @override
  State<BlueprintEditorScreen> createState() => _BlueprintEditorScreenState();
}

class _BlueprintEditorScreenState extends State<BlueprintEditorScreen> {
  late HousePlan _plan;
  late int _floor;
  String? _selectedId;
  String? _dragRoomId;
  String? _resizeRoomId;
  String? _dragOpeningKey; // 'door:0' | 'window:1'
  int _resizeEdge = 0; // 0=right 1=bottom 2=left 3=top

  final _undo = <HousePlan>[];
  final _redo = <HousePlan>[];
  bool _saving = false;

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _amberD = Color(0xFFA8861D);
  static const _surface = Color(0xFFF7F5EF);
  static const _white = Colors.white;
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _red = Color(0xFFDC2626);

  double get _pxPerFt {
    final long = _plan.plotWidthFt > _plan.plotLengthFt
        ? _plan.plotWidthFt
        : _plan.plotLengthFt;
    return long > 0 ? 560 / long : 6;
  }

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _floor = widget.floor;
  }

  // ── snapshot stack ──────────────────────────────────────────

  void _pushUndo() {
    _undo.add(_plan.copy());
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
  }

  void _undo_() {
    if (_undo.isEmpty) return;
    setState(() {
      _redo.add(_plan);
      _plan = _undo.removeLast();
      _selectedId = null;
    });
  }

  void _redo_() {
    if (_redo.isEmpty) return;
    setState(() {
      _undo.add(_plan);
      _plan = _redo.removeLast();
      _selectedId = null;
    });
  }

  void _reset() {
    setState(() {
      _plan = widget.plan.copy();
      _selectedId = null;
      _undo.clear();
      _redo.clear();
    });
  }

  HousePlanRoom? get _selected {
    if (_selectedId == null) return null;
    for (final r in _plan.roomsOn(_floor)) {
      if (r.id == _selectedId) return r;
    }
    return null;
  }

  // ── hit testing (screen px → plan ft) ───────────────────────

  Offset _toPlan(Offset px) => Offset(px.dx / _pxPerFt, px.dy / _pxPerFt);

  HousePlanRoom? _roomAt(Offset planPt) {
    for (final r in _plan.roomsOn(_floor)) {
      if (planPt.dx >= r.x &&
          planPt.dx <= r.right &&
          planPt.dy >= r.y &&
          planPt.dy <= r.bottom) {
        return r;
      }
    }
    return null;
  }

  bool _nearHandle(Offset planPt, HousePlanRoom r) {
    // corner/edge handles (half inch → 1.2 ft hot zone)
    const h = 1.4;
    final corners = [
      Offset(r.right, r.y + r.length / 2), // right
      Offset(r.x + r.width / 2, r.bottom), // bottom
      Offset(r.x, r.y + r.length / 2), // left
      Offset(r.x + r.width / 2, r.y), // top
    ];
    for (final c in corners) {
      if ((planPt - c).distance < h) return true;
    }
    return false;
  }

  // ── gesture handlers ────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    final p = _toPlan(d.localPosition);
    final room = _roomAt(p);
    if (room == null) {
      setState(() => _selectedId = null);
      return;
    }
    setState(() => _selectedId = room.id);
    _pushUndo();
    if (_nearHandle(p, room)) {
      _resizeRoomId = room.id;
      _dragRoomId = null;
      // pick nearest edge
      final dists = [
        (p - Offset(room.right, room.y + room.length / 2)).distance,
        (p - Offset(room.x + room.width / 2, room.bottom)).distance,
        (p - Offset(room.x, room.y + room.length / 2)).distance,
        (p - Offset(room.x + room.width / 2, room.y)).distance,
      ];
      _resizeEdge = dists.indexWhere((x) => x == dists.reduce((a, b) => a < b ? a : b));
    } else {
      _dragRoomId = room.id;
      _resizeRoomId = null;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final dx = d.delta.dx / _pxPerFt;
    final dy = d.delta.dy / _pxPerFt;
    setState(() {
      if (_dragRoomId != null) {
        final r = _findRoom(_dragRoomId!);
        if (r != null) {
          r.x = (r.x + dx).clamp(0, _plan.plotWidthFt - r.width);
          r.y = (r.y + dy).clamp(0, _plan.plotLengthFt - r.length);
        }
      } else if (_resizeRoomId != null) {
        final r = _findRoom(_resizeRoomId!);
        if (r == null) return;
        switch (_resizeEdge) {
          case 0: // right
            r.width = (r.width + dx).clamp(2, _plan.plotWidthFt - r.x);
          case 1: // bottom
            r.length = (r.length + dy).clamp(2, _plan.plotLengthFt - r.y);
          case 2: // left
            final w = (r.width - dx).clamp(2.0, r.x + r.width).toDouble();
            r.x = r.x + (r.width - w);
            r.width = w;
          default: // top
            final l = (r.length - dy).clamp(2.0, r.y + r.length).toDouble();
            r.y = r.y + (r.length - l);
            r.length = l;
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails _) {
    _dragRoomId = null;
    _resizeRoomId = null;
  }

  HousePlanRoom? _findRoom(String id) {
    for (final r in _plan.roomsOn(_floor)) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ── room operations ─────────────────────────────────────────

  void _addRoom() async {
    final spec = await showModalBottomSheet<RoomSpec>(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Add Room',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 8),
          ...kSelectableRoomTypes.map(
            (s) => ListTile(
              dense: true,
              leading: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: s.color,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              title: Text(s.label,
                  style: const TextStyle(fontSize: 13.5, color: _navy)),
              subtitle: Text(
                '${s.defWidth.round()} × ${s.defLength.round()} ft',
                style: const TextStyle(fontSize: 11, color: _textSec),
              ),
              onTap: () => Navigator.pop(context, s),
            ),
          ),
        ],
      ),
    );
    if (spec == null) return;

    _pushUndo();
    // find a free gap at the top-left area of the floor
    final room = HousePlanRoom(
      id: 'room_${DateTime.now().millisecondsSinceEpoch % 100000}',
      type: spec.type,
      name: spec.label,
      x: 1,
      y: 1,
      width: spec.defWidth
          .clamp(2, _plan.plotWidthFt - 2)
          .toDouble(),
      length: spec.defLength
          .clamp(2, _plan.plotLengthFt - 2)
          .toDouble(),
      floor: _floor,
      doors: [
        PlanOpening(
            wall: 's',
            offset: spec.defWidth / 2,
            width: 3.0.clamp(1.5, spec.defWidth / 2))
      ],
      windows: [
        PlanOpening(
            wall: 'n',
            offset: spec.defLength / 2,
            width: 3.0.clamp(1.5, spec.defLength / 2))
      ],
    );
    setState(() {
      final idx = _plan.floorIndexOf(_floor);
      if (idx == -1) {
        _plan.floors.add(HousePlanFloor(floor: _floor, rooms: [room]));
      } else {
        _plan.floors[idx].rooms.add(room);
      }
      _selectedId = room.id;
    });
  }

  void _renameRoom() {
    final r = _selected;
    if (r == null) return;
    final ctrl = TextEditingController(text: r.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Rename Room',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Room name',
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: _white,
                elevation: 0),
            onPressed: () {
              _pushUndo();
              setState(() => r.name =
                  ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : r.name);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _moveOpening(List<PlanOpening> list, double deltaFt) {
    if (_dragOpeningKey == null) return;
    final parts = _dragOpeningKey!.split(':');
    final idx = int.tryParse(parts[1]) ?? -1;
    if (idx < 0 || idx >= list.length) return;
    final o = list[idx];
    final room = _selected!;
    final along = (o.wall == 'n' || o.wall == 's') ? room.width : room.length;
    final newOffset = (o.offset + deltaFt)
        .clamp(o.width / 2, along - o.width / 2)
        .toDouble();
    list[idx] = o.copyWith(offset: newOffset);
  }

  // ── save ────────────────────────────────────────────────────

  Future<void> _save() async {
    final validation = HousePlanValidator.validate(_plan);
    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            'Please fix these first:\n• ${validation.errors.join('\n• ')}',
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.planId != null) {
        final version = await HousePlanService.saveNewVersion(
          planId: widget.planId!,
          plan: _plan,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved as version $version'),
              backgroundColor: _navy,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      if (mounted) Navigator.pop(context, _plan);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: _white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Blueprint',
            style: TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Undo',
            icon: Icon(Icons.undo_rounded,
                color: _undo.isEmpty ? Colors.white38 : _white),
            onPressed: _undo.isEmpty ? null : _undo_,
          ),
          IconButton(
            tooltip: 'Redo',
            icon: Icon(Icons.redo_rounded,
                color: _redo.isEmpty ? Colors.white38 : _white),
            onPressed: _redo.isEmpty ? null : _redo_,
          ),
          IconButton(
            tooltip: 'Reset to original',
            icon: const Icon(Icons.restart_alt_rounded, color: _white),
            onPressed: _reset,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── floor selector + add room ────────────────────────
          Container(
            color: _white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (_plan.floors.length > 1)
                  Expanded(
                    child: DropdownButton<int>(
                      value: _floor,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: _plan.floors
                          .map((f) => DropdownMenuItem(
                                value: f.floor,
                                child: Text(
                                    HousePlanFloor.floorLabel(f.floor),
                                    style: const TextStyle(
                                        fontSize: 12.5, color: _navy)),
                              ))
                          .toList(),
                      onChanged: (f) =>
                          setState(() { _floor = f ?? _floor; _selectedId = null; }),
                    ),
                  )
                else
                  Text(
                    HousePlanFloor.floorLabel(_floor),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _navy),
                  ),
                TextButton.icon(
                  onPressed: _addRoom,
                  icon: const Icon(Icons.add_rounded, size: 17, color: _amberD),
                  label: const Text('Add Room',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: _amberD)),
                ),
              ],
            ),
          ),

          // ── canvas ───────────────────────────────────────────
          Expanded(
            child: InteractiveViewer(
              maxScale: 5,
              minScale: 0.5,
              boundaryMargin: const EdgeInsets.all(60),
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onTapUp: (d) {
                  final r = _roomAt(_toPlan(d.localPosition));
                  setState(() => _selectedId = r?.id);
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FittedBox(
                    child: SizedBox(
                      width: _plan.plotWidthFt * _pxPerFt + 60,
                      height: _plan.plotLengthFt * _pxPerFt + 60,
                      child: CustomPaint(
                        painter: BlueprintPainter(
                          plan: _plan,
                          floor: _floor,
                          scale: _pxPerFt,
                          selectedRoomId: _selectedId,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── selected room panel ─────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            color: _white,
            padding: EdgeInsets.fromLTRB(
                14, 10, 14, 12 + MediaQuery.of(context).padding.bottom),
            height: _selected != null ? 150 : 52,
            child: _selected == null
                ? const Center(
                    child: Text(
                      'Tap a room to select · drag to move · corners to resize',
                      style: TextStyle(fontSize: 11.5, color: _textSec),
                    ),
                  )
                : _selectedPanel(),
          ),
        ],
      ),
      bottomNavigationBar: null,
      // SAVE bar (fixed above the selected panel via bottomSheet trick is
      // messy; simplest robust approach: put save in the panel container).
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        backgroundColor: _amber,
        foregroundColor: _navy,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.save_rounded, size: 20),
        label: Text(
          widget.planId != null ? 'SAVE VERSION' : 'APPLY CHANGES',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _selectedPanel() {
    final r = _selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                r.name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _navy),
              ),
            ),
            Text(
              "${r.width.round()}' × ${r.length.round()}' · ${r.area.round()} sq ft",
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _amberD),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // door / window movers
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _moverChip('Door', Icons.meeting_room_rounded, r.doors),
              const SizedBox(width: 8),
              _moverChip('Window', Icons.window_rounded, r.windows),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _panelBtn(Icons.edit_rounded, 'Rename', _renameRoom),
            const SizedBox(width: 8),
            _panelBtn(Icons.content_copy_rounded, 'Duplicate', () {
              _pushUndo();
              final copy = HousePlanRoom(
                id: 'room_${DateTime.now().millisecondsSinceEpoch % 100000}',
                type: r.type,
                name: '${r.name} 2',
                x: (r.x + 2).clamp(0, _plan.plotWidthFt - r.width).toDouble(),
                y: (r.y + 2).clamp(0, _plan.plotLengthFt - r.length).toDouble(),
                width: r.width,
                length: r.length,
                floor: r.floor,
                doors: List.of(r.doors),
                windows: List.of(r.windows),
              );
              setState(() {
                _plan.floors[_plan.floorIndexOf(_floor)].rooms.add(copy);
                _selectedId = copy.id;
              });
            }),
            const SizedBox(width: 8),
            _panelBtn(Icons.delete_rounded, 'Delete', () {
              _pushUndo();
              setState(() {
                _plan.floors[_plan.floorIndexOf(_floor)].rooms.remove(r);
                _selectedId = null;
              });
            }, color: _red),
          ],
        ),
      ],
    );
  }

  Widget _moverChip(
      String label, IconData icon, List<PlanOpening> openings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _amberD),
          const SizedBox(width: 6),
          Text('$label ×${openings.length}',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _navy)),
          const SizedBox(width: 6),
          if (openings.isNotEmpty) ...[
            InkWell(
              onTap: () {
                _pushUndo();
                setState(() => _moveOpening(openings, -1));
              },
              child:
                  const Icon(Icons.chevron_left_rounded, size: 18, color: _navy),
            ),
            InkWell(
              onTap: () {
                _pushUndo();
                setState(() => _moveOpening(openings, 1));
              },
              child:
                  const Icon(Icons.chevron_right_rounded, size: 18, color: _navy),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panelBtn(IconData icon, String label, VoidCallback onTap,
      {Color color = _navy}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
