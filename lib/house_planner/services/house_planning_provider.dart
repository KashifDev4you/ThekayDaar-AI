// =============================================================================
// house_planning_provider.dart — AI abstraction layer (spec §8, §35, §36)
//
// HousePlanningProvider is the single seam between the UI and any planning
// engine. Two implementations ship today:
//
//   LocalHousePlanningProvider    → RuleBasedPlanner (free, offline, always
//                                    available, deterministic)
//   RemoteAIHousePlanningProvider → Gemini via GeminiService (optional; the
//                                    key stays in .env and is only used when
//                                    configured)
//
// HousePlannerService.generatePlan() orchestrates them with the required
// fallback chain: try remote → validate → repair → fall back to local. The
// UI never knows (or cares) which provider produced the plan, so swapping in
// a self-hosted LLM later means adding one class here.
// =============================================================================

import 'package:ali_app/house_planner/models/house_plan_models.dart';
import 'package:ali_app/house_planner/services/house_plan_validator.dart';
import 'package:ali_app/house_planner/services/rule_based_planner.dart';
import 'package:ali_app/services/gemini_service.dart';

export 'package:ali_app/house_planner/services/house_plan_validator.dart'
    show HousePlanValidator, ValidationResult, PlanIssue;

abstract class HousePlanningProvider {
  String get name;

  /// Generates a plan for [plot] + [requirements]. Throws on failure —
  /// the orchestrator catches and falls back.
  Future<HousePlan> generate({
    required PlotDetails plot,
    required List<RoomRequirement> requirements,
  });
}

// ─────────────────────────────────────────────────────────────
// LOCAL (rule-based) — always available, zero cost
// ─────────────────────────────────────────────────────────────

class LocalHousePlanningProvider implements HousePlanningProvider {
  const LocalHousePlanningProvider();

  @override
  String get name => 'rule_based';

  @override
  Future<HousePlan> generate({
    required PlotDetails plot,
    required List<RoomRequirement> requirements,
  }) async {
    // Simulated async boundary keeps the UI contract identical for both
    // providers (and lets a future isolate-based engine slot in).
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return RuleBasedPlanner.generate(plot: plot, requirements: requirements);
  }
}

// ─────────────────────────────────────────────────────────────
// REMOTE (Gemini) — optional enhancement
// ─────────────────────────────────────────────────────────────

class RemoteAIHousePlanningProvider implements HousePlanningProvider {
  const RemoteAIHousePlanningProvider();

  @override
  String get name => 'gemini';

  bool get isConfigured => GeminiService.isConfigured;

  @override
  Future<HousePlan> generate({
    required PlotDetails plot,
    required List<RoomRequirement> requirements,
  }) async {
    if (!isConfigured) {
      throw Exception('Gemini is not configured — using the built-in planner.');
    }

    // AI geometry is requested in the plot's own unit… converted to feet
    // because our internal schema is feet (HousePlan.fromJson converts back).
    final raw = await GeminiService.generateHousePlanLayout(
      plotWidth: plot.widthFt,
      plotLength: plot.lengthFt,
      unit: 'ft',
      floors: plot.includedFloors,
      requirements: requirements.map((r) => r.toJson()).toList(),
    );

    final plan = HousePlan.fromJson(raw);
    if (plan == null) {
      throw Exception('AI returned an unreadable plan.');
    }
    plan.generatedBy = 'ai';
    plan.unit = plot.unit;
    return plan;
  }
}

// ─────────────────────────────────────────────────────────────
// ORCHESTRATOR — provider chain with graceful degradation
// ─────────────────────────────────────────────────────────────

/// Outcome metadata so the wizard can tell the user WHICH engine produced
/// the plan and whether AI had to be abandoned (spec §29 friendly messaging).
class PlanGenerationResult {
  const PlanGenerationResult({
    required this.plan,
    required this.usedProvider,
    required this.fallbackUsed,
    this.fallbackReason,
  });

  final HousePlan plan;
  final String usedProvider; // 'ai' | 'rule_based'
  final bool fallbackUsed;
  final String? fallbackReason;
}

class HousePlannerService {
  HousePlannerService._();

  static const local = LocalHousePlanningProvider();
  static const remote = RemoteAIHousePlanningProvider();

  /// Generates a plan with the fallback chain:
  /// remote AI (if configured) → validate/repair → else local planner.
  static Future<PlanGenerationResult> generatePlan({
    required PlotDetails plot,
    required List<RoomRequirement> requirements,
    bool preferAi = true,
  }) async {
    if (preferAi && remote.isConfigured) {
      try {
        final aiPlan = await remote.generate(
          plot: plot,
          requirements: requirements,
        );
        final validation = HousePlanValidator.validate(aiPlan);
        if (validation.isValid) {
          HousePlanValidator.repair(aiPlan);
          return PlanGenerationResult(
            plan: aiPlan,
            usedProvider: 'ai',
            fallbackUsed: false,
          );
        }
        // Invalid AI geometry — deterministic planner to the rescue.
        final plan = await local.generate(plot: plot, requirements: requirements);
        return PlanGenerationResult(
          plan: plan,
          usedProvider: 'rule_based',
          fallbackUsed: true,
          fallbackReason:
              'AI planning was temporarily unavailable, so we created a '
              'layout with our built-in planner. You can still edit it.',
        );
      } catch (e) {
        final plan = await local.generate(plot: plot, requirements: requirements);
        return PlanGenerationResult(
          plan: plan,
          usedProvider: 'rule_based',
          fallbackUsed: true,
          fallbackReason:
              'AI planning is temporarily unavailable — we\'ve created a '
              'basic layout using our built-in planner.',
        );
      }
    }

    final plan = await local.generate(plot: plot, requirements: requirements);
    return PlanGenerationResult(
      plan: plan,
      usedProvider: 'rule_based',
      fallbackUsed: false,
    );
  }
}

// Re-export moved to the top of this file (directives must precede classes).
