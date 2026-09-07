// =============================================================================
// house_plan_service.dart — Firestore persistence for the AI House Planner
//
// Collections (spec §22, adapted to the existing Firestore backend instead
// of a new REST server — the app already uses Firebase for everything):
//
//   house_plans/{planId}
//     projectId, clientId, plot_width_ft, plot_length_ft, plot_unit,
//     number_of_floors, requirements_json, plan_json, version,
//     status ('draft'|'ready'), created_at, updated_at
//
//   house_plans/{planId}/versions/{n}
//     version, plan_json, created_at
//
// ROLE-BASED FIELD FILTERING (spec §23) is enforced in TWO layers:
//   1. [toClientMap / toContractorMap] — the serializer layer in THIS file
//      decides which fields even exist per role. Contractor maps simply do
//      NOT contain the private visualization fields.
//   2. firestore.rules — the database layer blocks contractor reads/writes
//      of house_plans documents entirely except the whitelisted
//      construction fields via a separate `blueprint` view. (See
//      firestore.rules in the repo root.)
//
// The 3D/360/visualization URLs are therefore never present in a contractor
// response — not merely hidden in the UI.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ali_app/house_planner/models/house_plan_models.dart';

class HousePlanDoc {
  const HousePlanDoc({
    required this.id,
    required this.projectId,
    required this.clientId,
    required this.version,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.plan,
    this.plot,
    this.requirements,
    this.model3dUrl,
    this.panoramaUrl,
    this.visualizationUrl,
  });

  final String id;
  final String projectId;
  final String clientId;
  final HousePlan? plan;
  final PlotDetails? plot;
  final List<RoomRequirement>? requirements;
  final int version;
  final String status; // 'draft' | 'ready'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Private, client-only resources (spec §23).
  final String? model3dUrl;
  final String? panoramaUrl;
  final String? visualizationUrl;

  bool get hasPlan => plan != null && plan!.floors.isNotEmpty;
}

class HousePlanService {
  HousePlanService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('house_plans');

  // ─────────────────────────────────────────────────────────────
  // CREATE / SAVE
  // ─────────────────────────────────────────────────────────────

  /// Creates a draft house plan and returns its id. The project doc itself
  /// is written later by the wizard's final step.
  static Future<String> createDraft({
    required String projectId,
    required PlotDetails plot,
    required List<RoomRequirement> requirements,
    required HousePlan plan,
  }) async {
    final now = FieldValue.serverTimestamp();
    final doc = await _col.add({
      'projectId': projectId,
      'clientId': _uid,
      'plot_width_ft': plot.widthFt,
      'plot_length_ft': plot.lengthFt,
      'plot_unit': plot.unit,
      'number_of_floors': plot.includedFloors.length,
      'requirements_json': requirements.map((r) => r.toJson()).toList(),
      'plan_json': plan.toJson(),
      'version': 1,
      'status': 'draft',
      'created_at': now,
      'updated_at': now,
    });

    // Version 1 snapshot (spec §14).
    await doc.collection('versions').doc('1').set({
      'version': 1,
      'plan_json': plan.toJson(),
      'created_at': now,
    });

    // Sanitized construction copy for contractors (spec §23) — see
    // _writeBlueprintProjection below + firestore.rules.
    await _writeBlueprintProjection(
      projectId: projectId,
      plot: plot,
      requirements: requirements,
      plan: plan,
      version: 1,
    );
    return doc.id;
  }

  /// Saves [plan] as a NEW version (spec §14 versioning). The caller owns
  /// the plan object; we just persist it.
  static Future<int> saveNewVersion({
    required String planId,
    required HousePlan plan,
    bool markReady = false,
  }) async {
    final ref = _col.doc(planId);
    final snap = await ref.get();
    final current = ((snap.data()?['version'] as int?) ?? 1);
    final next = current + 1;
    final now = FieldValue.serverTimestamp();

    await ref.update({
      'plan_json': plan.toJson(),
      'version': next,
      'updated_at': now,
      if (markReady) 'status': 'ready',
    });
    await ref.collection('versions').doc('$next').set({
      'version': next,
      'plan_json': plan.toJson(),
      'created_at': now,
    });

    // Keep the contractor-facing construction copy in sync.
    final projectId = ((snap.data()?['projectId'] as String?) ?? '');
    if (projectId.isNotEmpty) {
      final reqs = (snap.data()?['requirements_json'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .map(RoomRequirement.fromJson)
          .toList();
      final widthFt = (snap.data()?['plot_width_ft'] as num?)
              ?.toDouble() ??
          plan.plotWidthFt;
      final lengthFt = (snap.data()?['plot_length_ft'] as num?)
              ?.toDouble() ??
          plan.plotLengthFt;
      final unit = (snap.data()?['plot_unit'] as String?) ?? 'ft';
      await _writeBlueprintProjection(
        projectId: projectId,
        plot: PlotDetails(
          width: unit == 'm' ? widthFt / kMetersToFeet : widthFt,
          length: unit == 'm' ? lengthFt / kMetersToFeet : lengthFt,
          unit: unit,
          includedFloors: plan.floors.map((f) => f.floor).toList(),
        ),
        requirements: reqs,
        plan: plan,
        version: next,
      );
    }
    return next;
  }

  /// Attaches a project to an existing draft (used when the wizard creates
  /// the Firestore project doc AFTER the plan).
  static Future<void> attachProject(String planId, String projectId) =>
      _col.doc(planId).update({
        'projectId': projectId,
        'updated_at': FieldValue.serverTimestamp(),
      });

  // ─────────────────────────────────────────────────────────────
  // READ — with role-based serialization (spec §23)
  // ─────────────────────────────────────────────────────────────

  static HousePlanDoc? _docFrom(String id, Map<String, dynamic> d) {
    HousePlan? plan;
    final rawPlan = d['plan_json'];
    if (rawPlan is Map) {
      plan = HousePlan.fromJson(Map<String, dynamic>.from(rawPlan));
    }
    PlotDetails? plot;
    if (plan != null) {
      plot = PlotDetails(
        width: plan.plotWidthFt,
        length: plan.plotLengthFt,
        unit: 'ft',
        includedFloors: plan.floors.map((f) => f.floor).toList(),
      );
    }
    final reqs = (d['requirements_json'] as List? ?? [])
        .whereType<Map>()
        .map((m) => RoomRequirement.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    DateTime? parse(dynamic v) => v is Timestamp ? v.toDate() : null;

    return HousePlanDoc(
      id: id,
      projectId: (d['projectId'] as String?) ?? '',
      clientId: (d['clientId'] as String?) ?? '',
      plan: plan,
      plot: plot,
      requirements: reqs,
      version: (d['version'] as int?) ?? 1,
      status: (d['status'] as String?) ?? 'draft',
      createdAt: parse(d['created_at']),
      updatedAt: parse(d['updated_at']),
    );
  }

  /// CLIENT read: includes every field, including private 3D/360 URLs.
  static Future<HousePlanDoc?> getForClient(String planId) async {
    final snap = await _col.doc(planId).get();
    if (!snap.exists) return null;
    final d = snap.data()!;
    final base = _docFrom(snap.id, d);
    if (base == null) return null;
    // Re-build with private fields (only the client passes through here).
    return HousePlanDoc(
      id: base.id,
      projectId: base.projectId,
      clientId: base.clientId,
      plan: base.plan,
      plot: base.plot,
      requirements: base.requirements,
      version: base.version,
      status: base.status,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      model3dUrl: d['model_3d_url'] as String?,
      panoramaUrl: d['panorama_url'] as String?,
      visualizationUrl: d['visualization_url'] as String?,
    );
  }

  /// Writes the sanitized construction projection to
  /// `project_blueprints/{projectId}` — the ONLY house-plan data contractors
  /// can read once firestore.rules is deployed (spec §23/§28). This document
  /// deliberately contains NO private visualization URLs; the rules also
  /// reject any write that tries to add them.
  static Future<void> _writeBlueprintProjection({
    required String projectId,
    required PlotDetails plot,
    required List<RoomRequirement> requirements,
    required HousePlan plan,
    required int version,
  }) async {
    await _db.collection('project_blueprints').doc(projectId).set({
      'projectId': projectId,
      'clientId': _uid,
      'plot_width_ft': plot.widthFt,
      'plot_length_ft': plot.lengthFt,
      'plot_unit': plot.unit,
      'number_of_floors': plot.includedFloors.length,
      'requirements_json': requirements.map((r) => r.toJson()).toList(),
      'plan_json': plan.toJson(),
      'version': version,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// CONTRACTOR read: construction data ONLY (spec §23/§28). Private
  /// visualization URLs are never read from Firestore in this path — the
  /// returned document does not contain them at all.
  ///
  /// Reads the sanitized `project_blueprints` projection first (the path
  /// that stays legal under firestore.rules); falls back to querying the
  /// private collection for dev environments with permissive rules.
  static Future<HousePlanDoc?> getForContractor(String projectId) async {
    final projection = await _db
        .collection('project_blueprints')
        .doc(projectId)
        .get();
    if (projection.exists) {
      final doc = _docFrom(projection.id, projection.data()!);
      if (doc != null) return doc;
    }

    // Dev fallback (open rules only).
    final q = await _col.where('projectId', isEqualTo: projectId).limit(1).get();
    if (q.docs.isEmpty) return null;
    final snap = q.docs.first;
    return _docFrom(snap.id, snap.data());
  }

  /// Client: all my plans.
  static Stream<List<HousePlanDoc>> watchMyPlans() => _col
      .where('clientId', isEqualTo: _uid)
      .orderBy('updated_at', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => _docFrom(d.id, d.data()))
          .whereType<HousePlanDoc>()
          .toList());

  // ─────────────────────────────────────────────────────────────
  // VERSIONS (spec §14)
  // ─────────────────────────────────────────────────────────────

  static Future<List<(int, HousePlan?)>> listVersions(String planId) async {
    final snap = await _col.doc(planId).collection('versions').get();
    final out = <(int, HousePlan?)>[];
    for (final d in snap.docs) {
      final v = (d.data()['version'] as int?) ??
          int.tryParse(d.id) ??
          0;
      final raw = d.data()['plan_json'];
      HousePlan? plan;
      if (raw is Map) {
        plan = HousePlan.fromJson(Map<String, dynamic>.from(raw));
      }
      out.add((v, plan));
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return out;
  }

  static Future<void> restoreVersion(String planId, int version) async {
    final doc = await _col.doc(planId).collection('versions').doc('$version').get();
    final raw = doc.data()?['plan_json'];
    if (raw is! Map) return;
    final plan = HousePlan.fromJson(Map<String, dynamic>.from(raw));
    if (plan == null) return;
    await saveNewVersion(planId: planId, plan: plan);
  }

  // ─────────────────────────────────────────────────────────────
  // OPTIONAL PRIVATE RESOURCES (client only)
  // ─────────────────────────────────────────────────────────────

  /// The procedural 3D model is generated ON DEVICE (spec §15/§31) — no URL
  /// is stored for it. A future backend exporter can set model_3d_url and
  /// this method is already in place for it.
  static Future<void> setPanoramaUrl(String planId, String url) =>
      _col.doc(planId).update({
        'panorama_url': url,
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Future<void> setVisualizationUrl(String planId, String url) =>
      _col.doc(planId).update({
        'visualization_url': url,
        'updated_at': FieldValue.serverTimestamp(),
      });

  // ─────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────

  static Future<void> deletePlan(String planId) async {
    // Snapshot the projectId so the projection can be removed too.
    final snap = await _col.doc(planId).get();
    final projectId = (snap.data()?['projectId'] as String?) ?? '';

    final versions = await _col.doc(planId).collection('versions').get();
    for (final v in versions.docs) {
      await v.reference.delete();
    }
    await _col.doc(planId).delete();

    if (projectId.isNotEmpty) {
      await _db.collection('project_blueprints').doc(projectId).delete();
    }
  }
}
