// =============================================================================
// blueprint_view_screen.dart — 2D blueprint viewer (spec §12, §26)
//
// Hosts BlueprintPainter inside an InteractiveViewer (zoom/pan/reset), with
// floor tabs, dimension toggle, a room-dimensions summary sheet, the
// architectural-safety disclaimer (spec §34), and entry buttons to the
// editor / 3D / 360 screens.
//
// [mode] drives role behaviour:
//   client    → EDIT / 3D / 360 buttons visible
//   contractor→ read-only; construction data only, no 3D/360 (spec §28)
// =============================================================================

import 'package:flutter/material.dart';

import 'package:ali_app/house_planner/models/house_plan_models.dart';
import 'package:ali_app/house_planner/widgets/blueprint_painter.dart';
import 'package:ali_app/house_planner/widgets/house3d_painter.dart';
import 'package:ali_app/house_planner/screens/blueprint_editor_screen.dart';
import 'package:ali_app/house_planner/screens/panorama_screen.dart';
import 'package:ali_app/house_planner/screens/plan_versions_screen.dart';

enum BlueprintViewerMode { client, contractor }

class BlueprintViewScreen extends StatefulWidget {
  const BlueprintViewScreen({
    super.key,
    required this.plan,
    this.mode = BlueprintViewerMode.client,
    this.planId,
    this.currentVersion = 0, // 0 → resolved as "latest" in the versions screen
    this.projectTitle,
    this.onPlanEdited,
  });

  final HousePlan plan;
  final BlueprintViewerMode mode;
  final String? planId; // null while still in the wizard (unsaved)
  final int currentVersion;
  final String? projectTitle;
  final void Function(HousePlan)? onPlanEdited;

  @override
  State<BlueprintViewScreen> createState() => _BlueprintViewScreenState();
}

class _BlueprintViewScreenState extends State<BlueprintViewScreen> {
  late HousePlan _plan;
  late final TransformationController _xf;
  int _floor = 0;
  bool _showDims = true;

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _amberD = Color(0xFFA8861D);
  static const _amberL = Color(0xFFFBF6E3);
  static const _surface = Color(0xFFF7F5EF);
  static const _white = Colors.white;
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _floor = _plan.floors.isNotEmpty ? _plan.floors.first.floor : 0;
    _xf = TransformationController();
  }

  @override
  void dispose() {
    _xf.dispose();
    super.dispose();
  }

  double get _pxPerFt {
    final longSide = _plan.plotWidthFt > _plan.plotLengthFt
        ? _plan.plotWidthFt
        : _plan.plotLengthFt;
    return (longSide > 0) ? 620 / longSide : 6;
  }

  @override
  Widget build(BuildContext context) {
    final isClient = widget.mode == BlueprintViewerMode.client;
    final floorLabel = HousePlanFloor.floorLabel(_floor);
    final roomCount = _plan.roomsOn(_floor).length;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.projectTitle ?? 'AI House Plan',
              style: const TextStyle(
                  color: _white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${_plan.plotWidthFt.round()} × ${_plan.plotLengthFt.round()} ft · '
              '$floorLabel · $roomCount rooms',
              style: const TextStyle(color: _amber, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── floor tabs ────────────────────────────────────────
          if (_plan.floors.length > 1)
            Container(
              color: _white,
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: _navy,
                      unselectedLabelColor: _textSec,
                      indicatorColor: _amber,
                      indicatorSize: TabBarIndicatorSize.label,
                      onTap: (i) =>
                          setState(() => _floor = _plan.floors[i].floor),
                      tabs: _plan.floors
                          .map((f) => Tab(
                                text: HousePlanFloor.floorLabel(f.floor)
                                    .replaceAll(' Floor', ''),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),

          // ── toolbar (spec §26) ────────────────────────────────
          Container(
            color: _white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _tool(Icons.add_rounded, 'Zoom +', () => _zoom(1.3)),
                const SizedBox(width: 6),
                _tool(Icons.remove_rounded, 'Zoom −', () => _zoom(1 / 1.3)),
                const SizedBox(width: 6),
                _tool(Icons.restart_alt_rounded, 'Reset', _reset),
                const SizedBox(width: 6),
                _tool(
                  Icons.straighten_rounded,
                  _showDims ? 'Hide dims' : 'Dims',
                  () => setState(() => _showDims = !_showDims),
                  active: _showDims,
                ),
                const Spacer(),
                // generation provenance badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _amberL,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _plan.generatedBy == 'ai' ? 'AI plan' : 'Built-in planner',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _amberD,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── blueprint canvas ──────────────────────────────────
          Expanded(
            child: InteractiveViewer(
              transformationController: _xf,
              minScale: 0.4,
              maxScale: 6,
              boundaryMargin: const EdgeInsets.all(80),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FittedBox(
                  child: SizedBox(
                    width: _plan.plotWidthFt * _pxPerFt + 80,
                    height: _plan.plotLengthFt * _pxPerFt + 80,
                    child: CustomPaint(
                      painter: BlueprintPainter(
                        plan: _plan,
                        floor: _floor,
                        scale: _pxPerFt,
                        showDimensions: _showDims,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── disclaimer (spec §34) ─────────────────────────────
          Container(
            color: _amberL,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: _amberD),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'AI-generated house plans are conceptual. Final construction '
                    'drawings must be prepared by a qualified architect/engineer.',
                    style: TextStyle(fontSize: 10, height: 1.4, color: _textSec),
                  ),
                ),
              ],
            ),
          ),

          // ── bottom actions ────────────────────────────────────
          Container(
            color: _white,
            padding: EdgeInsets.fromLTRB(
                14, 10, 14, 10 + MediaQuery.of(context).padding.bottom),
            child: Column(
              children: [
                if (isClient) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _action(
                          Icons.edit_rounded,
                          'EDIT BLUEPRINT',
                          const Color(0xFF0E3B2E),
                          _openEditor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _action(
                          Icons.view_in_ar_rounded,
                          'GENERATE 3D',
                          _amberD,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => House3dViewerScreen(
                                  plan: _plan, floor: _floor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _action(
                          Icons.threesixty_rounded,
                          'VIEW 360',
                          _amberD,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PanoramaScreen(plan: _plan, floor: _floor),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.planId != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _openVersions,
                        icon: const Icon(Icons.history_rounded,
                            size: 16, color: _amberD),
                        label: Text(
                          'VERSION HISTORY',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: _amberD),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  // Contractor: dimensions table + no 3D/360 (spec §28)
                  SizedBox(
                    width: double.infinity,
                    child: _action(
                      Icons.table_rows_rounded,
                      'ROOM DIMENSIONS',
                      _amberD,
                      _showDimensionsSheet,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── toolbar helpers ─────────────────────────────────────────

  void _zoom(double factor) {
    final m = _xf.value;
    final scale = (m.getMaxScaleOnAxis() * factor).clamp(0.4, 6.0);
    _xf.value = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(m.getTranslation().x, m.getTranslation().y)
      // ignore: deprecated_member_use
      ..scale(scale);
  }

  void _reset() => _xf.value = Matrix4.identity();

  void _openEditor() async {
    final edited = await Navigator.push<HousePlan>(
      context,
      MaterialPageRoute(
        builder: (_) => BlueprintEditorScreen(
          plan: _plan.copy(),
          floor: _floor,
          planId: widget.planId,
        ),
      ),
    );
    if (edited != null) {
      setState(() => _plan = edited);
      widget.onPlanEdited?.call(edited);
    }
  }

  void _openVersions() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanVersionsScreen(
          planId: widget.planId!,
          currentVersion: widget.currentVersion,
          projectTitle: widget.projectTitle,
          onRestored: (restored) {
            setState(() => _plan = restored);
            widget.onPlanEdited?.call(restored);
          },
        ),
      ),
    );
  }

  void _showDimensionsSheet() {
    final rooms = _plan.roomsOn(_floor);
    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${HousePlanFloor.floorLabel(_floor)} — Room Dimensions',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: _navy),
          ),
          const SizedBox(height: 12),
          ...rooms.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(r.name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _navy)),
                    ),
                    Expanded(
                      child: Text(
                        "${r.width.round()}' × ${r.length.round()}'",
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _amberD),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${r.area.round()} sq ft',
                        textAlign: TextAlign.right,
                        style:
                            const TextStyle(fontSize: 12, color: _textSec),
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(color: _border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Covered area (this floor)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _navy)),
              Text(
                '${_plan.floors[_plan.floorIndexOf(_floor)].coveredArea.round()} sq ft',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: _amberD),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── widgets ─────────────────────────────────────────────────

  Widget _tool(IconData icon, String label, VoidCallback onTap,
      {bool active = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _amberL : _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? _amberD : _navy),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? _amberD : _navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}
