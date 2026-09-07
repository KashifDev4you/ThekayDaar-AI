import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _T {
  static const navy       = Color(0xFF0E3B2E);
  static const navyLight  = Color(0xFF1F2A26);
  static const white      = Color(0xFFFFFFFF);
  static const bg         = Color(0xFFF7F5EF);
  static const amber      = Color(0xFFC9A227);
  static const amberDark  = Color(0xFFA8861D);
  static const green      = Color(0xFF10B981);
  static const red        = Color(0xFFDC2626);
  static const blue       = Color(0xFF1A5C46);
  static const slate100   = Color(0xFFF7F5EF);
  static const slate200   = Color(0xFFE3E0D5);
  static const slate400   = Color(0xFFA6B2AB);
  static const slate500   = Color(0xFF5D6B64);
  static const slate700   = Color(0xFF1F2A26);
  static const slate800   = Color(0xFF1F2A26);
  static const purple     = Color(0xFFC9A227);
  static const card       = Color(0xFFFFFFFF);

  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));


  static BoxDecoration cardDecor({Color? border}) => BoxDecoration(
        color: card,
        borderRadius: r16,
        border: Border.all(color: border ?? slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AreaHandlerClientsScreen extends StatefulWidget {
  final String city, area;
  const AreaHandlerClientsScreen(
      {super.key, required this.city, required this.area});

  @override
  State<AreaHandlerClientsScreen> createState() =>
      _AreaHandlerClientsScreenState();
}

class _AreaHandlerClientsScreenState
    extends State<AreaHandlerClientsScreen> {
  String _filter = 'all'; // all | pending | approved | suspended

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _FilterBar(
            selected: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          Expanded(child: _ClientList(
            city: widget.city,
            area: widget.area,
            filter: _filter,
          )),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
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
          const Text('Clients',
              style: TextStyle(
                  color: _T.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2)),
          Text(
            '${widget.area} · ${widget.city}',
            style: const TextStyle(color: _T.slate400, fontSize: 11),
          ),
        ],
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER BAR
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterBar({required this.selected, required this.onChanged});

  static const _tabs = [
    ('all', 'All'),
    ('pending', 'Pending NIC'),
    ('approved', 'Approved'),
    ('suspended', 'Suspended'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _T.navy,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(
          children: _tabs.map((t) {
            final active = selected == t.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active
                        ? _T.amber
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(t.$2,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? _T.navy : _T.slate400)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLIENT LIST
// ─────────────────────────────────────────────────────────────────────────────

class _ClientList extends StatelessWidget {
  final String city, area, filter;
  const _ClientList(
      {required this.city, required this.area, required this.filter});

  Stream<QuerySnapshot> get _stream {
    var q = FirebaseFirestore.instance
        .collection('clients')
        .where('city', isEqualTo: city)
        .where('area', isEqualTo: area);
    return q.snapshots();
  }

  bool _matches(Map<String, dynamic> d) {
    if (filter == 'all') return true;
    if (filter == 'approved') return d['nic_approved'] == true;
    if (filter == 'suspended') return d['accountStatus'] == 'suspended';
    if (filter == 'pending') {
      final hasImages =
          d['nic_front_url'] != null && d['nic_back_url'] != null;
      return hasImages && d['nic_approved'] != true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _T.amber));
        }

        final all  = snap.data?.docs ?? [];
        final docs = all
            .where((d) => _matches(d.data() as Map<String, dynamic>))
            .toList();

        if (docs.isEmpty) return _EmptyState(filter: filter);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, i) {
            final d   = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            return _ClientCard(uid: uid, data: d);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final labels = {
      'all'      : ('No clients yet', 'No clients have registered in this area.'),
      'pending'  : ('No pending reviews', 'All NIC documents have been reviewed.'),
      'approved' : ('None approved yet', 'No clients have been NIC verified.'),
      'suspended': ('None suspended', 'No accounts are currently suspended.'),
    };
    final (title, sub) = labels[filter]!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _T.slate200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.people_outline_rounded,
                size: 32, color: _T.slate400),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _T.slate700)),
          const SizedBox(height: 6),
          Text(sub,
              style: const TextStyle(fontSize: 13, color: _T.slate400),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLIENT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ClientCard extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _ClientCard({required this.uid, required this.data});

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {

  Future<void> _toggleNicApproval(bool current) async {
    await FirebaseFirestore.instance
        .collection('clients')
        .doc(widget.uid)
        .update({'nic_approved': !current});
  }

  Future<void> _toggleSuspend(String current) async {
    final next = current == 'active' ? 'suspended' : 'active';
    await FirebaseFirestore.instance
        .collection('clients')
        .doc(widget.uid)
        .update({'accountStatus': next});
  }

  void _copyToClipboard(BuildContext ctx, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text('$label copied'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      backgroundColor: _T.navyLight,
    ));
  }

  void _openNicViewer(
    BuildContext context,
    String? frontUrl,
    String? backUrl, {
    int startIndex = 0,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _NicViewerSheet(
        frontUrl: frontUrl,
        backUrl: backUrl,
        startIndex: startIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    // ── Field extraction ──────────────────────────────────────
    final name          = d['fullName']        as String? ?? '—';
    final phone         = d['phone']           as String? ?? '—';
    final email         = d['email']           as String? ?? '';
    final displayId     = d['displayId']       as String? ?? '—';
    final planName      = d['planName']        as String? ?? 'Free';
    final nicNumber     = d['nicNumber']       as String? ?? '—';
    final nicFrontUrl   = d['nic_front_url']   as String?;
    final nicBackUrl    = d['nic_back_url']    as String?;
    final nicApproved   = d['nic_approved']    as bool?   ?? false;
    final isPremium     = d['isPremium']       as bool?   ?? false;
    final verifiedBadge = d['verifiedBadge']   as bool?   ?? false;
    final profilePic    = d['profilePic']      as String?;
    final accountStatus = d['accountStatus']   as String? ?? 'active';
    final totalProjects    = d['totalProjects']      as int?  ?? 0;
    final activeProjects   = d['activeProjects']     as int?  ?? 0;
    final completedProjects= d['completedProjects']  as int?  ?? 0;
    final totalSpent       = d['totalSpent']         as num?  ?? 0;
    // Spending breakdown — money paid to contractors for completed work


    final rating           = d['rating']             as num?  ?? 0.0;
    final totalReviews     = d['totalReviews']       as int?  ?? 0;
    final memberSince      = d['createdAt']          as Timestamp?;
    final lastActive       = d['lastActive']         as Timestamp?;
    final city             = d['city']               as String? ?? '—';
    final area             = d['area']               as String? ?? '—';

    final isSuspended   = accountStatus == 'suspended';
    final memberDate    = memberSince != null
        ? _formatDate(memberSince.toDate())
        : '—';
    final lastActiveStr = lastActive != null
        ? _timeAgo(lastActive.toDate())
        : '—';

    return Container(
      decoration: _T.cardDecor(
        border: isSuspended
            ? _T.red.withValues(alpha: 0.25)
            : nicApproved
                ? _T.green.withValues(alpha: 0.20)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ══════════════════════════════════════════════════════
          // SECTION 1 — Header
          // ══════════════════════════════════════════════════════
          _buildHeader(context, name, displayId, phone, profilePic,
              verifiedBadge, isPremium, planName, accountStatus, isSuspended),

          _divider(),

          // ══════════════════════════════════════════════════════
          // SECTION 2 — Quick Stats Row
          // ══════════════════════════════════════════════════════
          _buildStatsRow(totalProjects, activeProjects,
              completedProjects, totalSpent, rating, totalReviews),

          _divider(),

          // ══════════════════════════════════════════════════════
          // SECTION 3 — Key Info Grid
          // ══════════════════════════════════════════════════════
          _buildInfoGrid(context, nicNumber, phone, email, city, area,
              memberDate, lastActiveStr),

          _divider(),

          // ══════════════════════════════════════════════════════
          // SECTION 4 — Spending Breakdown (live from payment_requests)
          // ══════════════════════════════════════════════════════
          _buildSpendingSection(planName, isPremium),

          _divider(),

          // ══════════════════════════════════════════════════════
          // SECTION 5 — NIC Verification
          // ══════════════════════════════════════════════════════
          _buildNicSection(context, nicApproved, nicFrontUrl, nicBackUrl),

          // ══════════════════════════════════════════════════════
          // SECTION 6 — Actions footer
          // ══════════════════════════════════════════════════════
          _buildActionsFooter(context, accountStatus, isSuspended, displayId),
        ],
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    String name,
    String displayId,
    String phone,
    String? profilePic,
    bool verifiedBadge,
    bool isPremium,
    String planName,
    String accountStatus,
    bool isSuspended,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _T.purple.withValues(alpha: 0.12),
                backgroundImage:
                    profilePic != null ? NetworkImage(profilePic) : null,
                child: profilePic == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: _T.purple,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      )
                    : null,
              ),
              // Green dot for active, red for suspended
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isSuspended ? _T.red : _T.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: _T.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Name + IDs
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _T.slate800,
                              letterSpacing: -0.2)),
                    ),
                    if (verifiedBadge) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified_rounded,
                          size: 15, color: _T.blue),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(displayId,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _T.slate400,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3)),
                Text(phone,
                    style: const TextStyle(
                        fontSize: 11, color: _T.slate400)),
              ],
            ),
          ),

          // Badges column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Pill(
                label: isSuspended ? 'Suspended' : 'Active',
                color: isSuspended ? _T.red : _T.green,
              ),
              if (isPremium) ...[
                const SizedBox(height: 4),
                _Pill(
                  label: planName.isEmpty ? 'Premium' : planName,
                  color: _T.amberDark,
                  icon: Icons.workspace_premium_rounded,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── STATS ROW ────────────────────────────────────────────────
  Widget _buildStatsRow(int total, int active, int completed,
      num spent, num rating, int reviews) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          _StatCell(
              value: total.toString(),
              label: 'Total',
              sublabel: 'Projects',
              icon: Icons.folder_copy_outlined,
              color: _T.blue),
          _vDivider(),
          _StatCell(
              value: active.toString(),
              label: 'Active',
              sublabel: 'Running',
              icon: Icons.play_circle_outline_rounded,
              color: _T.green),
          _vDivider(),
          _StatCell(
              value: completed.toString(),
              label: 'Done',
              sublabel: 'Completed',
              icon: Icons.check_circle_outline_rounded,
              color: _T.purple),
          _vDivider(),
          _StatCell(
              value: reviews > 0 ? rating.toStringAsFixed(1) : '—',
              label: 'Rating',
              sublabel: reviews > 0 ? '$reviews reviews' : 'No reviews',
              icon: Icons.star_rounded,
              color: _T.amber),
        ],
      ),
    );
  }

  // ── SPENDING SECTION (live from payment_requests) ────────────
  Widget _buildSpendingSection(String planName, bool isPremium) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Spending Breakdown'),
          const SizedBox(height: 14),

          // ── Current plan tile ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isPremium
                  ? _T.amberDark.withValues(alpha: 0.07)
                  : _T.slate100,
              borderRadius: _T.r12,
              border: Border.all(
                color: isPremium
                    ? _T.amberDark.withValues(alpha: 0.25)
                    : _T.slate200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isPremium
                        ? _T.amberDark.withValues(alpha: 0.12)
                        : _T.slate200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPremium
                        ? Icons.workspace_premium_rounded
                        : Icons.person_outline_rounded,
                    color: isPremium ? _T.amberDark : _T.slate400,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Plan',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _T.slate400,
                              letterSpacing: 0.3)),
                      const SizedBox(height: 3),
                      Text(
                        planName.isEmpty ? 'Free' : planName,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isPremium ? _T.amberDark : _T.slate700,
                            letterSpacing: -0.2),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPremium
                        ? _T.amberDark.withValues(alpha: 0.12)
                        : _T.slate200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPremium ? 'Subscribed' : 'Free Tier',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isPremium ? _T.amberDark : _T.slate500),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Live payment_requests StreamBuilder ──────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('payment_requests')
                .where('userId', isEqualTo: widget.uid)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: _T.amber, strokeWidth: 2)),
                );
              }

              final docs = snap.data?.docs ?? [];

              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _T.slate100,
                    borderRadius: _T.r12,
                    border: Border.all(color: _T.slate200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _T.slate200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_outlined,
                            color: _T.slate400, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No payment history yet.\nTransactions will appear here once the client pays.',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: _T.slate400,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // ── Compute totals from real payment docs ────────
              num totalPaid      = 0;
              num planPaid       = 0;
              num projectPaid    = 0;
              num pendingAmount  = 0;
              int approvedCount  = 0;
              int pendingCount   = 0;

              // Track individual plan payments for listing
              final List<Map<String, dynamic>> planPayments   = [];
              final List<Map<String, dynamic>> projectPayments = [];

              for (final doc in docs) {
                final data   = doc.data() as Map<String, dynamic>;
                final amount = (data['amount'] as num?) ?? 0;
                final status = (data['status'] as String?) ?? '';
                final type   = (data['type']   as String?) ?? '';
                // 'plan', 'subscription', 'upgrade' → plan fee
                // 'project', 'payment'              → contractor payment
                final isPlanPayment = type == 'plan' ||
                    type == 'subscription' ||
                    type == 'upgrade';

                if (status == 'approved' || status == 'completed') {
                  totalPaid += amount;
                  approvedCount++;
                  if (isPlanPayment) {
                    planPaid += amount;
                    planPayments.add(data);
                  } else {
                    projectPaid += amount;
                    projectPayments.add(data);
                  }
                } else if (status == 'pending') {
                  pendingAmount += amount;
                  pendingCount++;
                }
              }

              final planRatio    = totalPaid > 0 ? planPaid    / totalPaid : 0.0;
              final projectRatio = totalPaid > 0 ? projectPaid / totalPaid : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Total hero tile ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _T.amberDark.withValues(alpha: 0.12),
                          _T.amber.withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: _T.r12,
                      border: Border.all(
                          color: _T.amberDark.withValues(alpha: 0.20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _T.amberDark.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: _T.amberDark,
                              size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Paid',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _T.slate500,
                                      letterSpacing: 0.3)),
                              const SizedBox(height: 4),
                              Text(
                                'Rs ${_formatAmount(totalPaid)}',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: _T.amberDark,
                                    letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$approvedCount payment${approvedCount == 1 ? '' : 's'} confirmed',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: _T.slate400),
                              ),
                            ],
                          ),
                        ),
                        // Pending badge
                        if (pendingCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _T.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _T.red.withValues(alpha: 0.22)),
                            ),
                            child: Column(
                              children: [
                                const Text('Pending',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: _T.red)),
                                const SizedBox(height: 2),
                                Text(
                                  'Rs ${_compactNum(pendingAmount)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _T.red),
                                ),
                                Text(
                                  '$pendingCount txn',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: _T.red),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Breakdown container ──────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _T.slate100,
                      borderRadius: _T.r12,
                      border: Border.all(color: _T.slate200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Where did this money go?',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _T.slate500,
                                letterSpacing: 0.2)),
                        const SizedBox(height: 14),

                        // ── Plan/Subscription row ────────────
                        _SpendRow(
                          icon: Icons.workspace_premium_rounded,
                          color: _T.purple,
                          label: 'Plan & Subscription Fees',
                          sublabel: planPayments.isEmpty
                              ? 'No plan payments found'
                              : '${planPayments.length} payment${planPayments.length == 1 ? '' : 's'} · Paid for ${planName.isEmpty ? "Free" : planName} plan',
                          amount: planPaid,
                          ratio: planRatio.toDouble(),
                          hasData: planPayments.isNotEmpty,
                        ),
                        const SizedBox(height: 14),

                        // ── Project payments row ─────────────
                        _SpendRow(
                          icon: Icons.engineering_rounded,
                          color: _T.blue,
                          label: 'Paid to Contractors',
                          sublabel: projectPayments.isEmpty
                              ? 'No contractor payments yet'
                              : '${projectPayments.length} payment${projectPayments.length == 1 ? '' : 's'} · For completed projects',
                          amount: projectPaid,
                          ratio: projectRatio.toDouble(),
                          hasData: projectPayments.isNotEmpty,
                        ),

                        // ── Pending row — only if exists ─────
                        if (pendingCount > 0) ...[
                          const SizedBox(height: 14),
                          _SpendRow(
                            icon: Icons.pending_actions_rounded,
                            color: _T.red,
                            label: 'Awaiting Approval',
                            sublabel:
                                '$pendingCount request${pendingCount == 1 ? '' : 's'} submitted, not yet verified',
                            amount: pendingAmount,
                            ratio: totalPaid > 0
                                ? (pendingAmount / (totalPaid + pendingAmount))
                                    .toDouble()
                                : 1.0,
                            hasData: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── INFO GRID ────────────────────────────────────────────────
  Widget _buildInfoGrid(
    BuildContext context,
    String nicNumber,
    String phone,
    String email,
    String city,
    String area,
    String memberDate,
    String lastActive,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Client Information'),
          const SizedBox(height: 12),
          // 2-column grid of info rows
          Wrap(
            spacing: 0,
            runSpacing: 10,
            children: [
              _InfoTile(
                icon: Icons.badge_outlined,
                label: 'NIC Number',
                value: nicNumber,
                onCopy: () =>
                    _copyToClipboard(context, nicNumber, 'NIC number'),
              ),
              _InfoTile(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: phone,
                onCopy: () =>
                    _copyToClipboard(context, phone, 'Phone'),
              ),
              if (email.isNotEmpty)
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                  onCopy: () =>
                      _copyToClipboard(context, email, 'Email'),
                ),
              _InfoTile(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: '$area, $city',
              ),
              _InfoTile(
                icon: Icons.calendar_today_outlined,
                label: 'Member Since',
                value: memberDate,
              ),
              _InfoTile(
                icon: Icons.access_time_rounded,
                label: 'Last Active',
                value: lastActive,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── NIC SECTION ──────────────────────────────────────────────
  Widget _buildNicSection(
    BuildContext context,
    bool nicApproved,
    String? nicFrontUrl,
    String? nicBackUrl,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'NIC Verification'),
          const SizedBox(height: 12),

          // ── State 1: Approved ────────────────────────────────
          if (nicApproved)
            _StatusBanner(
              color: _T.green,
              icon: Icons.verified_rounded,
              title: 'NIC Approved',
              subtitle: 'Identity verified successfully.',
              action: _BannerAction(
                label: 'Revoke',
                color: _T.red,
                onTap: () => _toggleNicApproval(nicApproved),
              ),
            )

          // ── State 2: Images uploaded, pending review ─────────
          else if (nicFrontUrl != null && nicBackUrl != null) ...[
            _StatusBanner(
              color: _T.amber,
              icon: Icons.hourglass_top_rounded,
              title: 'NIC Under Review',
              subtitle: 'Tap images to inspect, then approve.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _NicThumb(
                  url: nicFrontUrl,
                  label: 'Front',
                  onTap: () => _openNicViewer(
                      context, nicFrontUrl, nicBackUrl),
                ),
                const SizedBox(width: 10),
                _NicThumb(
                  url: nicBackUrl,
                  label: 'Back',
                  onTap: () => _openNicViewer(
                      context, nicFrontUrl, nicBackUrl,
                      startIndex: 1),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Approve button
            _ActionButton(
              label: 'Approve NIC',
              icon: Icons.verified_user_rounded,
              color: _T.green,
              onTap: () => _toggleNicApproval(nicApproved),
            ),
          ]

          // ── State 3: Not uploaded ────────────────────────────
          else ...[
            _StatusBanner(
              color: _T.slate400,
              icon: Icons.image_not_supported_outlined,
              title: 'NIC Not Uploaded',
              subtitle: nicFrontUrl == null && nicBackUrl == null
                  ? 'Client hasn\'t uploaded any NIC images.'
                  : nicFrontUrl == null
                      ? 'Front side is missing.'
                      : 'Back side is missing.',
            ),
            if (nicFrontUrl != null || nicBackUrl != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _NicThumb(
                    url: nicFrontUrl,
                    label: 'Front',
                    onTap: () => _openNicViewer(
                        context, nicFrontUrl, nicBackUrl),
                  ),
                  const SizedBox(width: 10),
                  _NicThumb(
                    url: nicBackUrl,
                    label: 'Back',
                    onTap: () => _openNicViewer(
                        context, nicFrontUrl, nicBackUrl,
                        startIndex: 1),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── ACTIONS FOOTER ───────────────────────────────────────────
  Widget _buildActionsFooter(
    BuildContext context,
    String accountStatus,
    bool isSuspended,
    String displayId,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _T.slate100,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: const Border(top: BorderSide(color: _T.slate200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Copy UID
          _FooterAction(
            icon: Icons.fingerprint_rounded,
            label: 'Copy ID',
            onTap: () => _copyToClipboard(context, displayId, 'Display ID'),
          ),
          const SizedBox(width: 8),
          // View Projects (placeholder — wire to your nav)
          _FooterAction(
            icon: Icons.folder_open_rounded,
            label: 'Projects',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Client Projects')),
                    body: const Center(
                      child: Text('Projects page placeholder'),
                    ),
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          // Suspend / Unsuspend
          GestureDetector(
            onTap: () => _confirmSuspend(context, accountStatus),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSuspended
                    ? _T.green.withValues(alpha: 0.10)
                    : _T.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSuspended
                        ? _T.green.withValues(alpha: 0.25)
                        : _T.red.withValues(alpha: 0.20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSuspended
                        ? Icons.lock_open_rounded
                        : Icons.block_rounded,
                    size: 13,
                    color: isSuspended ? _T.green : _T.red,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isSuspended ? 'Unsuspend' : 'Suspend',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSuspended ? _T.green : _T.red),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSuspend(BuildContext context, String status) {
    final isSuspended = status == 'suspended';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _T.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isSuspended ? 'Unsuspend Account?' : 'Suspend Account?',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: _T.slate800),
        ),
        content: Text(
          isSuspended
              ? 'This client will regain access to the app.'
              : 'This client will lose access to the app immediately.',
          style: const TextStyle(fontSize: 13, color: _T.slate500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: _T.slate400)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleSuspend(status);
            },
            child: Text(
              isSuspended ? 'Unsuspend' : 'Suspend',
              style: TextStyle(
                  color: isSuspended ? _T.green : _T.red,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────
  Widget _divider() =>
      const Divider(height: 1, color: _T.slate200, indent: 0, endIndent: 0);

  Widget _vDivider() => Container(
      height: 32, width: 1, color: _T.slate200,
      margin: const EdgeInsets.symmetric(horizontal: 8));

  static String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return _formatDate(d);
  }

  static String _compactNum(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  // Full formatted amount e.g. 1,25,000 — readable for PKR
  static String _formatAmount(num n) {
    if (n == 0) return '0';
    if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)}Cr';
    if (n >= 100000)   return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000)     return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            color: _T.amber,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _T.slate500,
                letterSpacing: 0.5)),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value, label, sublabel;
  final IconData icon;
  final Color color;
  const _StatCell(
      {required this.value,
      required this.label,
      required this.sublabel,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5,
                  color: _T.slate700,
                  fontWeight: FontWeight.w600)),
          Text(sublabel,
              style: const TextStyle(
                  fontSize: 9.5,
                  color: _T.slate400,
                  fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      this.onCopy});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 32 - 32) / 2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: _T.slate400),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        color: _T.slate400,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _T.slate700)),
                    ),
                    if (onCopy != null)
                      GestureDetector(
                        onTap: onCopy,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.copy_rounded,
                              size: 12, color: _T.slate400),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title, subtitle;
  final _BannerAction? action;
  const _StatusBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: _T.r12,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _T.slate400,
                        height: 1.4)),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: action!.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: action!.color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: action!.color.withValues(alpha: 0.22)),
                ),
                child: Text(action!.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: action!.color)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerAction {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BannerAction(
      {required this.label, required this.color, required this.onTap});
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: _T.r12,
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FooterAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _T.slate200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _T.slate500),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _T.slate500)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Pill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPEND ROW — single line inside spending breakdown
// ─────────────────────────────────────────────────────────────────────────────

class _SpendRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sublabel;
  final num amount;
  final double ratio; // 0.0–1.0 for progress bar
  final bool hasData;

  const _SpendRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.sublabel,
    required this.amount,
    required this.ratio,
    required this.hasData,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Icon badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 10),
            // Label + sublabel
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _T.slate700)),
                  const SizedBox(height: 1),
                  Text(sublabel,
                      style: const TextStyle(
                          fontSize: 10,
                          color: _T.slate400,
                          height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Amount
            Text(
              'Rs ${_ClientCardState._formatAmount(amount)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar showing share of total
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: _T.slate200,
            valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${(ratio * 100).toStringAsFixed(0)}% of total spent',
          style: const TextStyle(fontSize: 9.5, color: _T.slate400),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NIC THUMBNAIL
// ─────────────────────────────────────────────────────────────────────────────

class _NicThumb extends StatelessWidget {
  final String? url;
  final String label;
  final VoidCallback onTap;
  const _NicThumb(
      {required this.url, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: url != null ? onTap : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _T.slate400,
                        fontWeight: FontWeight.w500)),
                if (url == null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.warning_amber_rounded,
                      size: 11, color: _T.amber),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Stack(
              children: [
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _T.slate100,
                    borderRadius: _T.r12,
                    border: Border.all(
                        color: url != null
                            ? _T.amberDark.withValues(alpha: 0.30)
                            : _T.slate200),
                    image: url != null
                        ? DecorationImage(
                            image: NetworkImage(url!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: url == null
                      ? const Center(
                          child: Icon(
                              Icons.image_not_supported_outlined,
                              color: _T.slate400,
                              size: 24))
                      : null,
                ),
                if (url != null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.zoom_in_rounded,
                          color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NIC VIEWER BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _NicViewerSheet extends StatefulWidget {
  final String? frontUrl;
  final String? backUrl;
  final int startIndex;
  const _NicViewerSheet(
      {this.frontUrl, this.backUrl, this.startIndex = 0});

  @override
  State<_NicViewerSheet> createState() => _NicViewerSheetState();
}

class _NicViewerSheetState extends State<_NicViewerSheet>
    with SingleTickerProviderStateMixin {
  late int _selected;
  late final TransformationController _transformCtrl;
  late final AnimationController _resetAnim;
  Animation<Matrix4>? _resetMatrix;

  @override
  void initState() {
    super.initState();
    _selected      = widget.startIndex;
    _transformCtrl = TransformationController();
    _resetAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_resetMatrix != null) {
          _transformCtrl.value = _resetMatrix!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _resetAnim.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (_selected == index) return;
    _transformCtrl.value = Matrix4.identity();
    setState(() => _selected = index);
  }

  void _resetZoom() {
    _resetMatrix = Matrix4Tween(
      begin: _transformCtrl.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _resetAnim, curve: Curves.easeOut));
    _resetAnim.forward(from: 0);
  }

  String? get _activeUrl =>
      _selected == 0 ? widget.frontUrl : widget.backUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF060D1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.credit_card_rounded,
                      color: Colors.white70, size: 16),
                ),
                const SizedBox(width: 10),
                const Text('NIC Document',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                if (_activeUrl != null)
                  GestureDetector(
                    onTap: _resetZoom,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.zoom_out_map_rounded,
                          color: Colors.white60, size: 16),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.5), size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _ViewerTab(
                    label: 'Front Side',
                    icon: Icons.flip_to_front_rounded,
                    selected: _selected == 0,
                    hasImage: widget.frontUrl != null,
                    onTap: () => _switchTab(0),
                  ),
                  const SizedBox(width: 3),
                  _ViewerTab(
                    label: 'Back Side',
                    icon: Icons.flip_to_back_rounded,
                    selected: _selected == 1,
                    hasImage: widget.backUrl != null,
                    onTap: () => _switchTab(1),
                  ),
                ],
              ),
            ),
          ),

          // Image
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _activeUrl != null
                    ? ClipRRect(
                        key: ValueKey(_selected),
                        borderRadius: BorderRadius.circular(16),
                        child: InteractiveViewer(
                          transformationController: _transformCtrl,
                          minScale: 0.8,
                          maxScale: 6.0,
                          clipBehavior: Clip.none,
                          child: Image.network(
                            _activeUrl!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              final pct = progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null;
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 40, height: 40,
                                      child: CircularProgressIndicator(
                                        value: pct,
                                        color: _T.amber,
                                        strokeWidth: 2.5,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    if (pct != null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                          '${(pct * 100).toInt()}%',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.4),
                                              fontSize: 12)),
                                    ],
                                  ],
                                ),
                              );
                            },
                            errorBuilder: (_, _, _) => Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_outlined,
                                      color: Colors.white.withValues(alpha: 0.2),
                                      size: 52),
                                  const SizedBox(height: 10),
                                  Text('Could not load image',
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.35),
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        key: ValueKey('empty_$_selected'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.image_not_supported_outlined,
                                  color: Colors.white.withValues(alpha: 0.2),
                                  size: 32),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _selected == 0
                                  ? 'Front image not uploaded'
                                  : 'Back image not uploaded',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // Hint
          Padding(
            padding: const EdgeInsets.only(bottom: 20, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pinch_outlined,
                    size: 13, color: Colors.white.withValues(alpha: 0.22)),
                const SizedBox(width: 5),
                Text('Pinch to zoom  ·  Tap tabs to switch',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.22),
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIEWER TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ViewerTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected, hasImage;
  final VoidCallback onTap;
  const _ViewerTab(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.hasImage,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? Colors.white : Colors.white38),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.white38)),
              if (!hasImage) ...[
                const SizedBox(width: 5),
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: _T.amber, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}