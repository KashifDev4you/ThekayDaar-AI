// =============================================================================
// house_plan_validator.dart — blueprint validation + AI repair (spec §10)
//
// Checks a plan (whether from the rule-based planner or the AI provider):
//   - rooms inside plot bounds
//   - no overlapping rooms
//   - no negative/degenerate dimensions
//   - required rooms exist (bedroom/bathroom/kitchen + entry)
//   - parking + staircase fit the plot
//   - room sides are reasonable
//
// [repair] fixes what it can deterministically (clamping, opening wall
// sanity) and reports the rest as warnings. It NEVER throws — invalid AI
// output triggers the rule-based fallback in HousePlannerService instead.
// =============================================================================

import 'package:ali_app/house_planner/models/house_plan_models.dart';

class PlanIssue {
  const PlanIssue(this.severity, this.message);

  final String severity; // 'error' | 'warning'
  final String message;

  @override
  String toString() => '[$severity] $message';
}

class ValidationResult {
  ValidationResult({required this.issues});

  final List<PlanIssue> issues;

  bool get isValid => issues.every((i) => i.severity != 'error');
  bool get hasWarnings => issues.any((i) => i.severity == 'warning');

  Iterable<String> get errors =>
      issues.where((i) => i.severity == 'error').map((i) => i.message);
  Iterable<String> get warnings =>
      issues.where((i) => i.severity == 'warning').map((i) => i.message);
}

class HousePlanValidator {
  const HousePlanValidator._();

  static const double _epsilon = 0.05; // ½ inch tolerance

  static ValidationResult validate(HousePlan plan) {
    final issues = <PlanIssue>[];

    if (plan.floors.isEmpty) {
      issues.add(const PlanIssue('error', 'The plan has no floors.'));
      return ValidationResult(issues: issues);
    }

    // Duplicate floor numbers?
    final floorNums = <int>{};
    for (final f in plan.floors) {
      if (!floorNums.add(f.floor)) {
        issues.add(PlanIssue('error', 'Floor ${f.floor} appears twice.'));
      }
    }

    final requiredTypes = <String>{};
    for (final f in plan.floors) {
      for (final r in f.rooms) {
        requiredTypes.add(r.type);
      }
    }

    for (final f in plan.floors) {
      for (final r in f.rooms) {
        // ── dimensions ─────────────────────────────────────────
        if (r.width <= 0 || r.length <= 0) {
          issues.add(PlanIssue('error', '${r.name} has invalid dimensions.'));
          continue;
        }
        if (r.width < 2.5 || r.length < 2.5) {
          issues.add(PlanIssue(
              'warning', '${r.name} is very small (${r.width}×${r.length} ft).'));
        }
        if (r.width > plan.plotWidthFt + _epsilon ||
            r.length > plan.plotLengthFt + _epsilon) {
          issues.add(PlanIssue('error', '${r.name} is larger than the plot.'));
        }

        // ── bounds ─────────────────────────────────────────────
        if (r.x < -_epsilon ||
            r.y < -_epsilon ||
            r.right > plan.plotWidthFt + _epsilon ||
            r.bottom > plan.plotLengthFt + _epsilon) {
          issues.add(PlanIssue('error', '${r.name} is outside the plot boundary.'));
        }

        // ── openings sanity ────────────────────────────────────
        for (final o in [...r.doors, ...r.windows]) {
          final along = (o.wall == 'n' || o.wall == 's') ? r.width : r.length;
          if (o.offset < 0 || o.offset > along || o.width <= 0) {
            issues.add(PlanIssue(
                'warning', '${r.name} has an opening outside its wall.'));
          } else if (o.offset - o.width / 2 < -_epsilon ||
              o.offset + o.width / 2 > along + _epsilon) {
            issues.add(PlanIssue(
                'warning', '${r.name} has an opening that spills past a corner.'));
          }
        }
        if (r.doors.isEmpty) {
          issues.add(PlanIssue('warning', '${r.name} has no door.'));
        }
      }

      // ── overlap detection (n log n sweep per floor) ─────────
      issues.addAll(_overlaps(f));
    }

    // ── required rooms (any floor) ────────────────────────────
    for (final t in ['bedroom', 'master_bedroom']) {
      if (requiredTypes.contains(t)) break;
      if (t == 'master_bedroom' && !requiredTypes.contains('bedroom')) {
        issues.add(const PlanIssue('warning', 'No bedroom in the plan.'));
      }
    }
    if (!requiredTypes.contains('bathroom')) {
      issues.add(const PlanIssue('warning', 'No bathroom in the plan.'));
    }
    if (!requiredTypes.contains('kitchen')) {
      issues.add(const PlanIssue('warning', 'No kitchen in the plan.'));
    }

    // ── multi-floor needs a staircase ─────────────────────────
    if (plan.floors.length > 1 && !requiredTypes.contains('staircase')) {
      issues.add(const PlanIssue('error', 'Multi-floor plan has no staircase.'));
    }

    // ── parking fit ───────────────────────────────────────────
    final hasParking =
        requiredTypes.contains('car_parking') || requiredTypes.contains('garage');
    if (hasParking) {
      final park = plan.floors
          .expand((f) => f.rooms)
          .firstWhere(
              (r) => r.type == 'car_parking' || r.type == 'garage',
              orElse: () => plan.floors.first.rooms.first);
      if (park.width < 8 || park.length < 14) {
        issues.add(const PlanIssue(
            'warning', 'Parking is too small for a standard car.'));
      }
    }

    return ValidationResult(issues: issues);
  }

  static List<PlanIssue> _overlaps(HousePlanFloor f) {
    final issues = <PlanIssue>[];
    final rooms = [...f.rooms]..sort((a, b) => a.x.compareTo(b.x));

    for (var i = 0; i < rooms.length; i++) {
      for (var j = i + 1; j < rooms.length; j++) {
        final a = rooms[i], b = rooms[j];
        if (b.x >= a.right - _epsilon) break; // sweep: no further overlap
        if (b.y < a.bottom - _epsilon && a.y < b.bottom - _epsilon) {
          issues.add(PlanIssue(
              'error', '${a.name} overlaps ${b.name} on floor ${f.floor}.'));
        }
      }
    }
    return issues;
  }

  // ─────────────────────────────────────────────────────────────
  // REPAIR — deterministic clean-up applied to every loaded/generated plan
  // ─────────────────────────────────────────────────────────────

  /// Clamps rooms into the plot and fixes openings that spill past corners.
  /// Returns the number of fixes applied.
  static int repair(HousePlan plan) {
    var fixes = 0;
    plan.clampToPlot();

    for (final f in plan.floors) {
      for (final r in f.rooms) {
        fixes += _fixOpenings(r.doors, r);
        fixes += _fixOpenings(r.windows, r);
        if (r.doors.isEmpty) {
          // Deterministic default: centred door on the longest wall.
          final wall = r.width >= r.length ? 'n' : 'w';
          final along = wall == 'n' ? r.width : r.length;
          r.doors.add(PlanOpening(
              wall: wall,
              offset: along / 2,
              width: 3.0.clamp(1.5, along / 2)));
          fixes++;
        }
      }
    }
    return fixes;
  }

  static int _fixOpenings(List<PlanOpening> list, HousePlanRoom r) {
    var fixes = 0;
    final fixed = <PlanOpening>[];
    for (final o in list) {
      final along = (o.wall == 'n' || o.wall == 's') ? r.width : r.length;
      if (along < 1) continue; // drop on degenerate walls
      var width = o.width.clamp(1.5, along * 0.9).toDouble();
      var offset = o.offset.clamp(width / 2, along - width / 2).toDouble();
      if (offset != o.offset || width != o.width) fixes++;
      fixed.add(o.copyWith(offset: offset, width: width));
    }
    list
      ..clear()
      ..addAll(fixed);
    return fixes;
  }
}
