import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ali_app/utils/app_theme.dart';

// =============================================================================
// SUPPORT DESK DASHBOARD
// Tabs: Tickets | Complaints | Refunds
// Support desk can view, reply, resolve tickets
// CANNOT suspend users or edit financials
// =============================================================================
class SupportDeskDashboard extends StatefulWidget {
  const SupportDeskDashboard({super.key});

  @override
  State<SupportDeskDashboard> createState() => _SupportDeskDashboardState();
}

class _SupportDeskDashboardState extends State<SupportDeskDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _agentName = '';
  String _city      = '';
  bool   _loading   = true;

  static const _navy   = Color(0xFF0E3B2E);
  static const _amber  = Color(0xFFC9A227);
  static const _white  = Color(0xFFFFFFFF);
  static const _bg     = Color(0xFFF7F5EF);

  static const _red    = Color(0xFFDC2626);
  static const _blue   = AppTheme.emeraldMid;
  static const _orange = AppTheme.goldDark;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      if (doc.exists) {
        final d = doc.data()!;
        setState(() {
          _agentName = (d['fullName']         as String? ?? '').trim();
          _city      = (d['operationalCity']  as String? ?? '').trim();
          _loading   = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // ── Stats streams — no orderBy to avoid index errors ──────────────
  Stream<QuerySnapshot> get _openTickets =>
      FirebaseFirestore.instance
          .collection('support_tickets')
          .where('status', isEqualTo: 'open')
          .snapshots();

  Stream<QuerySnapshot> get _openComplaints =>
      FirebaseFirestore.instance
          .collection('complaints')
          .where('status', isEqualTo: 'open')
          .snapshots();

  Stream<QuerySnapshot> get _pendingRefunds =>
      FirebaseFirestore.instance
          .collection('payment_requests')
          .where('refundRequested', isEqualTo: true)
          .where('refundStatus', isEqualTo: 'pending')
          .snapshots();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: _bg,
          body: Center(child: CircularProgressIndicator(color: _amber)));
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(children: [
        _buildStatsRow(),
        Container(
          color: _white,
          child: TabBar(
            controller: _tabs,
            labelColor: AppTheme.emerald,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.gold,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Tickets'),
              Tab(text: 'Complaints'),
              Tab(text: 'Refunds'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _TicketsTab(agentUid: _uid),
              _ComplaintsTab(agentUid: _uid),
              _RefundsTab(),
            ],
          ),
        ),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _navy,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SUPPORT DESK',
            style: TextStyle(color: _amber, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        Text(_agentName.isNotEmpty ? _agentName : 'Dashboard',
            style: const TextStyle(
                color: _white, fontSize: 17, fontWeight: FontWeight.w700)),
      ]),
      actions: [
        if (_city.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: _amber.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _amber.withValues(alpha:0.4))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_city_rounded, size: 13, color: _amber),
              const SizedBox(width: 5),
              Text(_city, style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _amber)),
            ]),
          ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFA6B2AB), size: 20),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
          },
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: [
        _StatCard(stream: _openTickets,    label: 'Open Tickets',    icon: Icons.confirmation_number_outlined, color: _blue),
        const SizedBox(width: 10),
        _StatCard(stream: _openComplaints, label: 'Complaints',      icon: Icons.report_outlined,              color: _orange),
        const SizedBox(width: 10),
        _StatCard(stream: _pendingRefunds, label: 'Refund Requests', icon: Icons.money_off_rounded,            color: _red),
      ]),
    );
  }
}

// =============================================================================
// STAT CARD
// =============================================================================
class _StatCard extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({required this.stream, required this.label,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (_, snap) {
          final count = snap.data?.docs.length ?? 0;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: color.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha:0.25))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text('$count', style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(
                  fontSize: 10, color: Color(0xFFA6B2AB), fontWeight: FontWeight.w600)),
            ]),
          );
        },
      ),
    );
  }
}

// =============================================================================
// TICKETS TAB
// =============================================================================
class _TicketsTab extends StatefulWidget {
  final String agentUid;
  const _TicketsTab({required this.agentUid});

  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab>
    with SingleTickerProviderStateMixin {
  late TabController _sub;

  static const _amber = Color(0xFFC9A227);
  static const _sub2  = Color(0xFF5D6B64);
  static const _navy  = Color(0xFF0E3B2E);

  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _sub.dispose(); super.dispose(); }

  Stream<QuerySnapshot> _stream(String status) =>
      FirebaseFirestore.instance
          .collection('support_tickets')
          .where('status', isEqualTo: status)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: const Color(0xFFF7F5EF),
        child: TabBar(
          controller: _sub,
          labelColor: _navy,
          unselectedLabelColor: _sub2,
          indicatorColor: _amber,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'Open'), Tab(text: 'In Progress'), Tab(text: 'Resolved')],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _sub,
          children: [
            _TicketList(stream: _stream('open'),        agentUid: widget.agentUid),
            _TicketList(stream: _stream('in_progress'), agentUid: widget.agentUid),
            _TicketList(stream: _stream('resolved'),    agentUid: widget.agentUid),
          ],
        ),
      ),
    ]);
  }
}

// ── Ticket List ──────────────────────────────────────────────────
class _TicketList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String agentUid;

  static const _amber = Color(0xFFC9A227);
  static const _sub   = Color(0xFF5D6B64);

  const _TicketList({required this.stream, required this.agentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _amber));
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}',
              style: const TextStyle(color: Colors.red)));
        }

        var docs = snap.data?.docs ?? [];
        docs.sort((a, b) {
          final aT = (a.data() as Map<String,dynamic>)['createdAt'];
          final bT = (b.data() as Map<String,dynamic>)['createdAt'];
          if (aT == null && bT == null) return 0;
          if (aT == null) return 1; if (bT == null) return -1;
          return (bT as Timestamp).compareTo(aT as Timestamp);
        });

        if (docs.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.confirmation_number_outlined, size: 52, color: Color(0xFFA9B5AE)),
            const SizedBox(height: 14),
            const Text('No tickets here.', style: TextStyle(fontSize: 13.5, color: _sub)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final d   = doc.data() as Map<String,dynamic>;
            return _TicketCard(docId: doc.id, data: d, agentUid: agentUid);
          },
        );
      },
    );
  }
}

// ── Ticket Card ──────────────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  final String docId, agentUid;
  final Map<String,dynamic> data;

  static const _white  = Color(0xFFFFFFFF);
  static const _label  = Color(0xFF1F2A26);
  static const _sub    = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _green  = Color(0xFF10B981);
  static const _amber  = Color(0xFFC9A227);
  static const _blue   = AppTheme.emeraldMid;

  const _TicketCard({required this.docId, required this.data, required this.agentUid});

  Color _statusColor(String s) => s == 'open' ? _amber
      : s == 'in_progress' ? _blue
      : s == 'resolved' ? _green : _sub;

  String _statusLabel(String s) => s == 'open' ? 'Open'
      : s == 'in_progress' ? 'In Progress'
      : s == 'resolved' ? 'Resolved' : s;

  Future<void> _updateStatus(BuildContext ctx, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(docId)
        .update({
      'status'     : newStatus,
      'assignedTo' : agentUid,
      'updatedAt'  : FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final title      = data['title']      as String? ?? 'Support Ticket';
    final desc       = data['description'] as String? ?? '';
    final userName   = data['userName']   as String? ?? '—';
    final userRole   = data['userRole']   as String? ?? '';
    final status     = data['status']     as String? ?? 'open';
    final category   = data['category']   as String? ?? '';
    final statusCol  = _statusColor(status);
    final statusLbl  = _statusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: status == 'open' ? _amber.withValues(alpha:0.3) : _border,
            width: status == 'open' ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _label))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: statusCol.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusCol.withValues(alpha:0.3))),
                child: Text(statusLbl, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: statusCol)),
              ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFFA6B2AB)),
              const SizedBox(width: 5),
              Text('$userName${userRole.isNotEmpty ? '  ·  $userRole' : ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFA6B2AB))),
              if (category.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: _blue.withValues(alpha:0.08),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(category, style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600, color: _blue)),
                ),
              ],
            ]),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: _sub, height: 1.4)),
            ],
          ]),
        ),

        // Actions
        if (status != 'resolved') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: const Color(0xFFF7F5EF),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13))),
            child: Row(children: [
              if (status == 'open')
                Expanded(child: _ActionBtn(
                  label: 'Take Ownership',
                  icon: Icons.assignment_ind_outlined,
                  color: _blue,
                  onTap: () => _updateStatus(context, 'in_progress'),
                ))
              else
                Expanded(child: _ActionBtn(
                  label: 'Mark Resolved',
                  icon: Icons.check_circle_outline_rounded,
                  color: _green,
                  onTap: () => _updateStatus(context, 'resolved'),
                )),
              const SizedBox(width: 10),
              Expanded(child: _ActionBtn(
                label: 'Add Reply',
                icon: Icons.reply_rounded,
                color: _amber,
                onTap: () => _ReplySheet.show(context, docId),
              )),
            ]),
          ),
        ],
      ]),
    );
  }
}

// =============================================================================
// COMPLAINTS TAB
// =============================================================================
class _ComplaintsTab extends StatefulWidget {
  final String agentUid;
  const _ComplaintsTab({required this.agentUid});

  @override
  State<_ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<_ComplaintsTab>
    with SingleTickerProviderStateMixin {
  late TabController _sub;

  @override
  void initState() { super.initState(); _sub = TabController(length: 2, vsync: this); }

  @override
  void dispose() { _sub.dispose(); super.dispose(); }

  Stream<QuerySnapshot> _stream(String status) =>
      FirebaseFirestore.instance
          .collection('complaints')
          .where('status', isEqualTo: status)
          .snapshots();

  static const _amber = Color(0xFFC9A227);
  static const _sub2  = Color(0xFF5D6B64);
  static const _navy  = Color(0xFF0E3B2E);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: const Color(0xFFF7F5EF),
        child: TabBar(
          controller: _sub,
          labelColor: _navy,
          unselectedLabelColor: _sub2,
          indicatorColor: _amber,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'Open'), Tab(text: 'Resolved')],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _sub, children: [
          _ComplaintList(stream: _stream('open'),     agentUid: widget.agentUid),
          _ComplaintList(stream: _stream('resolved'), agentUid: widget.agentUid),
        ]),
      ),
    ]);
  }
}

class _ComplaintList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String agentUid;

  static const _amber  = Color(0xFFC9A227);
  static const _sub    = Color(0xFF5D6B64);
  static const _white  = Color(0xFFFFFFFF);
  static const _label  = Color(0xFF1F2A26);
  static const _border = Color(0xFFE3E0D5);
  static const _green  = Color(0xFF10B981);
  static const _orange = AppTheme.goldDark;

  const _ComplaintList({required this.stream, required this.agentUid});

  Future<void> _resolve(String docId) async {
    await FirebaseFirestore.instance
        .collection('complaints')
        .doc(docId)
        .update({
      'status'     : 'resolved',
      'resolvedBy' : agentUid,
      'resolvedAt' : FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _amber));
        }
        var docs = snap.data?.docs ?? [];
        docs.sort((a, b) {
          final aT = (a.data() as Map<String,dynamic>)['createdAt'];
          final bT = (b.data() as Map<String,dynamic>)['createdAt'];
          if (aT == null && bT == null) return 0;
          if (aT == null) return 1; if (bT == null) return -1;
          return (bT as Timestamp).compareTo(aT as Timestamp);
        });
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.report_outlined, size: 52, color: Color(0xFFA9B5AE)),
          const SizedBox(height: 14),
          const Text('No complaints here.', style: TextStyle(fontSize: 13.5, color: _sub)),
        ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final d   = doc.data() as Map<String,dynamic>;
            final title    = d['title']       as String? ?? 'Complaint';
            final desc     = d['description'] as String? ?? '';
            final reporter = d['reporterName'] as String? ?? '—';
            final against  = d['againstName']  as String? ?? '—';
            final status   = d['status']       as String? ?? 'open';
            final isOpen   = status == 'open';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _white, borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isOpen ? _orange.withValues(alpha:0.3) : _border,
                    width: isOpen ? 1.5 : 1),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: isOpen ? _orange.withValues(alpha:0.1) : _green.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(isOpen ? Icons.report_rounded : Icons.check_circle_rounded,
                          color: isOpen ? _orange : _green, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: _label)),
                    const SizedBox(height: 2),
                    Text('By: $reporter  →  Against: $against',
                        style: const TextStyle(fontSize: 11.5, color: _sub)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: isOpen ? _orange.withValues(alpha:0.1) : _green.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(isOpen ? 'Open' : 'Resolved',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: isOpen ? _orange : _green)),
                  ),
                ]),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: _sub, height: 1.4)),
                ],
                if (isOpen) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _ActionBtn(
                      label: 'Mark Resolved', icon: Icons.check_circle_outline_rounded,
                      color: _green, onTap: () => _resolve(doc.id),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _ActionBtn(
                      label: 'Add Reply', icon: Icons.reply_rounded,
                      color: _amber, onTap: () => _ReplySheet.show(context, doc.id, collection: 'complaints'),
                    )),
                  ]),
                ],
              ]),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// REFUNDS TAB
// Support desk can VIEW refund requests only — CANNOT approve/reject financials
// =============================================================================
class _RefundsTab extends StatelessWidget {
  static const _amber  = Color(0xFFC9A227);
  static const _sub    = Color(0xFF5D6B64);
  static const _white  = Color(0xFFFFFFFF);
  static const _label  = Color(0xFF1F2A26);
  static const _border = Color(0xFFE3E0D5);
  static const _red    = Color(0xFFDC2626);
  static const _green  = Color(0xFF10B981);
  static const _fill   = AppTheme.bg;

  const _RefundsTab();

  Stream<QuerySnapshot> get _stream =>
      FirebaseFirestore.instance
          .collection('payment_requests')
          .where('refundRequested', isEqualTo: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Read-only notice
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: _red.withValues(alpha:0.06),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: _red, size: 15),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Read-only view. Refund approvals are handled by Super Admin.',
            style: TextStyle(fontSize: 12, color: _red, fontWeight: FontWeight.w600))),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _stream,
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _amber));
            }
            var docs = snap.data?.docs ?? [];
            docs.sort((a, b) {
              final aT = (a.data() as Map<String,dynamic>)['createdAt'];
              final bT = (b.data() as Map<String,dynamic>)['createdAt'];
              if (aT == null && bT == null) return 0;
              if (aT == null) return 1; if (bT == null) return -1;
              return (bT as Timestamp).compareTo(aT as Timestamp);
            });

            if (docs.isEmpty) {
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.money_off_rounded, size: 52, color: Color(0xFFA9B5AE)),
              const SizedBox(height: 14),
              const Text('No refund requests.', style: TextStyle(fontSize: 13.5, color: _sub)),
            ]));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d      = docs[i].data() as Map<String,dynamic>;
                final status = d['refundStatus'] as String? ?? 'pending';
                final isPending  = status == 'pending';
                final statusColor = isPending ? _amber : status == 'approved' ? _green : _red;
                final statusLabel = isPending ? 'Pending' : status == 'approved' ? 'Approved' : 'Rejected';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.02),
                          blurRadius: 8, offset: const Offset(0, 2))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(d['projectTitle'] as String? ?? 'Refund Request',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _label))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: statusColor.withValues(alpha:0.1), borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withValues(alpha:0.3))),
                        child: Text(statusLabel, style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _infoRow('Client', d['clientName'] as String? ?? '—'),
                    _infoRow('Thekaydaar', d['thekaydaarName'] as String? ?? '—'),
                    _infoRow('Amount', 'Rs ${d['amount'] ?? '—'}'),
                    if ((d['refundReason'] as String? ?? '').isNotEmpty)
                      _infoRow('Reason', d['refundReason'] as String),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: _fill, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Awaiting Super Admin approval',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: _sub, fontWeight: FontWeight.w500)),
                    ),
                  ]),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: _sub))),
      Expanded(child: Text(value, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: _label))),
    ]),
  );
}

// =============================================================================
// SHARED ACTION BUTTON
// =============================================================================
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.label, required this.icon,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 38,
      decoration: BoxDecoration(
          color: color.withValues(alpha:0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha:0.25))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

// =============================================================================
// REPLY BOTTOM SHEET
// =============================================================================
class _ReplySheet extends StatefulWidget {
  final String docId;
  final String collection;

  const _ReplySheet({required this.docId, this.collection = 'support_tickets'});

  static void show(BuildContext context, String docId,
      {String collection = 'support_tickets'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReplySheet(docId: docId, collection: collection),
    );
  }

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _ctrl    = TextEditingController();
  bool _loading  = false;

  static const _amber = Color(0xFFC9A227);
  static const _navy  = Color(0xFF0E3B2E);
  static const _white = Color(0xFFFFFFFF);
  static const _label = Color(0xFF1F2A26);
  static const _border = Color(0xFFE3E0D5);
  static const _fill  = Color(0xFFF7F5EF);
  static const _red   = Color(0xFFDC2626);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final uid     = FirebaseAuth.instance.currentUser?.uid ?? '';
      final replyData = {
        'agentUid'  : uid,
        'message'   : _ctrl.text.trim(),
        'repliedAt' : FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection(widget.collection)
          .doc(widget.docId)
          .update({
        'replies'  : FieldValue.arrayUnion([replyData]),
        'status'   : 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: _red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Add Reply', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: _label)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            style: const TextStyle(color: _label, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Type your reply to the user...',
              hintStyle: const TextStyle(color: Color(0xFFA6B2AB), fontSize: 13),
              filled: true, fillColor: _fill,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _amber, width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _amber, foregroundColor: _navy, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: _navy, strokeWidth: 2))
                  : const Text('Send Reply',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}