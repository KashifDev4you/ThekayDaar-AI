// =============================================================================
// plan_versions_screen.dart — blueprint version history (spec §14)
//
// Every SAVE in the editor creates a new immutable version snapshot under
// house_plans/{planId}/versions/{n}. This screen lets the client:
//   - view the list of versions (rooms / covered area per version)
//   - preview any version in the read-only blueprint viewer
//   - RESTORE a version (restore itself saves a NEW version — history is
//     never rewritten)
//   - compare a version against the current one (rooms + area deltas)
//
// Client-only surface (the contractor never receives plan history).
// =============================================================================

import 'package:flutter/material.dart';

import 'package:ali_app/house_planner/models/house_plan_models.dart';
import 'package:ali_app/house_planner/screens/blueprint_view_screen.dart';
import 'package:ali_app/house_planner/services/house_plan_service.dart';

class PlanVersionsScreen extends StatefulWidget {
  const PlanVersionsScreen({
    super.key,
    required this.planId,
    required this.currentVersion,
    this.projectTitle,
    this.onRestored,
  });

  final String planId;
  final int currentVersion;
  final String? projectTitle;

  /// Fired after a successful restore so the parent screen can reload its own
  /// copy of the plan.
  final void Function(HousePlan restoredPlan)? onRestored;

  @override
  State<PlanVersionsScreen> createState() => _PlanVersionsScreenState();
}

class _PlanVersionsScreenState extends State<PlanVersionsScreen> {
  bool _loading = true;
  String? _error;
  List<(int, HousePlan?)> _versions = [];
  int _currentVersion = 0;
  bool _restoring = false;

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _amberD = Color(0xFFA8861D);
  static const _amberL = Color(0xFFFBF6E3);
  static const _surface = Color(0xFFF7F5EF);
  static const _white = Colors.white;
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _red = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _currentVersion = widget.currentVersion;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final versions = await HousePlanService.listVersions(widget.planId);
      if (!mounted) return;
      setState(() {
        _versions = versions;
        // 0 / unknown → treat the newest snapshot as current.
        _currentVersion = widget.currentVersion > 0
            ? widget.currentVersion
            : (versions.isNotEmpty ? versions.last.$1 : 0);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load versions. Check your connection and retry.';
        _loading = false;
      });
    }
  }

  Future<void> _restore(int version, HousePlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Restore version $version?',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Text(
          'The current blueprint will be kept in history — restoring saves it '
          'as a new version.',
          style: const TextStyle(fontSize: 12.5, height: 1.5, color: _textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: _white,
                elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _restoring = true);
    try {
      await HousePlanService.restoreVersion(widget.planId, version);
      final fresh = await HousePlanService.listVersions(widget.planId);
      if (!mounted) return;
      setState(() {
        _versions = fresh;
        _currentVersion = fresh.isNotEmpty ? fresh.last.$1 : _currentVersion;
        _restoring = false;
      });
      widget.onRestored?.call(plan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Version $version restored — saved as version $_currentVersion'),
            backgroundColor: _navy,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _restoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Restore failed: $e'), backgroundColor: _red),
      );
    }
  }

  void _preview(HousePlan plan, int version) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlueprintViewScreen(
          plan: plan,
          projectTitle:
              '${widget.projectTitle ?? 'AI House Plan'} — v$version preview',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Plan Versions',
            style: TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : _error != null
              ? _errorView()
              : _versions.isEmpty
                  ? _emptyView()
                  : _listView(),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42, color: _textSec),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, color: _textSec)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: _white,
                    elevation: 0),
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _emptyView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 44, color: _textSec),
            const SizedBox(height: 10),
            const Text('No versions yet',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _navy)),
            const SizedBox(height: 4),
            const Text(
              'Every time you save changes in the blueprint editor,\n'
              'a new version appears here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5, height: 1.6, color: _textSec),
            ),
          ],
        ),
      );

  Widget _listView() {
    // newest first
    final versions = _versions.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: versions.length,
      itemBuilder: (_, i) {
        final (version, plan) = versions[i];
        final isCurrent = version == _currentVersion;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isCurrent ? _amber : _border,
                width: isCurrent ? 1.4 : 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: plan != null ? () => _preview(plan, version) : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isCurrent ? _amber : _amberL,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'VERSION $version',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: isCurrent ? _navy : _amberD,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isCurrent)
                          const Text('current',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: _textSec)),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            size: 20,
                            color: plan != null ? _navy : _border),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (plan != null) ...[
                      Text(
                        '${plan.totalRooms} rooms · '
                        '${plan.coveredArea.round()} sq ft covered · '
                        '${plan.floors.length} floor${plan.floors.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _navy),
                      ),
                      const SizedBox(height: 4),
                      _compareWithCurrent(plan),
                    ] else
                      const Text(
                        'Version snapshot unreadable',
                        style: TextStyle(fontSize: 12.5, color: _textSec),
                      ),
                    if (plan != null && !isCurrent) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _smallBtn(
                            Icons.visibility_rounded,
                            'Preview',
                            () => _preview(plan, version),
                          ),
                          const SizedBox(width: 8),
                          _smallBtn(
                            Icons.restore_rounded,
                            _restoring ? 'Restoring…' : 'Restore',
                            _restoring ? null : () => _restore(version, plan),
                            filled: true,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Compact "compare" (spec §14 — "compare version if practical"): rooms and
  /// covered-area delta vs the CURRENT plan.
  Widget _compareWithCurrent(HousePlan plan) {
    final current = _versions
        .where((v) => v.$1 == _currentVersion && v.$2 != null)
        .map((v) => v.$2!)
        .firstOrNull;
    if (current == null) return const SizedBox.shrink();

    final roomDelta = plan.totalRooms - current.totalRooms;
    final areaDelta = plan.coveredArea - current.coveredArea;

    String deltaLabel(int v, String unit) {
      if (v == 0) return 'same $unit';
      final sign = v > 0 ? '+' : '';
      return '$sign$v $unit';
    }

    return Text(
      'vs current: ${deltaLabel(roomDelta, 'rooms')} · '
      '${areaDelta == 0 ? 'same area' : '${areaDelta > 0 ? '+' : ''}${areaDelta.round()} sq ft'}',
      style: const TextStyle(fontSize: 11, color: _textSec),
    );
  }

  Widget _smallBtn(IconData icon, String label, VoidCallback? onTap,
      {bool filled = false}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: filled ? _navy : _navy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: filled ? _white : _navy),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: filled ? _white : _navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
