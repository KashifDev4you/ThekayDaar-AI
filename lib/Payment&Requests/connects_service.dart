// =============================================================================
// connects_service.dart
// Handles: reading balance, spending connects on bids,
// granting monthly plan connects, recording transactions.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'connects_config.dart';

class ConnectsService {
  ConnectsService._();

  static final _db = FirebaseFirestore.instance;

  // ── Read current balance ────────────────────────────────────
  static Future<ConnectsBalance> getBalance(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    return ConnectsBalance.fromMap(data);
  }

  // ── Stream balance (live) ────────────────────────────────────
  static Stream<ConnectsBalance> streamBalance(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => ConnectsBalance.fromMap(s.data() ?? {}));
  }

  // ── Spend connects for a bid ────────────────────────────────
  // Returns null on success, error string on failure.
  static Future<String?> spendForBid({
    required String uid,
    required String projectId,
    required String budgetMin,
    required String budgetMax,
    required String projectTitle,
  }) async {
    final cost = ThekaydaarPlans.bidCost(budgetMin, budgetMax);

    return _db.runTransaction((txn) async {
      final userRef = _db.collection('users').doc(uid);
      final snap    = await txn.get(userRef);
      final data    = snap.data() ?? {};

      final balance = ConnectsBalance.fromMap(data);

      // Check plan allows bidding
      final plan = ThekaydaarPlans.plans[balance.planName];
      if (plan == null || !plan.canBid) {
        return 'Upgrade your plan to start bidding.';
      }

      // Check total connects
      if (balance.totalConnects < cost) {
        return 'Not enough connects. Need $cost, have ${balance.totalConnects}.';
      }

      // Deduct: plan connects first, then purchased
      int remainCost = cost;
      int newPlanConnects      = balance.planConnects;
      int newPurchasedConnects = balance.purchasedConnects;

      if (newPlanConnects >= remainCost) {
        newPlanConnects -= remainCost;
        remainCost = 0;
      } else {
        remainCost        -= newPlanConnects;
        newPlanConnects    = 0;
        newPurchasedConnects -= remainCost;
      }

      txn.update(userRef, {
        'planConnects'      : newPlanConnects,
        'purchasedConnects' : newPurchasedConnects,
        'totalConnects'     : newPlanConnects + newPurchasedConnects,
      });

      // Record transaction
      final txnRef = _db.collection('connects_transactions').doc();
      txn.set(txnRef, {
        'uid'        : uid,
        'type'       : 'bid_spend',
        'amount'     : -cost,
        'projectId'  : projectId,
        'description': 'Bid on "$projectTitle" (-$cost connects)',
        'createdAt'  : FieldValue.serverTimestamp(),
      });

      return null; // success
    });
  }

  // ── Grant monthly plan connects (call on plan activation) ───
  static Future<void> grantMonthlyConnects({
    required String uid,
    required String planName,
  }) async {
    final plan = ThekaydaarPlans.plans[planName];
    if (plan == null) return;

    final now    = DateTime.now();
    final expiry = DateTime(now.year, now.month + 1, now.day);

    final userRef = _db.collection('users').doc(uid);
    final snap    = await userRef.get();
    final data    = snap.data() ?? {};
    final existing = (data['purchasedConnects'] as int?) ?? 0;

    await userRef.update({
      'planName'             : planName,
      'planConnects'         : plan.monthlyConnects,
      'planConnectsExpiry'   : Timestamp.fromDate(expiry),
      'totalConnects'        : plan.monthlyConnects + existing,
      'isPremium'            : planName != 'Free',
    });

    // Record grant transaction
    if (plan.monthlyConnects > 0) {
      await _db.collection('connects_transactions').add({
        'uid'        : uid,
        'type'       : 'plan_grant',
        'amount'     : plan.monthlyConnects,
        'description': '$planName plan — +${plan.monthlyConnects} connects',
        'createdAt'  : FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Add purchased connects ──────────────────────────────────
  static Future<void> addPurchasedConnects({
    required String uid,
    required int    amount,
    required String packageLabel,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final snap    = await userRef.get();
    final data    = snap.data() ?? {};

    final existing  = (data['purchasedConnects'] as int?) ?? 0;
    final planConns = (data['planConnects']       as int?) ?? 0;
    final newTotal  = existing + amount;

    await userRef.update({
      'purchasedConnects': newTotal,
      'totalConnects'    : planConns + newTotal,
    });

    await _db.collection('connects_transactions').add({
      'uid'        : uid,
      'type'       : 'purchase',
      'amount'     : amount,
      'description': '$packageLabel purchased (+$amount connects)',
      'createdAt'  : FieldValue.serverTimestamp(),
    });
  }

  // ── Check if plan connects have expired, zero them out ──────
  static Future<void> checkAndExpirePlanConnects(
      String uid) async {
    final userRef = _db.collection('users').doc(uid);
    final snap    = await userRef.get();
    final data    = snap.data() ?? {};

    final expiry = data['planConnectsExpiry'] as Timestamp?;
    if (expiry == null) return;

    final now = DateTime.now();
    if (now.isAfter(expiry.toDate())) {
      final purchased =
          (data['purchasedConnects'] as int?) ?? 0;
      await userRef.update({
        'planConnects' : 0,
        'totalConnects': purchased,
      });
    }
  }
}

// ── Balance model ──────────────────────────────────────────────
class ConnectsBalance {
  final String planName;
  final int    planConnects;
  final int    purchasedConnects;
  final int    totalConnects;
  final DateTime? planExpiry;

  ConnectsBalance({
    required this.planName,
    required this.planConnects,
    required this.purchasedConnects,
    required this.totalConnects,
    this.planExpiry,
  });

  factory ConnectsBalance.fromMap(Map<String, dynamic> d) {
    final plan      = d['planName']           as String? ?? 'Free';
    final planC     = (d['planConnects']       as int?)  ?? 0;
    final purchC    = (d['purchasedConnects']  as int?)  ?? 0;
    final total     = (d['totalConnects']      as int?)  ?? (planC + purchC);
    final expTs     = d['planConnectsExpiry']  as Timestamp?;

    return ConnectsBalance(
      planName          : plan,
      planConnects      : planC,
      purchasedConnects : purchC,
      totalConnects     : total,
      planExpiry        : expTs?.toDate(),
    );
  }

  bool get canBid =>
      ThekaydaarPlans.plans[planName]?.canBid ?? false;
}