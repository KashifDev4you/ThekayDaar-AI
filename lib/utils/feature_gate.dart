// =============================================================================
// feature_gate.dart
// Lightweight feature-gating helper.  Checks the user's current plan
// from Firestore and shows a beautiful upgrade dialog when a feature
// is locked behind a higher tier.
//
// Usage:
//   final ok = await FeatureGate.check(
//     context, 'canUseAiTools', isContractor: true);
//   if (!ok) return;   // user dismissed → don't proceed
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ali_app/Payment&Requests/connects_config.dart';

class FeatureGate {
  FeatureGate._();

  // User-friendly labels for each feature flag key.
  static const _featureLabels = <String, String>{
    'canBid':                  'Bidding on Projects',
    'canViewProjects':         'View Project Details',
    'canUseAiTools':           'AI Tools',
    'canUseMaterialEstimator': 'AI Material Estimator',
    'canAccessChat':           'Messaging',
    'canViewAnalytics':        'Analytics Dashboard',
    'canPostGig':              'Post a Gig',
    'prioritySupport':         'Priority Support',
    'featuredListing':         'Featured Listing',
    'verifiedBadge':           'Verified Badge',
  };

  /// Returns `true` if the current user's plan allows [feature].
  /// If not, pops up a themed upgrade dialog and returns `false`.
  static Future<bool> check(
    BuildContext context,
    String feature, {
    required bool isContractor,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection(isContractor ? 'thekaydaars' : 'clients')
        .doc(uid)
        .get();
    final planName = doc.data()?['planName'] as String? ?? 'Free';

    // Check feature access directly from plan config.
    // We use the full feature names (e.g. 'canUseAiTools') which match
    // the property names on PlanConfig / ClientPlanConfig.
    final bool hasAccess;
    if (isContractor) {
      final plan = ThekaydaarPlans.plans[planName] ?? ThekaydaarPlans.plans['Free']!;
      hasAccess = switch (feature) {
        'canBid'                  => plan.canBid,
        'canViewProjects'         => plan.canViewProjects,
        'canPostGig'              => plan.canPostGig,
        'canUseAiTools'           => plan.canUseAiTools,
        'canUseMaterialEstimator' => plan.canUseMaterialEstimator,
        'canAccessChat'           => plan.canAccessChat,
        'canViewAnalytics'        => plan.canViewAnalytics,
        'prioritySupport'         => plan.prioritySupport,
        'featuredListing'         => plan.featuredListing,
        'verifiedBadge'           => plan.verifiedBadge,
        _                         => false,
      };
    } else {
      final plan = ThekaydaarPlans.clientPlans[planName] ?? ThekaydaarPlans.clientPlans['Free']!;
      hasAccess = switch (feature) {
        'canAccessChat'   => plan.canAccessChat,
        'canUseAiTools'   => plan.canUseAiTools,
        'verifiedBadge'   => plan.verifiedBadge,
        'featuredListing' => plan.featuredListing,
        'prioritySupport' => plan.prioritySupport,
        _                 => false,
      };
    }

    if (hasAccess) return true;

    if (context.mounted) {
      // Build plan rows for the dialog.
      final planRows = <_PlanRow>[];
      if (isContractor) {
        for (final p in ThekaydaarPlans.plans.values) {
          if (p.priceMonthly > 0) {
            planRows.add(_PlanRow(
              badge: p.badge,
              name: p.name,
              price: p.priceMonthly,
              connects: p.monthlyConnects,
            ));
          }
        }
      } else {
        for (final p in ThekaydaarPlans.clientPlans.values) {
          if (p.priceMonthly > 0) {
            planRows.add(_PlanRow(
              badge: p.badge,
              name: p.name,
              price: p.priceMonthly,
              connects: p.projectPostsAllowed,
              suffix: 'posts',
            ));
          }
        }
      }

      await showDialog(
        context: context,
        builder: (_) => _UpgradeDialog(
          feature: _featureLabels[feature] ?? feature,
          planRows: planRows,
        ),
      );
    }
    return false;
  }
}

// ── Simple data holder for dialog plan rows ──────────────────────────────────

class _PlanRow {
  final String badge;
  final String name;
  final int price;
  final int connects;
  final String suffix;
  const _PlanRow({
    required this.badge,
    required this.name,
    required this.price,
    required this.connects,
    this.suffix = 'connects',
  });
}

// ── Upgrade Dialog ───────────────────────────────────────────────────────────

class _UpgradeDialog extends StatelessWidget {
  const _UpgradeDialog({
    required this.feature,
    required this.planRows,
  });

  final String feature;
  final List<_PlanRow> planRows;

  @override
  Widget build(BuildContext context) {
    const navy  = Color(0xFF0E3B2E);
    const amber = Color(0xFFC9A227);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [navy, navy.withValues(blue: ((navy.b * 255.0).round() + 20).clamp(0, 255) / 255.0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, color: amber, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'Feature Locked',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              '"$feature" is available on premium plans.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            ...planRows.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Text(p.badge, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        Text(
                            'Rs ${p.price}/mo  •  ${p.connects} ${p.suffix}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      color: amber, size: 14),
                ],
              ),
            )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: amber,
                  foregroundColor: navy,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Upgrade Plan',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Maybe later',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ),
          ],
        ),
      ),
    );
  }
}
