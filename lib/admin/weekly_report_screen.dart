// ignore: file_names
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Add this to pubspec.yaml (run: flutter pub add share_plus) if you want
// the "Share Report" button to work. Safe to remove if you don't need it.
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS — matches the rest of the admin app
// ─────────────────────────────────────────────────────────────────────────────

// Matches the palette used in super_admin_dashboard_screen.dart
// (_dNavy, _dAmber, _dGreen, etc.) — kept under _T here since this file's
// tokens are private to this file anyway, just with the same values.
class _T {
  static const navy      = Color(0xFF0E3B2E); // _dNavy
  static const navyLight = Color(0xFF1F2A26); // same hex as _dLabel
  static const white     = Color(0xFFFFFFFF); // _dWhite
  static const bg        = Color(0xFFF7F5EF); // _dFill
  static const amber     = Color(0xFFC9A227); // _dAmber
  static const amberDark = Color(0xFFC9A227); // unified with amber — dashboard has no second shade
  static const green     = Color(0xFF10B981); // _dGreen
  static const red       = Color(0xFFDC2626); // _dRed
  static const blue      = Color(0xFF1A5C46); // _dBlue
  static const purple    = Color(0xFFC9A227); // _dPurple

  static const slate200  = Color(0xFFE3E0D5); // _dBorder
  static const slate400  = Color(0xFFA6B2AB); // unselected/hint gray used in dashboard
  static const slate500  = Color(0xFF5D6B64); // _dSub
  static const slate700  = Color(0xFF1F2A26); // unified with _dLabel
  static const slate800  = Color(0xFF1F2A26); // _dLabel
  static const card      = Color(0xFFFFFFFF); // _dWhite

  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r14 = BorderRadius.all(Radius.circular(14));
  static const r16 = BorderRadius.all(Radius.circular(16));

  // Matches the card style in _UserCard: radius 14, border _dBorder,
  // shadow alpha .04 blur 8 offset (0,2).
  static BoxDecoration cardDecor({Color? border}) => BoxDecoration(
        color: card,
        borderRadius: r14,
        border: Border.all(color: border ?? slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL — everything the screen needs, fetched in one shot
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyStats {
  final num totalRevenue;
  final num planRevenue;
  final num projectRevenue;
  final int approvedPaymentCount;

  final int newClients;
  final int pendingNicReviews; // snapshot as of now, not week-bound
  final int suspendedAccounts; // snapshot as of now, not week-bound

  // Previous week, for the delta arrows
  final num prevRevenue;
  final int prevNewClients;

  const _WeeklyStats({
    required this.totalRevenue,
    required this.planRevenue,
    required this.projectRevenue,
    required this.approvedPaymentCount,
    required this.newClients,
    required this.pendingNicReviews,
    required this.suspendedAccounts,
    required this.prevRevenue,
    required this.prevNewClients,
  });

  double get revenueChangePct =>
      prevRevenue == 0 ? 0 : ((totalRevenue - prevRevenue) / prevRevenue) * 100;

  double get clientsChangePct => prevNewClients == 0
      ? 0
      : ((newClients - prevNewClients) / prevNewClients) * 100;
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class WeeklyReportScreen extends StatefulWidget {
  // Pass null for Super Admin (global, all cities).
  // Pass the admin's city for Regional Admin (scoped to that city only).
  //
  // Usage:
  //   Navigator.push(context, MaterialPageRoute(
  //     builder: (_) => const WeeklyReportScreen(city: null), // Super Admin
  //   ));
  //   Navigator.push(context, MaterialPageRoute(
  //     builder: (_) => WeeklyReportScreen(city: regionalAdmin.city), // Regional Admin
  //   ));
  final String? city;
  const WeeklyReportScreen({super.key, this.city});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  // 0 = current week, -1 = last week, -2 = two weeks ago, etc.
  int _weekOffset = 0;
  late Future<_WeeklyStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  // Week runs Monday → Sunday. Adjust here if your business week differs.
  ({DateTime start, DateTime end}) _weekRange(int offset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mondayThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final start = mondayThisWeek.add(Duration(days: 7 * offset));
    final end = start.add(const Duration(days: 7));
    return (start: start, end: end);
  }

  Future<_WeeklyStats> _loadStats() async {
    final current = _weekRange(_weekOffset);
    final previous = _weekRange(_weekOffset - 1);

    final results = await Future.wait([
      _fetchRevenue(current.start, current.end, widget.city),
      _fetchRevenue(previous.start, previous.end, widget.city),
      _fetchNewClients(current.start, current.end, widget.city),
      _fetchNewClients(previous.start, previous.end, widget.city),
      _fetchPendingNicCount(widget.city),
      _fetchSuspendedCount(widget.city),
    ]);

    final currentRevenue = results[0] as _RevenueResult;
    final previousRevenue = results[1] as _RevenueResult;
    final currentClients = results[2] as int;
    final previousClients = results[3] as int;
    final pendingNic = results[4] as int;
    final suspended = results[5] as int;

    return _WeeklyStats(
      totalRevenue: currentRevenue.total,
      planRevenue: currentRevenue.plan,
      projectRevenue: currentRevenue.project,
      approvedPaymentCount: currentRevenue.count,
      newClients: currentClients,
      pendingNicReviews: pendingNic,
      suspendedAccounts: suspended,
      prevRevenue: previousRevenue.total,
      prevNewClients: previousClients,
    );
  }

  // ── Firestore helpers ─────────────────────────────────────────
  // NOTE: these assume 'payment_requests' docs have: amount (num),
  // status ('approved'/'completed'/'pending'), type ('plan'/'subscription'/
  // 'upgrade' vs everything else), createdAt (Timestamp).
  // Adjust field names below if yours differ.
  //
  // CITY SCOPING: when `city` is non-null (Regional Admin), these filter
  // by a 'city' field on each document. 'clients' already has 'city' per
  // your schema. If 'payment_requests' docs don't yet store a 'city'
  // field, add one when you create them — it's the simplest way to scope
  // revenue per city without extra lookups.

  Future<_RevenueResult> _fetchRevenue(
      DateTime start, DateTime end, String? city) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('payment_requests')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end));
    if (city != null) {
      query = query.where('city', isEqualTo: city);
    }
    final snap = await query.get();

    num total = 0, plan = 0, project = 0;
    int count = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final status = (data['status'] as String?) ?? '';
      if (status != 'approved' && status != 'completed') continue;

      final amount = (data['amount'] as num?) ?? 0;
      final type = (data['type'] as String?) ?? '';
      final isPlan = type == 'plan' || type == 'subscription' || type == 'upgrade';

      total += amount;
      count++;
      if (isPlan) {
        plan += amount;
      } else {
        project += amount;
      }
    }

    return _RevenueResult(total: total, plan: plan, project: project, count: count);
  }

  Future<int> _fetchNewClients(
      DateTime start, DateTime end, String? city) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('clients')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end));
    if (city != null) {
      query = query.where('city', isEqualTo: city);
    }
    final snap = await query.get();
    return snap.docs.length;
  }

  Future<int> _fetchPendingNicCount(String? city) async {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('clients');
    if (city != null) {
      query = query.where('city', isEqualTo: city);
    }
    final snap = await query.get();
    return snap.docs.where((d) {
      final data = d.data();
      final hasImages =
          data['nic_front_url'] != null && data['nic_back_url'] != null;
      return hasImages && data['nic_approved'] != true;
    }).length;
  }

  Future<int> _fetchSuspendedCount(String? city) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('clients')
        .where('accountStatus', isEqualTo: 'suspended');
    if (city != null) {
      query = query.where('city', isEqualTo: city);
    }
    final snap = await query.get();
    return snap.docs.length;
  }

  void _changeWeek(int delta) {
    setState(() {
      _weekOffset += delta;
      _statsFuture = _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = _weekRange(_weekOffset);
    final label = _weekLabel(range.start, range.end);

    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.navy,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _T.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text('Weekly Report',
                style: TextStyle(
                    color: _T.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2)),
            Text(
              widget.city == null ? 'All Cities' : widget.city!,
              style: const TextStyle(color: _T.slate400, fontSize: 11),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _WeekSelector(
            label: label,
            canGoForward: _weekOffset < 0,
            onPrevious: () => _changeWeek(-1),
            onNext: () => _changeWeek(1),
          ),
          Expanded(
            child: FutureBuilder<_WeeklyStats>(
              future: _statsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _T.amber));
                }
                if (snap.hasError) {
                  return _ErrorState(error: snap.error.toString());
                }

                final stats = snap.data!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _RevenueHero(stats: stats),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.person_add_alt_1_rounded,
                            color: _T.blue,
                            label: 'New Clients',
                            value: stats.newClients.toString(),
                            deltaPct: stats.clientsChangePct,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.receipt_long_rounded,
                            color: _T.purple,
                            label: 'Payments',
                            value: stats.approvedPaymentCount.toString(),
                            sublabel: 'this week',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.hourglass_top_rounded,
                            color: _T.amberDark,
                            label: 'Pending NIC',
                            value: stats.pendingNicReviews.toString(),
                            sublabel: 'as of today',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.block_rounded,
                            color: _T.red,
                            label: 'Suspended',
                            value: stats.suspendedAccounts.toString(),
                            sublabel: 'as of today',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _RevenueBreakdown(stats: stats),
                    const SizedBox(height: 20),
                    _ShareButton(
                      label: label,
                      stats: stats,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _weekLabel(DateTime start, DateTime end) {
    final last = end.subtract(const Duration(days: 1));
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final sameMonth = start.month == last.month;
    final startStr = '${start.day} ${months[start.month - 1]}';
    final endStr = sameMonth
        ? '${last.day} ${months[last.month - 1]}'
        : '${last.day} ${months[last.month - 1]}';
    return '$startStr – $endStr, ${last.year}';
  }
}

class _RevenueResult {
  final num total, plan, project;
  final int count;
  const _RevenueResult(
      {required this.total, required this.plan, required this.project, required this.count});
}

// ─────────────────────────────────────────────────────────────────────────────
// WEEK SELECTOR
// ─────────────────────────────────────────────────────────────────────────────

class _WeekSelector extends StatelessWidget {
  final String label;
  final bool canGoForward;
  final VoidCallback onPrevious, onNext;
  const _WeekSelector({
    required this.label,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _T.navy,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: _T.white),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Center(
              child: Text(label,
                  style: const TextStyle(
                      color: _T.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded,
                color: canGoForward ? _T.white : _T.slate400),
            onPressed: canGoForward ? onNext : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVENUE HERO
// ─────────────────────────────────────────────────────────────────────────────

class _RevenueHero extends StatelessWidget {
  final _WeeklyStats stats;
  const _RevenueHero({required this.stats});

  @override
  Widget build(BuildContext context) {
    final up = stats.revenueChangePct >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_T.navy, _T.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: _T.r16,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _T.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: _T.amber, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Revenue This Week',
                    style: TextStyle(
                        color: _T.slate400,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Rs ${_formatAmount(stats.totalRevenue)}',
                  style: const TextStyle(
                      color: _T.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
              ],
            ),
          ),
          if (stats.prevRevenue > 0 || stats.totalRevenue > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: (up ? _T.green : _T.red).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 13,
                    color: up ? _T.green : _T.red,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${stats.revenueChangePct.abs().toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: up ? _T.green : _T.red),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METRIC CARD (small, reused for clients/payments/nic/suspended)
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  final String? sublabel;
  final double? deltaPct;
  const _MetricCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.sublabel,
    this.deltaPct,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _T.cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const Spacer(),
              if (deltaPct != null)
                Row(
                  children: [
                    Icon(
                      deltaPct! >= 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 11,
                      color: deltaPct! >= 0 ? _T.green : _T.red,
                    ),
                    Text(
                      '${deltaPct!.abs().toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: deltaPct! >= 0 ? _T.green : _T.red),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _T.slate800,
                  letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: _T.slate500,
                  fontWeight: FontWeight.w600)),
          if (sublabel != null)
            Text(sublabel!,
                style: const TextStyle(fontSize: 9.5, color: _T.slate400)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVENUE BREAKDOWN (plan vs project, same pattern as the client card)
// ─────────────────────────────────────────────────────────────────────────────

class _RevenueBreakdown extends StatelessWidget {
  final _WeeklyStats stats;
  const _RevenueBreakdown({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.totalRevenue == 0 ? 1 : stats.totalRevenue;
    final planRatio = stats.planRevenue / total;
    final projectRatio = stats.projectRevenue / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _T.cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 13,
                decoration: BoxDecoration(
                    color: _T.amber, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 7),
              const Text('Where Revenue Came From',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _T.slate500,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          _breakdownRow(
            icon: Icons.workspace_premium_rounded,
            color: _T.purple,
            label: 'Plan & Subscriptions',
            amount: stats.planRevenue,
            ratio: planRatio.toDouble(),
          ),
          const SizedBox(height: 14),
          _breakdownRow(
            icon: Icons.engineering_rounded,
            color: _T.blue,
            label: 'Contractor Payments',
            amount: stats.projectRevenue,
            ratio: projectRatio.toDouble(),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow({
    required IconData icon,
    required Color color,
    required String label,
    required num amount,
    required double ratio,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _T.slate700)),
            ),
            Text('Rs ${_formatAmount(amount)}',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: _T.slate200,
            valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _ShareButton extends StatelessWidget {
  final String label;
  final _WeeklyStats stats;
  const _ShareButton({required this.label, required this.stats});

  String _buildText() {
    return '''
📊 Weekly Report — $label

💰 Total Revenue: Rs ${_formatAmount(stats.totalRevenue)}
   • Plans: Rs ${_formatAmount(stats.planRevenue)}
   • Contractor payments: Rs ${_formatAmount(stats.projectRevenue)}

👥 New Clients: ${stats.newClients}
🧾 Payments processed: ${stats.approvedPaymentCount}
⏳ Pending NIC reviews: ${stats.pendingNicReviews}
🚫 Suspended accounts: ${stats.suspendedAccounts}
''';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final text = _buildText();
        // Requires share_plus — falls back to clipboard copy if removed.
        try {
          SharePlus.instance.share(
            ShareParams(text: text, subject: 'Weekly Report — $label'),
          );
        } catch (_) {
          Clipboard.setData(ClipboardData(text: text));
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _T.amber,
          borderRadius: _T.r12,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ios_share_rounded, size: 17, color: _T.navy),
            SizedBox(width: 8),
            Text('Share Report',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _T.navy)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _T.red, size: 40),
            const SizedBox(height: 12),
            const Text('Could not load report',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _T.slate700)),
            const SizedBox(height: 6),
            Text(
              error,
              style: const TextStyle(fontSize: 11, color: _T.slate400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _formatAmount(num n) {
  if (n == 0) return '0';
  if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)}Cr';
  if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toStringAsFixed(0);
}