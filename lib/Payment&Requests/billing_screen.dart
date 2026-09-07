// =============================================================================
// billing_screen.dart
//
// A full Plans & Billing screen for both 'thekaydaar' and 'client' roles.
//
// FEATURES:
//   1. Shows current active plan with full details
//   2. Lists all available plans with feature comparison
//   3. Payment sheet: EasyPaisa / JazzCash → writes to payment_requests
//   4. Admin approval: listens to Firestore; when admin sets
//      payment_requests/{docId}.status == 'approved', plan auto-activates
//   5. Payment history tab: lists all past requests with status badges
//   6. Plan expiry countdown
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'connects_config.dart';
import 'package:ali_app/Widgets/language_toggle_widget.dart';

// ─── Theme ───────────────────────────────────────────────────────────────────
const _navy = Color(0xFF0E3B2E);
const _amber = Color(0xFFC9A227);
const _amberD = Color(0xFFA8861D);
const _amberL = Color(0xFFFBF6E3);
const _green = Color(0xFF10B981);
const _greenL = Color(0xFFD1FAE5);
const _blue = Color(0xFF1A5C46);
const _blueL = Color(0xFFE7F2ED);
const _red = Color(0xFFDC2626);
const _redL = Color(0xFFFEF2F2);
const _border = Color(0xFFE3E0D5);
const _surface = Color(0xFFF7F5EF);
const _white = Color(0xFFFFFFFF);
const _textPri = Color(0xFF0E3B2E);
const _textSec = Color(0xFF5D6B64);

// ─── Plan Models ─────────────────────────────────────────────────────────────
class BillingPlan {
  final String key, label, price;
  final int priceAmount; // numeric Rs amount
  final Color bg, fg, accentBg;
  final IconData icon;
  final List<String> perks;
  final List<String> limitations;
  const BillingPlan({
    required this.key,
    required this.label,
    required this.price,
    required this.priceAmount,
    required this.bg,
    required this.fg,
    required this.accentBg,
    required this.icon,
    required this.perks,
    required this.limitations,
  });
}

// ── Thekaydaar plans ──────────────────────────────────────────────────────────
const _tkPlans = [
  BillingPlan(
    key: 'Free',
    label: 'Free',
    price: 'Rs 0/month',
    priceAmount: 0,
    bg: Color(0xFFF7F5EF),
    fg: Color(0xFF5D6B64),
    accentBg: Color(0xFFE3E0D5),
    icon: Icons.person_outline_rounded,
    perks: [
      'Browse all projects',
      'View limited project details',
      'Basic search',
    ],
    limitations: [
      'Cannot bid on projects',
      'No messaging or chat',
      'No AI tools or estimator',
      'No contract system access',
      'Profile hidden from clients',
    ],
  ),
  BillingPlan(
    key: 'Pro',
    label: 'Pro',
    price: 'Rs 999/month',
    priceAmount: 999,
    bg: Color(0xFFFBF6E3),
    fg: Color(0xFFA8861D),
    accentBg: Color(0xFFE6D694),
    icon: Icons.workspace_premium_rounded,
    perks: [
      '10 bids per month',
      'Post gig & public profile',
      'Verified badge on profile',
      'Direct client messaging',
      'Contract system access',
      'Priority listing in search',
    ],
    limitations: [
      'No AI Material Estimator',
      'Not featured at top of search',
      'No analytics report',
    ],
  ),
  BillingPlan(
    key: 'Elite',
    label: 'Elite',
    price: 'Rs 2499/month',
    priceAmount: 2499,
    bg: Color(0xFFE7F2ED),
    fg: Color(0xFF0E3B2E),
    accentBg: Color(0xFFCFE5DC),
    icon: Icons.star_rounded,
    perks: [
      '20 bids per month',
      'AI Material Estimator & smart tools',
      'Featured at top of search results',
      'Elite badge on profile',
      'Monthly analytics report',
      'Priority support',
      'Post gig & public profile',
      'Direct client messaging',
      'Contract system access',
    ],
    limitations: [],
  ),
  BillingPlan(
    key: 'Business',
    label: 'Business',
    price: 'Rs 3999/month',
    priceAmount: 3999,
    bg: Color(0xFF1A5C46),
    fg: Color(0xFFFFFFFF),
    accentBg: Color(0xFF0E3B2E),
    icon: Icons.diamond_outlined,
    perks: [
      '40 bids per month',
      'All AI tools unlocked',
      'Featured badge + top placement',
      'Full analytics dashboard',
      'Dedicated priority support',
      'Post gig & public profile',
      'Direct client messaging',
      'Contract system access',
      'Verified + Elite badge',
    ],
    limitations: [],
  ),
];

// ── Client plans ──────────────────────────────────────────────────────────────
const _clientPlans = [
  BillingPlan(
    key: 'Free',
    label: 'Free',
    price: 'Rs 0/month',
    priceAmount: 0,
    bg: Color(0xFFF7F5EF),
    fg: Color(0xFF5D6B64),
    accentBg: Color(0xFFE3E0D5),
    icon: Icons.person_outline_rounded,
    perks: [
      '1 project post per month',
      'View up to 5 bids per project',
      'Basic listing in search',
    ],
    limitations: [
      'Cannot view all bids',
      'No verified client badge',
      'No messaging with contractors',
      'No AI tools access',
    ],
  ),
  BillingPlan(
    key: 'Standard',
    label: 'Standard',
    price: 'Rs 499/month',
    priceAmount: 499,
    bg: Color(0xFFFBF6E3),
    fg: Color(0xFFA8861D),
    accentBg: Color(0xFFE6D694),
    icon: Icons.workspace_premium_rounded,
    perks: [
      '5 project posts per month',
      'All bids visible on each project',
      'Priority placement in search',
      'Direct contractor messaging',
      'Contract system access',
    ],
    limitations: [
      'No verified client badge',
      'Not featured at top of search',
      'No AI tools access',
    ],
  ),
  BillingPlan(
    key: 'Premium',
    label: 'Premium',
    price: 'Rs 1499/month',
    priceAmount: 1499,
    bg: Color(0xFFE7F2ED),
    fg: Color(0xFF1A5C46),
    accentBg: Color(0xFFD9EBE2),
    icon: Icons.star_rounded,
    perks: [
      'Unlimited project posts',
      'All bids visible on every project',
      'Verified client badge',
      'Featured in search results',
      'AI Material Estimator access',
      'Priority support',
      'Direct contractor messaging',
      'Contract system access',
    ],
    limitations: [],
  ),
];

BillingPlan _getPlan(List<BillingPlan> list, String key) =>
    list.firstWhere((p) => p.key == key, orElse: () => list.first);

int _daysUntilExpiry(dynamic ts) {
  if (ts == null) return 0;
  if (ts is Timestamp) {
    final diff = 30 - DateTime.now().difference(ts.toDate()).inDays;
    return diff < 0 ? 0 : diff;
  }
  return 0;
}

// =============================================================================
// BillingScreen
// =============================================================================
class BillingScreen extends StatefulWidget {
  /// Pass 'thekaydaar' or 'client'
  final String role;
  /// 0 = Plans tab (default), 1 = Payment History tab
  final int initialTab;
  const BillingScreen({super.key, required this.role, this.initialTab = 0});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with SingleTickerProviderStateMixin {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;
  late final TabController _tabs;
  StreamSubscription<QuerySnapshot>? _approvalSub;
  // ADD THESE
  String _userCity = '';
  String _userArea = '';
  String _userName = '';   // ADD
String _userPhone = '';  // ADD

  bool get _isTk => widget.role == 'thekaydaar';
  String get _collection => _isTk ? 'thekaydaars' : 'clients';
  List<BillingPlan> get _plans => _isTk ? _tkPlans : _clientPlans;
  Color get _accent => _isTk ? _amberD : _blue;
  Color get _accentL => _isTk ? _amberL : _blueL;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _listenForApproval();
    _loadUserLocation(); // ADD THIS
  }

Future<void> _loadUserLocation() async {
  if (uid == null) return;
  final doc = await FirebaseFirestore.instance
      .collection(_collection)
      .doc(uid)
      .get();
  if (doc.exists && mounted) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _userCity  = data['city']     as String? ?? '';
      _userArea  = data['area']     as String? ?? '';
      _userName  = data['fullName'] as String?       // ADD
          ?? data['name']           as String? ?? '';
      _userPhone = data['phone']    as String?       // ADD
          ?? data['phoneNumber']    as String? ?? '';
    });
  }
}

  @override
  void dispose() {
    _tabs.dispose();
    _approvalSub?.cancel();
    super.dispose();
  }

  // ── Listen for admin approval ─────────────────────────────────────────────
  void _listenForApproval() {
    if (uid == null) return;
    _approvalSub = FirebaseFirestore.instance
        .collection('payment_requests')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .where('activated', isEqualTo: false) // ADD THIS
        .snapshots()
        .listen((snap) async {
          for (final doc in snap.docs) {
            final data = doc.data();
            final planKey = data['plan'] as String? ?? '';
            final alreadyActivated = data['activated'] as bool? ?? false;
            if (planKey.isNotEmpty && !alreadyActivated) {
              await _activatePlan(planKey);
              // Mark as activated so listener doesn't fire again
              await doc.reference.update({'activated': true});
              if (mounted) {
                _snack(
                  '🎉 ${data['planLabel']} Plan Activated!',
                  success: true,
                );
              }
            }
          }
        });
  }

  // ── Activate plan in Firestore ────────────────────────────────────────────
  Future<void> _activatePlan(String key) async {
    if (uid == null) return;
    final Map<String, dynamic> updates;

    if (_isTk) {
      final canBid = key != 'Free';
      updates = {
        'isPremium': key != 'Free',
        'planName': key,
        'bidsRemaining': key == 'Business'
            ? 40
            : key == 'Elite'
            ? 20
            : key == 'Pro'
            ? 10
            : 0,
        'bidsTotal': key == 'Business'
            ? 40
            : key == 'Elite'
            ? 20
            : key == 'Pro'
            ? 10
            : 0,
        'canBid': canBid,
        'canPostGig': canBid,
        'verifiedBadge': key != 'Free',
        'featuredListing': key == 'Elite' || key == 'Business',
        'canUseAiTools': key == 'Elite' || key == 'Business',
        'canUseMaterialEstimator': key == 'Elite' || key == 'Business',
        'canAccessChat': key != 'Free',
        'canViewAnalytics': key == 'Elite' || key == 'Business',
        'prioritySupport': key == 'Elite' || key == 'Business',
        'planActivatedAt': FieldValue.serverTimestamp(),
        'paymentPending': false,
        'pendingPlan': FieldValue.delete(),
      };
    } else {
      final p = _getPlan(_clientPlans, key);
      updates = {
        'isPremium': p.priceAmount > 0,
        'planName': key,
        'projectsRemaining': key == 'Premium'
            ? 999
            : key == 'Standard'
            ? 5
            : 1,
        'bidsViewLimit': p.priceAmount > 0 ? 999 : 5,
        'premiumFeatures': p.priceAmount > 0,
        'verifiedBadge': key == 'Premium',
        'planActivatedAt': FieldValue.serverTimestamp(),
        'paymentPending': false,
        'pendingPlan': FieldValue.delete(),
      };
    }

    await FirebaseFirestore.instance
        .collection(_collection)
        .doc(uid)
        .set(updates, SetOptions(merge: true));
  }

  // ── Submit payment request ────────────────────────────────────────────────
 Future<void> _submitPayment(
  String planKey,
  String planLabel,
  String planPrice,
  String method,
  String txnId,
) async {
  if (uid == null) return;
  await FirebaseFirestore.instance.collection('payment_requests').add({
    'uid'         : uid,
    'userName'    : _userName,
    'userPhone'   : _userPhone,
    'plan'        : planKey,
    'planLabel'   : planLabel,
    'amount'      : planPrice,
    'txnId'       : txnId,
    'method'      : method,
    'role'        : _collection,
    'status'      : 'pending',
    'activated'   : false,
    'requestedAt' : FieldValue.serverTimestamp(),
    'city'        : _userCity,
    'area'        : _userArea,
  });
  await FirebaseFirestore.instance
      .collection(_collection)
      .doc(uid)
      .set({
        'paymentPending': true,
        'pendingPlan'   : planKey,
      }, SetOptions(merge: true));
} // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Login required')));
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(_collection)
          .doc(uid!)
          .snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final planKey = data['planName'] as String? ?? 'Free';
        final isPending = data['paymentPending'] as bool? ?? false;
        final pendPlan = data['pendingPlan'] as String? ?? '';
        final planTs = data['planActivatedAt'];
        final daysLeft = _daysUntilExpiry(planTs);
        final activePlan = _getPlan(_plans, planKey);

        return LanguageBuilder(
          builder: (context, t) {
            return Scaffold(
              backgroundColor: _surface,
              appBar: AppBar(
                backgroundColor: _white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _textPri,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  t.t('Plans & Billing'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textPri,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
                    child: LanguageToggleChip(compact: true),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(49),
                  child: Column(
                    children: [
                      Container(color: _border, height: 1),
                      TabBar(
                        controller: _tabs,
                        labelColor: _accent,
                        unselectedLabelColor: _textSec,
                        indicatorColor: _accent,
                        indicatorWeight: 2.5,
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: [
                          Tab(text: t.t('Plans')),
                          Tab(text: t.t('Payment History')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // SafeArea bottom — keeps tab content clear of the gesture bar
              // / home indicator (top is handled by AppBar + TabBar).
              body: SafeArea(
                top: false,
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _PlansTab(
                      plans: _plans,
                      activePlanKey: planKey,
                      isPending: isPending,
                      pendingPlan: pendPlan,
                      daysLeft: daysLeft,
                      activePlan: activePlan,
                      accent: _accent,
                      accentL: _accentL,
                      isTk: _isTk,
                      onSelectPlan: (p) => _showPaymentSheet(p, data),
                      onActivateFree: () => _activatePlan('Free'),
                    ),
                    _HistoryTab(uid: uid!, accent: _accent),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Payment sheet ─────────────────────────────────────────────────────────
  void _showPaymentSheet(BillingPlan plan, Map<String, dynamic> data) {
    final isPending = data['paymentPending'] as bool? ?? false;
    final activePlanKey = data['planName'] as String? ?? 'Free';
    if (isPending || activePlanKey == plan.key) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(
        plan: plan,
        accent: _accent,
        onSubmit: (method, txnId) async {
          await _submitPayment(plan.key, plan.label, plan.price, method, txnId);
        },
      ),
    );
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w500, color: _white),
        ),
        backgroundColor: success ? _green : _amberD,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// =============================================================================
// PLANS TAB
// =============================================================================
class _PlansTab extends StatelessWidget {
  final List<BillingPlan> plans;
  final String activePlanKey;
  final bool isPending;
  final String pendingPlan;
  final int daysLeft;
  final BillingPlan activePlan;
  final Color accent, accentL;
  final bool isTk;
  final void Function(BillingPlan) onSelectPlan;
  final VoidCallback onActivateFree;

  const _PlansTab({
    required this.plans,
    required this.activePlanKey,
    required this.isPending,
    required this.pendingPlan,
    required this.daysLeft,
    required this.activePlan,
    required this.accent,
    required this.accentL,
    required this.isTk,
    required this.onSelectPlan,
    required this.onActivateFree,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Active plan summary card ──────────────────────────────────────
        _ActivePlanCard(
          plan: activePlan,
          daysLeft: daysLeft,
          isPending: isPending,
          pendingPlan: pendingPlan,
          plans: plans,
          accent: accent,
        ),
        const SizedBox(height: 24),

        // ── Pending notice ────────────────────────────────────────────────
        if (isPending && pendingPlan.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF6E3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: _amberD,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Under Review',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _amberD,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your ${_getPlan2(plans, pendingPlan).label} plan will activate once admin approves your payment.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _textSec,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── All plan cards ────────────────────────────────────────────────
        Text(
          'Available Plans',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _textSec,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...plans.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlanCard(
              plan: p,
              isActive: activePlanKey == p.key,
              isPending: isPending && pendingPlan == p.key,
              onTap: p.key == 'Free' ? onActivateFree : () => onSelectPlan(p),
              activePlanKey: activePlanKey,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Feature comparison table ──────────────────────────────────────
        Text(
          'Feature Comparison',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _textSec,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _ComparisonTable(
          plans: plans,
          activePlanKey: activePlanKey,
          accent: accent,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

BillingPlan _getPlan2(List<BillingPlan> list, String key) =>
    list.firstWhere((p) => p.key == key, orElse: () => list.first);

// ── Active plan summary card ───────────────────────────────────────────────
class _ActivePlanCard extends StatelessWidget {
  final BillingPlan plan;
  final int daysLeft;
  final bool isPending;
  final String pendingPlan;
  final List<BillingPlan> plans;
  final Color accent;

  const _ActivePlanCard({
    required this.plan,
    required this.daysLeft,
    required this.isPending,
    required this.pendingPlan,
    required this.plans,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = plan.key == 'Free';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFree
              ? [const Color(0xFF1F2A26), const Color(0xFF1A5C46)]
              : [const Color(0xFF0E3B2E), _colorDarken(plan.fg, 0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Plan',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFA6B2AB),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.label,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  plan.icon,
                  color: isFree ? const Color(0xFFA6B2AB) : plan.fg,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: _white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Billing',
                      style: TextStyle(fontSize: 10, color: Color(0xFFA6B2AB)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.price,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _white,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isFree)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Renews in',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFA6B2AB),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$daysLeft days',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: daysLeft <= 5 ? Colors.red.shade300 : _white,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isFree)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFA6B2AB),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Always free',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (!isFree && daysLeft <= 5) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.shade400.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 13,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Expiring soon — renew to keep access',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade300),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _colorDarken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

// ── Individual plan card ───────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final BillingPlan plan;
  final bool isActive;
  final bool isPending;
  final String activePlanKey; // ADD THIS
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isActive,
    required this.isPending,
    required this.activePlanKey, // ADD THIS
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Locked = another paid plan is active and this isn't it
    final isLocked = !isActive && activePlanKey != 'Free' && plan.key != 'Free';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isActive
            ? plan.bg
            : isLocked
            ? const Color(0xFFF7F5EF)
            : _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? plan.fg.withValues(alpha: 0.5)
              : isLocked
              ? const Color(0xFFE3E0D5)
              : _border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: plan.fg.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Opacity(
        opacity: isLocked ? 0.45 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive
                          ? plan.fg
                          : isLocked
                          ? const Color(0xFFE3E0D5)
                          : plan.accentBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isLocked
                        ? const Icon(
                            Icons.lock_rounded,
                            size: 20,
                            color: Color(0xFFA6B2AB),
                          )
                        : Icon(
                            plan.icon,
                            size: 22,
                            color: isActive ? _white : plan.fg,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plan.label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isLocked
                                    ? const Color(0xFFA6B2AB)
                                    : _textPri,
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _greenL,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _green,
                                  ),
                                ),
                              ),
                            ],
                            if (isPending) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBF6E3),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFE6D694),
                                  ),
                                ),
                                child: const Text(
                                  'Pending',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFA8861D),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plan.price,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isLocked ? const Color(0xFFA6B2AB) : plan.fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isLocked
                        ? Icons.lock_rounded
                        : isActive
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isLocked
                        ? const Color(0xFFA9B5AE)
                        : isActive
                        ? plan.fg
                        : Colors.grey.shade300,
                    size: 22,
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 14),

              // Perks
              ...plan.perks.map(
                (perk) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: isActive
                              ? plan.fg.withValues(alpha: 0.1)
                              : _greenL,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: isActive ? plan.fg : _green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          perk,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isLocked
                                ? const Color(0xFFA6B2AB)
                                : _textPri,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Limitations
              if (plan.limitations.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...plan.limitations.map(
                  (lim) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _redL,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 11,
                            color: _red,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            lim,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSec,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // CTA — hidden when locked or already active
              if (!isLocked &&
                  plan.key != 'Free' &&
                  !isActive &&
                  !isPending) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.fg,
                      foregroundColor: _white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Get ${plan.label}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],

              // Locked label
              if (isLocked) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5EF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE3E0D5)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: Color(0xFFA6B2AB),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Cancel current plan to switch',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA6B2AB),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Free downgrade button
              if (!isLocked &&
                  plan.key == 'Free' &&
                  !isActive &&
                  !isPending) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSec,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Switch to Free',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feature comparison table ───────────────────────────────────────────────
class _ComparisonTable extends StatelessWidget {
  final List<BillingPlan> plans;
  final String activePlanKey;
  final Color accent;
  const _ComparisonTable({
    required this.plans,
    required this.activePlanKey,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    // Build a unified feature list from all perks
    final allFeatures = <String>{};
    for (final p in plans) {
      allFeatures.addAll(p.perks);
    }
    final features = allFeatures.toList();

    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Feature',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textSec,
                    ),
                  ),
                ),
                ...plans.map(
                  (p) => Expanded(
                    child: Text(
                      p.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: activePlanKey == p.key ? accent : _textSec,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),

          // Rows
          ...features.asMap().entries.map((entry) {
            final i = entry.key;
            final feature = entry.value;
            final isLast = i == features.length - 1;
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  color: i.isOdd ? _surface.withValues(alpha: 0.5) : _white,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          feature,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _textPri,
                          ),
                        ),
                      ),
                      ...plans.map((p) {
                        final has = p.perks.contains(feature);
                        return Expanded(
                          child: Center(
                            child: Icon(
                              has
                                  ? Icons.check_circle_rounded
                                  : Icons.remove_rounded,
                              size: 16,
                              color: has
                                  ? (activePlanKey == p.key ? accent : _green)
                                  : Colors.grey.shade300,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1, color: _border),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// HISTORY TAB
// =============================================================================
class _HistoryTab extends StatelessWidget {
  final String uid;
  final Color accent;
  const _HistoryTab({required this.uid, required this.accent});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payment_requests')
          .where('uid', isEqualTo: uid)
          .orderBy('requestedAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _amber));
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 32,
                    color: _textSec,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No payments yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPri,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your payment history will appear here.',
                  style: TextStyle(fontSize: 12, color: _textSec),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final status = d['status'] as String? ?? 'pending';
            final planLabel = d['planLabel'] as String? ?? d['plan'] ?? '';
            final amount = d['amount'] as String? ?? '';
            final method = d['method'] as String? ?? '';
            final txnId = d['txnId'] as String? ?? '';
            final ts = d['requestedAt'] as Timestamp?;
            final date = ts != null
                ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                : '—';

            Color statusColor;
            Color statusBg;
            IconData statusIcon;
            String statusLabel;
            switch (status) {
              case 'approved':
                statusColor = _green;
                statusBg = _greenL;
                statusIcon = Icons.check_circle_rounded;
                statusLabel = 'Approved';
                break;
              case 'rejected':
                statusColor = _red;
                statusBg = _redL;
                statusIcon = Icons.cancel_rounded;
                statusLabel = 'Rejected';
                break;
              default:
                statusColor = _amberD;
                statusBg = _amberL;
                statusIcon = Icons.hourglass_top_rounded;
                statusLabel = 'Pending';
            }

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _amberL,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_outlined,
                                color: _amberD,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    planLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _textPri,
                                    ),
                                  ),
                                  Text(
                                    amount,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: _border),
                  const SizedBox(height: 10),
                  _detailRow(Icons.calendar_today_outlined, 'Date', date),
                  const SizedBox(height: 6),
                  _detailRow(
                    Icons.account_balance_wallet_outlined,
                    'Method',
                    method,
                  ),
                  const SizedBox(height: 6),
                  _detailRow(
                    Icons.confirmation_number_outlined,
                    'TXN ID',
                    txnId,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 13, color: _textSec),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11.5, color: _textSec),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _textPri,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PAYMENT SHEET
// =============================================================================
class _PaymentSheet extends StatefulWidget {
  final BillingPlan plan;
  final Color accent;
  final Future<void> Function(String method, String txnId) onSubmit;
  const _PaymentSheet({
    required this.plan,
    required this.accent,
    required this.onSubmit,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  static const _ep = '03215285689';
  static const _jc = '03467784625';

  final _ctrl = TextEditingController();
  String _method = 'EasyPaisa';
  bool _busy = false, _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the Transaction ID.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    await widget.onSubmit(_method, _ctrl.text.trim());
    if (mounted) {
      setState(() {
        _busy = false;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: _done ? _success() : _form(),
  );

  Widget _success() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _bar(),
      const SizedBox(height: 24),
      Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(color: _greenL, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: _green, size: 38),
      ),
      const SizedBox(height: 16),
      const Text(
        'Payment Request Submitted!',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _amberL,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Your plan will activate automatically once an admin approves your payment. '
          'This usually takes up to 24 hours.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: _amberD, height: 1.5),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _amber,
            foregroundColor: _navy,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Got It',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );

  Widget _form() {
    final num = _method == 'EasyPaisa' ? _ep : _jc;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(), const SizedBox(height: 16),

          // Plan summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.plan.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.plan.fg.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.plan.fg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.plan.icon, color: _white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to ${widget.plan.label}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.plan.price,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.plan.fg,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _stepLabel('Step 1 — Choose payment method'),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip('EasyPaisa', Icons.account_balance_wallet_outlined),
              const SizedBox(width: 10),
              _chip('JazzCash', Icons.payment_outlined),
            ],
          ),
          const SizedBox(height: 20),

          _stepLabel('Step 2 — Send payment to this number'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _amberL,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _method,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _amberD,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      num,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: _textPri,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: num));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _amberD,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 13, color: _white),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Send exactly this amount, then enter the Transaction ID below.',
            style: TextStyle(fontSize: 11, color: _textSec),
          ),

          // Escrow protection info banner
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0E3B2E).withValues(alpha: 0.08), Color(0xFF1A5C46).withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _navy.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _navy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: _navy, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Escrow Protection',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _navy),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Project payments are held securely. A ${(ThekaydaarPlans.commissionRate * 100).toStringAsFixed(1)}% platform fee applies on successful projects.',
                        style: const TextStyle(fontSize: 10.5, color: _textSec, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _stepLabel('Step 3 — Enter Transaction ID from your payment receipt'),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'e.g. TXN123456789',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _amber, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: _navy,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _white,
                      ),
                    )
                  : const Text(
                      'Submit Payment Request',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _bar() => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _stepLabel(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: _textSec,
      letterSpacing: 0.3,
    ),
  );

  Widget _chip(String name, IconData icon) {
    final sel = _method == name;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _method = name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          decoration: BoxDecoration(
            color: sel ? _amberL : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? _amber : Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: sel ? _amberD : Colors.grey.shade400, size: 26),
              const SizedBox(height: 5),
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? _amberD : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
