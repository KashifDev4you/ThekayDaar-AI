// =============================================================================
// connects_screen.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'connects_config.dart';
import 'connects_service.dart';
import 'package:ali_app/Widgets/language_toggle_widget.dart';

class ConnectsScreen extends StatefulWidget {
  const ConnectsScreen({super.key});

  @override
  State<ConnectsScreen> createState() => _ConnectsScreenState();
}

class _ConnectsScreenState extends State<ConnectsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  static const _navy  = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    if (_uid.isNotEmpty) {
      ConnectsService.checkAndExpirePlanConnects(_uid);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: _white,
        elevation: 0,
        title: const Text('Connects',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: LanguageToggleChip(compact: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor          : _amber,
          unselectedLabelColor: Colors.white54,
          indicatorColor      : _amber,
          indicatorWeight     : 2.5,
          tabs: const [
            Tab(text: 'My Connects'),
            Tab(text: 'Buy Connects'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MyConnectsTab(uid: _uid),
          _BuyConnectsTab(uid: _uid),
        ],
      ),
    );
  }
}

// =============================================================================
// MY CONNECTS TAB
// =============================================================================
class _MyConnectsTab extends StatelessWidget {
  final String uid;
  const _MyConnectsTab({required this.uid});

  static const _amber  = Color(0xFFC9A227);
  static const _white  = Colors.white;
  static const _border = Color(0xFFE3E0D5);
  static const _sub    = Color(0xFF5D6B64);
  static const _label  = Color(0xFF1F2A26);
  static const _green  = Color(0xFF0E3B2E);
  static const _red    = Color(0xFFDC2626);
  static const _blue   = Color(0xFF1A5C46);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectsBalance>(
      stream: ConnectsService.streamBalance(uid),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _amber));
        }
        final balance = snap.data!;
        final plan    =
            ThekaydaarPlans.plans[balance.planName] ??
                ThekaydaarPlans.plans['Free']!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Balance hero card ──────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E3B2E), Color(0xFF1F2A26)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color: _amber.withValues(
                                  alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(plan.badge,
                                style: const TextStyle(
                                    fontSize: 12)),
                            const SizedBox(width: 5),
                            Text(balance.planName,
                                style: const TextStyle(
                                    color: _amber,
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.bolt_rounded,
                          color: _amber, size: 20),
                      const SizedBox(width: 4),
                      const Text('Thekaydaar',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Total Connects',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('${balance.totalConnects}',
                      style: const TextStyle(
                          color: _white,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          height: 1.0)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _BalancePill(
                        label: 'Plan',
                        value: '${balance.planConnects}',
                        color: _amber,
                      ),
                      const SizedBox(width: 10),
                      _BalancePill(
                        label: 'Purchased',
                        value: '${balance.purchasedConnects}',
                        color: _blue,
                      ),
                    ],
                  ),
                  if (balance.planExpiry != null &&
                      balance.planConnects > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 13, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(
                          'Plan connects expire '
                          '${DateFormat('dd MMM yyyy').format(balance.planExpiry!)}',
                          style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Connects per bid card ──────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel_rounded,
                          size: 15, color: _sub),
                      SizedBox(width: 6),
                      Text('Connects per Bid',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _label)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ✅ Used as widgets directly, not method calls
                  const _CostRow(
                    label: 'Small project (≤ Rs 10,000)',
                    cost : 1,
                    color: _green,
                  ),
                  const _CostRow(
                    label: 'Medium project (Rs 10k – 50k)',
                    cost : 2,
                    color: _amber,
                  ),
                  const _CostRow(
                    label: 'Large project (> Rs 50,000)',
                    cost : 3,
                    color: _red,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Transaction history ────────────────────────
            const _SectionLabel('Recent Activity'),
            const SizedBox(height: 10),
            _TransactionHistory(uid: uid),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

// =============================================================================
// BUY CONNECTS TAB
// =============================================================================
class _BuyConnectsTab extends StatefulWidget {
  final String uid;
  const _BuyConnectsTab({required this.uid});

  @override
  State<_BuyConnectsTab> createState() => _BuyConnectsTabState();
}

class _BuyConnectsTabState extends State<_BuyConnectsTab> {
  String? _selectedPkg;
  bool    _loading = false;

  static const _navy   = Color(0xFF0E3B2E);
  static const _amber  = Color(0xFFC9A227);
  static const _white  = Colors.white;
  static const _border = Color(0xFFE3E0D5);
  static const _sub    = Color(0xFF5D6B64);
  static const _label  = Color(0xFF1F2A26);
  static const _green  = Color(0xFF0E3B2E);
  static const _blue   = Color(0xFF1A5C46);


  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: _white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _buyPackage(ConnectPackage pkg) async {
    setState(() {
      _selectedPkg = pkg.id;
      _loading     = true;
    });
    try {
      await ConnectsService.addPurchasedConnects(
        uid         : widget.uid,
        amount      : pkg.connects,
        packageLabel: pkg.label,
      );
      _snack('+${pkg.connects} connects added!', _green);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _selectedPkg = null;
          _loading     = false;
        });
      }
    }
  }

  // ✅ build method was missing — added here
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Info banner ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _blue.withValues(alpha: 0.20)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16,
                  color: _blue.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Purchased connects never expire and stack '
                  'on top of your monthly plan connects. '
                  'Plan connects are used first.',
                  style: TextStyle(
                      fontSize: 12,
                      color: _sub,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Connect packages ───────────────────────────────
        const _SectionLabel('Connect Packages'),
        const SizedBox(height: 12),

        ...ThekaydaarPlans.packages.map((pkg) {
          final isSelected = _selectedPkg == pkg.id;
          final isBuying   = _loading && isSelected;
          final isBest     = pkg.id == 'pkg_40';

          return GestureDetector(
            onTap: _loading ? null : () => _buyPackage(pkg),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isBest
                    ? _amber.withValues(alpha: 0.06)
                    : _white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isBest
                      ? _amber.withValues(alpha: 0.5)
                      : _border,
                  width: isBest ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E3B2E)
                          .withValues(alpha: 0.06),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: _amber, size: 20),
                        Text('${pkg.connects}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _label,
                                height: 1.0)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(pkg.label,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w700,
                                    color: _label)),
                            if (isBest) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal: 7,
                                    vertical: 2),
                                decoration: BoxDecoration(
                                  color: _amber,
                                  borderRadius:
                                      BorderRadius.circular(
                                          20),
                                ),
                                child: const Text(
                                    'Best Value',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight:
                                            FontWeight.w800,
                                        color: _white)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Rs ${pkg.priceRs}  •  '
                          '${(pkg.priceRs / pkg.connects).toStringAsFixed(0)} PKR/connect',
                          style: const TextStyle(
                              fontSize: 11.5, color: _sub),
                        ),
                      ],
                    ),
                  ),
                  // Buy button
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _navy,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: isBuying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                                    color: _amber,
                                    strokeWidth: 2))
                        : Text(
                            'Rs ${pkg.priceRs}',
                            style: const TextStyle(
                                color: _amber,
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 24),

        // ── Plan upgrade section ───────────────────────────
        const _SectionLabel(
            'Upgrade Plan for Monthly Connects'),
        const SizedBox(height: 12),

        ...ThekaydaarPlans.plans.values
            .where((p) => p.name != 'Free')
            .map((plan) =>
                _PlanUpgradeCard(plan: plan, uid: widget.uid)),

        const SizedBox(height: 32),
      ],
    );
  }
}

// =============================================================================
// PLAN UPGRADE CARD
// =============================================================================
class _PlanUpgradeCard extends StatelessWidget {
  final PlanConfig plan;
  final String uid;

  static const _navy   = Color(0xFF0E3B2E);
  static const _amber  = Color(0xFFC9A227);
  static const _white  = Colors.white;
  static const _border = Color(0xFFE3E0D5);
  static const _sub    = Color(0xFF5D6B64);
  static const _label  = Color(0xFF1F2A26);

  static const _purple = Color(0xFF0E3B2E);

  const _PlanUpgradeCard(
      {required this.plan, required this.uid});

  @override
  Widget build(BuildContext context) {
    final isPopular = plan.name == 'Pro';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPopular
            ? _purple.withValues(alpha: 0.05)
            : _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPopular
              ? _purple.withValues(alpha: 0.4)
              : _border,
          width: isPopular ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.badge,
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(plan.name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _label)),
                        if (isPopular) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _purple,
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: const Text('Popular',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight:
                                        FontWeight.w800,
                                    color: _white)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Rs ${plan.priceMonthly}/month',
                      style: const TextStyle(
                          fontSize: 12, color: _sub),
                    ),
                  ],
                ),
              ),
              // Monthly connects badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _amber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text('${plan.monthlyConnects}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFA8861D),
                            height: 1.0)),
                    const Text('connects',
                        style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFFA8861D))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(plan.description,
              style: const TextStyle(
                  fontSize: 12, color: _sub, height: 1.4)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _FeatureChip('${plan.monthlyConnects} connects/month'),
              if (plan.profileVisible)
                const _FeatureChip('Profile visible'),
              if (plan.name == 'Business')
                const _FeatureChip('Featured badge'),
              if (plan.name != 'Basic')
                const _FeatureChip('Priority search'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: navigate to your BillingScreen
                // pass planName: plan.name
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(
                  content: Text(
                      'Redirecting to payment for ${plan.name}…'),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isPopular ? _purple : _navy,
                foregroundColor: _white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(10)),
              ),
              child: Text(
                'Upgrade to ${plan.name}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TRANSACTION HISTORY
// =============================================================================
class _TransactionHistory extends StatelessWidget {
  final String uid;

  static const _border = Color(0xFFE3E0D5);
  static const _sub    = Color(0xFF5D6B64);
  static const _label  = Color(0xFF1F2A26);
  static const _green  = Color(0xFF0E3B2E);
  static const _red    = Color(0xFFDC2626);
  static const _amber  = Color(0xFFC9A227);
  static const _blue   = Color(0xFF1A5C46);

  const _TransactionHistory({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('connects_transactions')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  color: _amber, strokeWidth: 2),
            ),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: const Center(
              child: Text('No activity yet.',
                  style: TextStyle(
                      color: _sub, fontSize: 13)),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: docs.map((doc) {
              final d    = doc.data() as Map<String, dynamic>;
              final type = d['type']        as String? ?? '';
              final amt  = (d['amount']     as int?)   ?? 0;
              final desc = d['description'] as String? ?? '';
              final ts   = d['createdAt']   as Timestamp?;
              final time = ts != null
                  ? DateFormat('dd MMM, hh:mm a')
                      .format(ts.toDate())
                  : '';

              final (icon, color) = switch (type) {
                'bid_spend'  => (Icons.gavel_rounded,           _red),
                'purchase'   => (Icons.shopping_bag_outlined,   _blue),
                'plan_grant' => (Icons.card_membership_rounded, _green),
                _            => (Icons.bolt_rounded,            _amber),
              };

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: _border)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Icon(icon,
                          color: color, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(desc,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: _label)),
                          if (time.isNotEmpty)
                            Text(time,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: _sub)),
                        ],
                      ),
                    ),
                    Text(
                      amt > 0 ? '+$amt' : '$amt',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: amt > 0 ? _green : _red),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// =============================================================================
// SHARED WIDGETS — all defined as top-level classes
// ✅ These must be top-level (not nested inside other classes)
// =============================================================================

class _BalancePill extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;

  const _BalancePill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color.withValues(alpha: 0.75),
                    fontSize: 11)),
          ],
        ),
      );
}

class _CostRow extends StatelessWidget {
  final String label;
  final int    cost;
  final Color  color;

  static const _sub   = Color(0xFF5D6B64);
 
  const _CostRow({
    required this.label,
    required this.cost,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded,
                size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12.5, color: _sub)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$cost connect${cost > 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  static const _sub = Color(0xFF5D6B64);

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _sub,
            letterSpacing: 0.8),
      );
}

class _FeatureChip extends StatelessWidget {
  final String text;
  static const _green = Color(0xFF0E3B2E);

  const _FeatureChip(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _green.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded,
                size: 11,
                color: _green.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(text,
                style: const TextStyle(
                    fontSize: 11,
                    color: _green,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}