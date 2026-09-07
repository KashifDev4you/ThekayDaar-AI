// =============================================================================
// super_admin_dashboard_screen.dart — FINAL
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const Color _dNavy = Color(0xFF0E3B2E);
const Color _dAmber = Color(0xFFC9A227);
const Color _dWhite = Color(0xFFFFFFFF);
const Color _dLabel = Color(0xFF1F2A26);
const Color _dSub = Color(0xFF5D6B64);
const Color _dBorder = Color(0xFFE3E0D5);
const Color _dFill = Color(0xFFF7F5EF);
const Color _dGreen = Color(0xFF10B981);
const Color _dRed = Color(0xFFDC2626);
const Color _dBlue = Color(0xFF1A5C46);
const Color _dPurple = Color(0xFFC9A227);


const Map<String, Map<String, dynamic>> _designationMeta = {
  'super_admin': {'label': 'Super Admin', 'color': Color(0xFFDC2626)},
  'regional_manager': {'label': 'Regional Manager', 'color': Color(0xFF0E3B2E)},
  'area_handler': {'label': 'Area Handler', 'color': Color(0xFF1A5C46)},
  'support_desk': {'label': 'Support Desk', 'color': Color(0xFF0E3B2E)},
};

// ── Region definitions ───────────────────────────────────────────────────────
// Each region key maps to a human-readable label and the cities it covers.
const Map<String, Map<String, dynamic>> _regionMeta = {
  'karachi_region': {
    'label': 'Karachi Region',
    'cities': ['Karachi'],
  },
  'lahore_region': {
    'label': 'Lahore Region',
    'cities': ['Lahore', 'Faisalabad', 'Multan'],
  },
  'islamabad_region': {
    'label': 'Islamabad Region',
    'cities': ['Islamabad', 'Rawalpindi'],
  },
  'peshawar_region': {
    'label': 'Peshawar Region',
    'cities': ['Peshawar'],
  },
  'quetta_region': {
    'label': 'Quetta Region',
    'cities': ['Quetta'],
  },
};

// ── Support Desk departments ─────────────────────────────────────────────────
const List<String> _supportDepts = [
  'General Support',
  'Billing & Payments',
  'Dispute Resolution',
  'Contractor Onboarding',
  'Client Relations',
  'Technical Issues',
];

const List<String> _cityOptions = [
  'Karachi',
  'Lahore',
  'Islamabad',
  'Rawalpindi',
  'Peshawar',
  'Quetta',
  'Multan',
  'Faisalabad',
];

const Map<String, List<String>> _cityAreaOptions = {
  'Karachi': [
    'Clifton / DHA',
    'Gulshan-e-Iqbal',
    'Nazimabad / North Nazimabad',
    'Johar / Malir',
    'Saddar / Lyari',
    'FB Area / Liaquatabad',
    'Bahria Town / DHA City',
    'Korangi / Landhi',
    'Orangi Town / SITE',
    'Regional',
  ],
  'Lahore': [
    'Gulberg',
    'DHA Lahore',
    'Model Town',
    'Johar Town',
    'Bahria Town Lahore',
    'Cantt',
    'Iqbal Town',
    'Township',
    'Regional',
  ],
  'Islamabad': [
    'F-6 / F-7',
    'F-8 / F-10',
    'G-9 / G-10',
    'G-11 / G-12',
    'I-8 / I-9',
    'Bahria Town Islamabad',
    'Regional',
  ],
  'Rawalpindi': [
    'Saddar',
    'Chaklala',
    'Bahria Town Rawalpindi',
    'Satellite Town',
    'Gulraiz',
    'Westridge',
    'Regional',
  ],
  'Peshawar': [
    'University Town',
    'Hayatabad',
    'Saddar / Cantonment',
    'Gulbahar',
    'Tehkal',
    'Regional',
  ],
  'Quetta': [
    'Jinnah Town',
    'Satellite Town',
    'Brewery Road',
    'Pishin Stop',
    'Airport Road',
    'Regional',
  ],
  'Multan': [
    'Cantt',
    'Shah Rukn-e-Alam',
    'Gulgasht Colony',
    'Wapda Town',
    'New Multan',
    'Regional',
  ],
  'Faisalabad': [
    'Peoples Colony',
    'Gulberg Faisalabad',
    'D Ground',
    'Samanabad',
    'Canal Road',
    'Regional',
  ],
};

String _fmtTimestamp(dynamic ts) {
  if (ts == null) return '—';
  if (ts is Timestamp) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
  }
  return ts.toString();
}

String _toKey(String d) =>
    d.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

// =============================================================================
// ROOT
// =============================================================================
class SuperAdminDashboardScreen extends StatelessWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: _dNavy,
            child: const TabBar(
              labelColor: _dAmber,
              unselectedLabelColor: Color(0xFFA6B2AB),
              indicatorColor: _dAmber,
              indicatorWeight: 2.5,
              labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.manage_accounts_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Admins'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Requests'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [_AdminSubTabView(), _RequestsView()]),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ADMIN SUB-TAB VIEW
// =============================================================================
class _AdminSubTabView extends StatelessWidget {
  const _AdminSubTabView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _designationMeta.length,
      child: Column(
        children: [
          Container(
            color: _dNavy,
            child: TabBar(
              isScrollable: true,
              labelColor: _dAmber,
              unselectedLabelColor: const Color(0xFFA6B2AB),
              indicatorColor: _dAmber,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              tabs: _designationMeta.entries
                  .map(
                    (e) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: e.value['color'] as Color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(e.value['label'] as String),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: _designationMeta.keys
                  .map(
                    (key) => _UserListView(
                      collection: 'users',
                      whereField: 'designation',
                      whereValue: _designationMeta[key]!['label'] as String,
                      emptyLabel:
                          'No ${_designationMeta[key]!['label']} registered yet.',
                      accentColor: _designationMeta[key]!['color'] as Color,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REQUESTS VIEW
// =============================================================================
class _RequestsView extends StatefulWidget {
  const _RequestsView();
  @override
  State<_RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends State<_RequestsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _stream(String status) => FirebaseFirestore.instance
      .collection('admin_requests')
      .where('status', isEqualTo: status)
      .orderBy('createdAt', descending: true)
      .snapshots();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        color: const Color(0xFF1F2A26),
        child: TabBar(
          controller: _tabs,
          labelColor: _dAmber,
          unselectedLabelColor: const Color(0xFFA6B2AB),
          indicatorColor: _dAmber,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [
            _RequestList(stream: _stream('pending')),
            _RequestList(stream: _stream('approved')),
            _RequestList(stream: _stream('rejected')),
          ],
        ),
      ),
    ],
  );
}

class _RequestList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  const _RequestList({required this.stream});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: stream,
    builder: (_, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: _dAmber));
      }
      if (snap.hasError) return _DErrorState(error: snap.error.toString());
      final docs = snap.data?.docs ?? [];
      if (docs.isEmpty) {
        return const _DEmptyState(label: 'No requests in this category.');
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        itemBuilder: (_, i) {
          final data = docs[i].data() as Map<String, dynamic>;
          return _RequestCard(docId: docs[i].id, data: data);
        },
      );
    },
  );
}

// =============================================================================
// REQUEST CARD
// =============================================================================
class _RequestCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _RequestCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final name = (data['fullName'] ?? data['name'] ?? '—').toString();
    final email = data['email'] as String? ?? '—';
    final requestedCity = data['city'] as String? ?? '—';
    final assignedCity = data['assignedCity'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';
    final createdAt = _fmtTimestamp(data['createdAt']);

    final (statusColor, statusLabel) = switch (status) {
      'approved' => (_dGreen, 'Approved'),
      'rejected' => (_dRed, 'Rejected'),
      _ => (_dAmber, 'Pending'),
    };

    return GestureDetector(
      onTap: () => _RequestDetailSheet.show(context, docId, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _dWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _dBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _dPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: _dPurple,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: _dLabel,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(color: _dSub, fontSize: 11.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      children: [
                        _DChip(
                          label: 'Requested: $requestedCity',
                          color: _dBlue,
                        ),
                        if (assignedCity.isNotEmpty)
                          _DChip(
                            label: 'Assigned: $assignedCity',
                            color: _dGreen,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt,
                      style: const TextStyle(
                        color: Color(0xFFA6B2AB),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFA9B5AE),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// REQUEST DETAIL SHEET
// =============================================================================
class _RequestDetailSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _RequestDetailSheet({required this.docId, required this.data});

  static void show(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestDetailSheet(docId: docId, data: data),
    );
  }

  @override
  State<_RequestDetailSheet> createState() => _RequestDetailSheetState();
}

class _RequestDetailSheetState extends State<_RequestDetailSheet> {
  final _cityCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  bool _loading = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.data['status'] as String? ?? 'pending';
    _cityCtrl.text = widget.data['assignedCity'] as String? ?? '';
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(color: _dWhite, fontSize: 13),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  Future<void> _approve() async {
    final city = _cityCtrl.text.trim();
    if (city.isEmpty) {
      _snack('Please enter the city to assign first.', _dRed);
      return;
    }
    if (widget.docId.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final db = FirebaseFirestore.instance;
      final now = FieldValue.serverTimestamp();
      await db.collection('admin_requests').doc(widget.docId).update({
        'status': 'approved',
        'assignedCity': city,
        'remark': _remarkCtrl.text.trim(),
        'reviewedAt': now,
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      final email = widget.data['email'] as String? ?? '';
      final name = (widget.data['fullName'] ?? widget.data['name'] ?? '')
          .toString();
      final phone = widget.data['phone'] as String? ?? '';
      final uid = widget.data['uid'] as String? ?? widget.docId;
      if (uid.isNotEmpty) {
        await db.collection('users').doc(uid).set({
          'uid': uid,
          'fullName': name,
          'email': email,
          'phone': phone,
          'designation': 'Regional Manager',
          'role': 'RegionalAdmin',
          'city': city,
          'operationalCity': city,
          'accountStatus': 'active',
          'createdAt': now,
        }, SetOptions(merge: true));
        await db
            .collection('admins')
            .doc('regional_manager')
            .collection('members')
            .doc(uid)
            .set({
              'uid': uid,
              'fullName': name,
              'email': email,
              'phone': phone,
              'city': city,
              'operationalCity': city,
              'role': 'RegionalAdmin',
              'accountStatus': 'active',
              'createdAt': now,
            }, SetOptions(merge: true));
      }
      setState(() => _status = 'approved');
      if (mounted) {
        Navigator.pop(context);
        Future.delayed(const Duration(milliseconds: 300), () {
          _snack('✓ Request approved. City "$city" assigned.', _dGreen);
        });
      }
    } catch (e) {
      _snack('Error: $e', _dRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    if (widget.docId.trim().isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reject Request',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to reject this request?'),
            const SizedBox(height: 12),
            TextField(
              controller: _remarkCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Rejection reason (optional)',
                filled: true,
                fillColor: _dFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _dBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _dRed,
              foregroundColor: _dWhite,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('admin_requests')
          .doc(widget.docId)
          .update({
            'status': 'rejected',
            'remark': _remarkCtrl.text.trim(),
            'reviewedAt': FieldValue.serverTimestamp(),
            'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
          });
      setState(() => _status = 'rejected');
      if (mounted) {
        Navigator.pop(context);
        Future.delayed(
          const Duration(milliseconds: 300),
          () => _snack('Request rejected.', _dRed),
        );
      }
    } catch (e) {
      _snack('Error: $e', _dRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final name = (d['fullName'] ?? d['name'] ?? '—').toString();
    final email = d['email'] as String? ?? '—';
    final phone = d['phone'] as String? ?? '—';
    final requestedCity = d['city'] as String? ?? '—';
    final createdAt = _fmtTimestamp(d['createdAt']);
    final remark = d['remark'] as String? ?? '';
    final isPending = _status == 'pending';

    final (statusColor, statusLabel) = switch (_status) {
      'approved' => (_dGreen, 'Approved'),
      'rejected' => (_dRed, 'Rejected'),
      _ => (_dAmber, 'Pending'),
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _dWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _dBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _dPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: _dPurple,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: _dLabel,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(color: _dSub, fontSize: 12.5),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: _dBorder),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  _DSectionHeader(
                    label: 'Applicant Info',
                    icon: Icons.person_outline_rounded,
                    color: _dPurple,
                  ),
                  const SizedBox(height: 12),
                  _DInfoRow(label: 'Name', value: name),
                  _DInfoRow(label: 'Email', value: email),
                  _DInfoRow(label: 'Phone', value: phone),
                  _DInfoRow(label: 'Requested City', value: requestedCity),
                  _DInfoRow(label: 'Applied On', value: createdAt),
                  if (remark.isNotEmpty)
                    _DInfoRow(label: 'Remark', value: remark),
                  const SizedBox(height: 20),

                  if (isPending) ...[
                    _DSectionHeader(
                      label: 'Assign City',
                      icon: Icons.location_city_outlined,
                      color: _dBlue,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _dBlue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _dBlue.withValues(alpha: 0.20)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: _dBlue.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'The city you assign here becomes the regional admin\'s operational city.',
                              style: TextStyle(
                                color: _dSub,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Operational City',
                      style: TextStyle(
                        color: _dLabel,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _cityCtrl,
                      style: const TextStyle(color: _dLabel, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Karachi, Lahore, Peshawar',
                        hintStyle: const TextStyle(color: Color(0xFFA6B2AB)),
                        prefixIcon: const Icon(
                          Icons.location_city_outlined,
                          color: Color(0xFFA6B2AB),
                          size: 18,
                        ),
                        filled: true,
                        fillColor: _dFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _dBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _dBlue,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Remark (optional)',
                      style: TextStyle(
                        color: _dLabel,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _remarkCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: _dLabel, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Internal note about this approval…',
                        hintStyle: const TextStyle(color: Color(0xFFA6B2AB)),
                        filled: true,
                        fillColor: _dFill,
                        contentPadding: const EdgeInsets.all(12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _dBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _dAmber,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _DActionButton(
                      label: 'Approve & Assign City',
                      icon: Icons.check_circle_outline_rounded,
                      color: _dGreen,
                      loading: _loading,
                      onTap: _approve,
                    ),
                    const SizedBox(height: 10),
                    _DActionButton(
                      label: 'Reject Request',
                      icon: Icons.cancel_outlined,
                      color: _dRed,
                      loading: _loading,
                      onTap: _reject,
                    ),
                    const SizedBox(height: 32),
                  ] else ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha:0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _status == 'approved'
                                  ? Icons.verified_rounded
                                  : Icons.cancel_rounded,
                              color: statusColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _status == 'approved'
                                      ? 'Request Approved'
                                      : 'Request Rejected',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (_status == 'approved' &&
                                    (d['assignedCity'] as String? ?? '')
                                        .isNotEmpty)
                                  Text(
                                    'City: ${d['assignedCity']}',
                                    style: const TextStyle(
                                      color: _dSub,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (remark.isNotEmpty)
                                  Text(
                                    'Remark: $remark',
                                    style: const TextStyle(
                                      color: _dSub,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// USER LIST VIEW
// =============================================================================
class _UserListView extends StatefulWidget {
  final String collection;
  final String? whereField, whereValue;
  final String emptyLabel;
  final Color accentColor;
  const _UserListView({
    required this.collection,
    required this.emptyLabel,
    required this.accentColor,
    this.whereField,
    this.whereValue,
  });
  @override
  State<_UserListView> createState() => _UserListViewState();
}

class _UserListViewState extends State<_UserListView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> get _query {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      widget.collection,
    );
    if (widget.whereField != null && widget.whereValue != null) {
      q = q.where(widget.whereField!, isEqualTo: widget.whereValue);
    }
    return q;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: const TextStyle(color: _dLabel, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Search by name, email, city…',
              hintStyle: const TextStyle(
                color: Color(0xFFA6B2AB),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFFA6B2AB),
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: Color(0xFFA6B2AB),
                        size: 18,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _dWhite,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _dBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.accentColor, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: widget.accentColor,
                    strokeWidth: 2.5,
                  ),
                );
              }
              if (snapshot.hasError) {
                return _DErrorState(error: snapshot.error.toString());
              }
              var docs = snapshot.data?.docs ?? [];
              docs.sort((a, b) {
                final aTs = a.data()['registeredAt'] ?? a.data()['createdAt'];
                final bTs = b.data()['registeredAt'] ?? b.data()['createdAt'];
                if (aTs == null && bTs == null) return 0;
                if (aTs == null) return 1;
                if (bTs == null) return -1;
                return (bTs as Timestamp).compareTo(aTs as Timestamp);
              });
              if (docs.isEmpty) return _DEmptyState(label: widget.emptyLabel);
              final filtered = _searchQuery.isEmpty
                  ? docs
                  : docs.where((d) {
                      final data = d.data();
                      final name = (data['fullName'] ?? data['name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final email = (data['email'] ?? '')
                          .toString()
                          .toLowerCase();
                      final city =
                          (data['operationalCity'] ?? data['city'] ?? '')
                              .toString()
                              .toLowerCase();
                      final area = (data['assignedArea'] ?? data['area'] ?? '')
                          .toString()
                          .toLowerCase();
                      final region = (data['assignedRegion'] ?? '')
                          .toString()
                          .toLowerCase();
                      final dept = (data['department'] ?? '')
                          .toString()
                          .toLowerCase();
                      return name.contains(_searchQuery) ||
                          email.contains(_searchQuery) ||
                          city.contains(_searchQuery) ||
                          area.contains(_searchQuery) ||
                          region.contains(_searchQuery) ||
                          dept.contains(_searchQuery);
                    }).toList();
              if (filtered.isEmpty) {
                return _DEmptyState(label: 'No results for "$_searchQuery".');
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _UserCard(
                  data: filtered[i].data(),
                  accentColor: widget.accentColor,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// USER CARD
// =============================================================================
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accentColor;
  const _UserCard({required this.data, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final name = (data['fullName'] ?? data['name'] ?? 'Unknown').toString();
    final email = (data['email'] ?? '—').toString();
    final designation = (data['designation'] ?? data['role'] ?? '—').toString();
    final desKey = _toKey(designation);

    // Choose what to show as location/scope chip depending on role
    final String scopeLabel;
    final Color scopeColor;

    if (desKey == 'regional_manager') {
      final region = (data['assignedRegion'] ?? data['city'] ?? '—').toString();
      scopeLabel = region;
      scopeColor = const Color(0xFF0E3B2E);
    } else if (desKey == 'support_desk') {
      final dept = (data['department'] ?? 'General Support').toString();
      scopeLabel = dept;
      scopeColor = const Color(0xFF0E3B2E);
    } else {
      final city = (data['city'] ?? data['operationalCity'] ?? '—').toString();
      scopeLabel = city;
      scopeColor = const Color(0xFF1A5C46);
    }

    final area = (data['area'] ?? data['assignedArea'] ?? '—').toString();
    final status = (data['accountStatus'] ?? 'active').toString();
    final isActive = status == 'active';

    return GestureDetector(
      onTap: () => _UserDetailSheet.show(context, data, accentColor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _dWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _dBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha:0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: _dLabel,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _DStatusBadge(isActive: isActive),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(color: _dSub, fontSize: 11.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (designation != '—')
                          _DChip(label: designation, color: accentColor),
                        if (scopeLabel != '—')
                          _DChip(label: scopeLabel, color: scopeColor),
                        // Only show area chip for area_handler
                        if (desKey == 'area_handler' &&
                            area != '—' &&
                            area != scopeLabel)
                          _DChip(
                            label: area,
                            color: const Color(0xFFC9A227),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFA9B5AE),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// USER DETAIL SHEET
// =============================================================================
class _UserDetailSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accentColor;
  const _UserDetailSheet({required this.data, required this.accentColor});

  static void show(
    BuildContext context,
    Map<String, dynamic> data,
    Color accentColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(data: data, accentColor: accentColor),
    );
  }

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  bool _actionLoading = false;
  late String _currentStatus;
  final _notesCtrl = TextEditingController();

  // ── Area Handler fields ──────────────────────────────────────────────────
  String? _selectedCity;
  String? _selectedArea;

  // ── Regional Manager field ───────────────────────────────────────────────
  String? _selectedRegionKey;

  // ── Support Desk field ───────────────────────────────────────────────────
  String? _selectedDept;

  late final String _desKey;

  @override
  void initState() {
    super.initState();
    _currentStatus = (widget.data['accountStatus'] ?? 'active').toString();
    _notesCtrl.text = (widget.data['notes'] ?? '').toString();

    final designation =
        (widget.data['designation'] ?? widget.data['role'] ?? '').toString();
    _desKey = _toKey(designation);

    // Pre-fill based on role
    if (_desKey == 'regional_manager') {
      // Find the region key whose label matches the stored assignedRegion
      final stored =
          (widget.data['assignedRegion'] ?? widget.data['city'] ?? '').toString();
      _selectedRegionKey = _regionMeta.entries
          .firstWhere(
            (e) => e.value['label'] == stored || e.key == _toKey(stored),
            orElse: () => _regionMeta.entries.first,
          )
          .key;
      // Validate it actually exists
      if (!_regionMeta.containsKey(_selectedRegionKey)) {
        _selectedRegionKey = null;
      }
    } else if (_desKey == 'support_desk') {
      final stored = (widget.data['department'] ?? '').toString();
      _selectedDept = _supportDepts.contains(stored) ? stored : null;
    } else {
      // area_handler / super_admin
      final city =
          (widget.data['city'] ?? widget.data['operationalCity'] ?? '').toString();
      final area =
          (widget.data['area'] ?? widget.data['assignedArea'] ?? '').toString();
      _selectedCity = _cityOptions.contains(city) ? city : null;
      _selectedArea =
          (_cityAreaOptions[city] ?? []).contains(area) ? area : null;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(color: _dWhite, fontSize: 13),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  Future<void> _sendPasswordReset() async {
    final email = (widget.data['email'] ?? '').toString();
    if (email.isEmpty) return;
    setState(() => _actionLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _snack('Password reset email sent to $email', _dGreen);
    } on FirebaseAuthException catch (e) {
      _snack('Failed: ${e.message}', _dRed);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _toggleStatus() async {
    final uid = (widget.data['uid'] ?? '').toString();
    if (uid.isEmpty) return;
    final newStatus = _currentStatus == 'active' ? 'suspended' : 'active';
    setState(() => _actionLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(
        db.collection('users').doc(uid),
        {'accountStatus': newStatus},
        SetOptions(merge: true),
      );
      batch.set(
        db.collection('admin_roster').doc(uid),
        {'accountStatus': newStatus},
        SetOptions(merge: true),
      );
      if (_designationMeta.containsKey(_desKey)) {
        batch.set(
          db.collection('admins').doc(_desKey).collection('members').doc(uid),
          {'accountStatus': newStatus},
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      setState(() => _currentStatus = newStatus);
      _snack(
        newStatus == 'active' ? 'Account activated.' : 'Account suspended.',
        newStatus == 'active' ? _dGreen : _dRed,
      );
    } catch (e) {
      _snack('Error: $e', _dRed);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Save jurisdiction — branches by role ──────────────────────────────────
  Future<void> _saveJurisdiction() async {
    final uid = (widget.data['uid'] ?? '').toString();
    if (uid.isEmpty) return;

    Map<String, dynamic> payload;
    String successMsg;

    if (_desKey == 'regional_manager') {
      // ── Regional Manager: assign a region (covers all its cities) ──────
      if (_selectedRegionKey == null) {
        _snack('Please select a region first.', _dRed);
        return;
      }
      final regionLabel =
          _regionMeta[_selectedRegionKey]!['label'] as String;
      final regionCities =
          (_regionMeta[_selectedRegionKey]!['cities'] as List).cast<String>();
      payload = {
        'assignedRegion': regionLabel,
        'operationalCities': regionCities,
        // Keep 'city' pointing to the primary/first city for backward compat
        'city': regionCities.first,
        'operationalCity': regionCities.first,
      };
      successMsg = '✓ $regionLabel assigned';
    } else if (_desKey == 'support_desk') {
      // ── Support Desk: national scope, just a department tag ────────────
      if (_selectedDept == null) {
        _snack('Please select a department first.', _dRed);
        return;
      }
      payload = {
        'department': _selectedDept,
        'scope': 'national',
        // Clear any city restriction a previous assignment may have set
        'city': FieldValue.delete(),
        'operationalCity': FieldValue.delete(),
        'assignedArea': FieldValue.delete(),
      };
      successMsg = '✓ Department "$_selectedDept" assigned (National)';
    } else {
      // ── Area Handler / others: city + area ─────────────────────────────
      if (_selectedCity == null) {
        _snack('Please select a city first.', _dRed);
        return;
      }
      payload = {
        'city': _selectedCity,
        'area': _selectedArea ?? '',
        'operationalCity': _selectedCity,
        'assignedArea': _selectedArea ?? '',
      };
      successMsg =
          '✓ $_selectedCity${_selectedArea != null ? ' · $_selectedArea' : ''} assigned';
    }

    setState(() => _actionLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(
        db.collection('users').doc(uid),
        payload,
        SetOptions(merge: true),
      );
      batch.set(
        db.collection('admin_roster').doc(uid),
        payload,
        SetOptions(merge: true),
      );
      if (_designationMeta.containsKey(_desKey)) {
        batch.set(
          db.collection('admins').doc(_desKey).collection('members').doc(uid),
          payload,
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
        Future.delayed(
          const Duration(milliseconds: 300),
          () => _snack(successMsg, _dGreen),
        );
      }
    } catch (e) {
      _snack('Error: $e', _dRed);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _saveNotes() async {
    final uid = (widget.data['uid'] ?? '').toString();
    if (uid.isEmpty) return;
    setState(() => _actionLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'notes': _notesCtrl.text.trim(),
      });
      _snack('Notes saved.', _dGreen);
    } catch (e) {
      _snack('Error: $e', _dRed);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Jurisdiction UI — branched by role ────────────────────────────────────
  Widget _buildJurisdictionSection() {
    if (_desKey == 'regional_manager') {
      return _buildRegionalManagerJurisdiction();
    } else if (_desKey == 'support_desk') {
      return _buildSupportDeskJurisdiction();
    } else {
      return _buildAreaHandlerJurisdiction();
    }
  }

  // Regional Manager: single region dropdown, shows covered cities
  Widget _buildRegionalManagerJurisdiction() {
    final coveredCities = _selectedRegionKey != null
        ? (_regionMeta[_selectedRegionKey]!['cities'] as List).cast<String>()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DSectionHeader(
          label: 'Assign Region',
          icon: Icons.public_rounded,
          color: _dPurple,
        ),
        const SizedBox(height: 10),
        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _dPurple.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _dPurple.withValues(alpha: 0.20)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: _dPurple.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'A Regional Manager oversees all cities and area handlers within their assigned region. No area restriction applies.',
                  style: TextStyle(color: _dSub, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Region *',
          style: TextStyle(
            color: _dLabel,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedRegionKey,
          onChanged: (v) => setState(() => _selectedRegionKey = v),
          style: const TextStyle(color: _dLabel, fontSize: 14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFFA6B2AB),
          ),
          decoration: InputDecoration(
            hintText: 'Select region',
            hintStyle: const TextStyle(color: Color(0xFFA6B2AB)),
            prefixIcon: const Icon(
              Icons.public_rounded,
              color: Color(0xFFA6B2AB),
              size: 18,
            ),
            filled: true,
            fillColor: _dFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _dBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _dPurple, width: 1.5),
            ),
          ),
          items: _regionMeta.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value['label'] as String),
                ),
              )
              .toList(),
        ),
        // Covered cities preview
        if (coveredCities.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _dGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _dGreen.withValues(alpha: 0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: _dGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Covers ${coveredCities.length} ${coveredCities.length == 1 ? 'city' : 'cities'}',
                      style: const TextStyle(
                        color: _dGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: coveredCities
                      .map(
                        (c) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _dGreen.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _dGreen.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            c,
                            style: const TextStyle(
                              color: _dGreen,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _DActionButton(
          label: 'Save Region',
          icon: Icons.save_rounded,
          color: _dPurple,
          loading: _actionLoading,
          onTap: _saveJurisdiction,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Support Desk: national badge + department picker only
  Widget _buildSupportDeskJurisdiction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DSectionHeader(
          label: 'Assign Department',
          icon: Icons.support_agent_rounded,
          color: _dGreen,
        ),
        const SizedBox(height: 10),
        // National scope badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _dBlue.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _dBlue.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _dBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.language_rounded, size: 16, color: _dBlue),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'National Scope',
                      style: TextStyle(
                        color: _dBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Support Desk can access the full platform with no city or area restrictions.',
                      style: TextStyle(color: _dSub, fontSize: 11.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Department *',
          style: TextStyle(
            color: _dLabel,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedDept,
          onChanged: (v) => setState(() => _selectedDept = v),
          style: const TextStyle(color: _dLabel, fontSize: 14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFFA6B2AB),
          ),
          decoration: InputDecoration(
            hintText: 'Select department',
            hintStyle: const TextStyle(color: Color(0xFFA6B2AB)),
            prefixIcon: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFFA6B2AB),
              size: 18,
            ),
            filled: true,
            fillColor: _dFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _dBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _dGreen, width: 1.5),
            ),
          ),
          items: _supportDepts
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
        ),
        const SizedBox(height: 14),
        _DActionButton(
          label: 'Save Department',
          icon: Icons.save_rounded,
          color: _dGreen,
          loading: _actionLoading,
          onTap: _saveJurisdiction,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Area Handler / others: city + area dropdowns
  Widget _buildAreaHandlerJurisdiction() {
    final d = widget.data;
    final city = (d['city'] ?? d['operationalCity'] ?? '—').toString();
    final area = (d['area'] ?? d['assignedArea'] ?? '—').toString();
    final currentAreas =
        _cityAreaOptions[_selectedCity] ?? ['Regional', 'Support'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DSectionHeader(
          label: 'Assign Jurisdiction',
          icon: Icons.location_city_outlined,
          color: _dBlue,
        ),
        const SizedBox(height: 8),
        if (city != '—')
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _dGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _dGreen.withValues(alpha: 0.20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: _dGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current: $city${area != '—' ? ' · $area' : ''}',
                    style: const TextStyle(
                      color: _dGreen,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Text(
          'City *',
          style: TextStyle(
            color: _dLabel,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedCity,
          onChanged: (v) => setState(() {
            _selectedCity = v;
            _selectedArea = null;
          }),
          style: const TextStyle(color: _dLabel, fontSize: 14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFFA6B2AB),
          ),
          decoration: InputDecoration(
            hintText: 'Select city',
            hintStyle: const TextStyle(color: Color(0xFFA6B2AB)),
            prefixIcon: const Icon(
              Icons.location_city_outlined,
              color: Color(0xFFA6B2AB),
              size: 18,
            ),
            filled: true,
            fillColor: _dFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _dBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _dBlue, width: 1.5),
            ),
          ),
          items: _cityOptions
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
        ),
        const SizedBox(height: 12),
        const Text(
          'Area / Region',
          style: TextStyle(
            color: _dLabel,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedArea,
          onChanged: _selectedCity == null
              ? null
              : (v) => setState(() => _selectedArea = v),
          style: const TextStyle(color: _dLabel, fontSize: 14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFFA6B2AB),
          ),
          decoration: InputDecoration(
            hintText:
                _selectedCity == null ? 'Select city first' : 'Select area',
            hintStyle: const TextStyle(color: Color(0xFFA6B2AB)),
            prefixIcon: const Icon(
              Icons.map_outlined,
              color: Color(0xFFA6B2AB),
              size: 18,
            ),
            filled: true,
            fillColor:
                _selectedCity == null ? const Color(0xFFF7F5EF) : _dFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _dBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _dBlue, width: 1.5),
            ),
          ),
          items: currentAreas
              .map((a) => DropdownMenuItem(value: a, child: Text(a)))
              .toList(),
        ),
        const SizedBox(height: 14),
        _DActionButton(
          label: 'Save Jurisdiction',
          icon: Icons.save_rounded,
          color: _dBlue,
          loading: _actionLoading,
          onTap: _saveJurisdiction,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final name = (d['fullName'] ?? d['name'] ?? 'Unknown').toString();
    final email = (d['email'] ?? '—').toString();
    final phone = (d['phone'] ?? '—').toString();
    final nic = (d['nic'] ?? '—').toString();
    final designation = (d['designation'] ?? d['role'] ?? '—').toString();
    final passwordSeed = (d['passwordSeed'] ?? '—').toString();
    final passcodeUsed = (d['passcodeUsed'] ?? '—').toString();
    final registeredAt = _fmtTimestamp(d['registeredAt'] ?? d['createdAt']);
    final uid = (d['uid'] ?? '—').toString();
    final isActive = _currentStatus == 'active';

    // Scope display value for profile row
    final String scopeValue;
    if (_desKey == 'regional_manager') {
      scopeValue = _selectedRegionKey != null
          ? _regionMeta[_selectedRegionKey]!['label'] as String
          : (d['assignedRegion'] ?? d['city'] ?? '—').toString();
    } else if (_desKey == 'support_desk') {
      scopeValue =
          '${_selectedDept ?? (d['department'] ?? 'General Support')} · National';
    } else {
      final city = (d['city'] ?? d['operationalCity'] ?? '—').toString();
      final area = (d['area'] ?? d['assignedArea'] ?? '—').toString();
      scopeValue =
          city + (area != '—' && area.isNotEmpty ? ' · $area' : '');
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _dWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _dBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha:0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: widget.accentColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: _dLabel,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(color: _dSub, fontSize: 12.5),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            _DChip(
                              label: designation,
                              color: widget.accentColor,
                            ),
                            const SizedBox(width: 6),
                            _DStatusBadge(isActive: isActive),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: _dBorder),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Profile ────────────────────────────────────────────
                  _DSectionHeader(
                    label: 'Profile',
                    icon: Icons.person_outline_rounded,
                    color: widget.accentColor,
                  ),
                  const SizedBox(height: 12),
                  _DInfoRow(label: 'Name', value: name),
                  _DInfoRow(label: 'Email', value: email),
                  _DInfoRow(
                    label: 'Phone',
                    value: phone.length == 11
                        ? '${phone.substring(0, 4)}-${phone.substring(4)}'
                        : phone,
                  ),
                  _DInfoRow(
                    label: 'CNIC',
                    value: nic.length == 13
                        ? '${nic.substring(0, 5)}-${nic.substring(5, 12)}-${nic[12]}'
                        : nic,
                  ),
                  _DInfoRow(label: 'Designation', value: designation),
                  _DInfoRow(label: 'Scope / Jurisdiction', value: scopeValue),
                  _DInfoRow(label: 'Registered', value: registeredAt),
                  _DInfoRow(
                    label: 'UID',
                    value: uid,
                    monospace: true,
                    copyable: true,
                  ),
                  const SizedBox(height: 20),

                  if (passwordSeed != '—') ...[
                    _DSectionHeader(
                      label: 'Credentials Reference',
                      icon: Icons.vpn_key_outlined,
                      color: _dAmber,
                    ),
                    const SizedBox(height: 10),
                    _DInfoRow(
                      label: 'Password Seed',
                      value: passwordSeed,
                      monospace: true,
                      copyable: true,
                    ),
                    _DInfoRow(
                      label: 'Passcode Used',
                      value: passcodeUsed,
                      monospace: true,
                      copyable: true,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Jurisdiction (role-specific) ───────────────────────
                  _buildJurisdictionSection(),

                  // ── Actions ───────────────────────────────────────────
                  _DSectionHeader(
                    label: 'Actions',
                    icon: Icons.admin_panel_settings_outlined,
                    color: _dRed,
                  ),
                  const SizedBox(height: 12),
                  _DActionButton(
                    label: 'Send Password Reset Email',
                    icon: Icons.lock_reset_rounded,
                    color: _dBlue,
                    loading: _actionLoading,
                    onTap: _sendPasswordReset,
                  ),
                  const SizedBox(height: 10),
                  _DActionButton(
                    label: isActive ? 'Suspend Account' : 'Activate Account',
                    icon: isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_outline_rounded,
                    color: isActive ? _dRed : _dGreen,
                    loading: _actionLoading,
                    onTap: _toggleStatus,
                  ),
                  const SizedBox(height: 20),

                  // ── Notes ─────────────────────────────────────────────
                  _DSectionHeader(
                    label: 'Notes',
                    icon: Icons.sticky_note_2_outlined,
                    color: _dPurple,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: _dLabel, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Add internal notes…',
                      hintStyle: const TextStyle(
                        color: Color(0xFFA6B2AB),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: _dFill,
                      contentPadding: const EdgeInsets.all(14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _dBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _dPurple,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DActionButton(
                    label: 'Save Notes',
                    icon: Icons.save_outlined,
                    color: _dPurple,
                    loading: _actionLoading,
                    onTap: _saveNotes,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _DStatusBadge extends StatelessWidget {
  final bool isActive;
  const _DStatusBadge({required this.isActive});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: isActive ? _dGreen.withValues(alpha:0.1) : _dRed.withValues(alpha:0.1),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(
        color: isActive ? _dGreen.withValues(alpha:0.3) : _dRed.withValues(alpha:0.3),
      ),
    ),
    child: Text(
      isActive ? 'Active' : 'Suspended',
      style: TextStyle(
        color: isActive ? _dGreen : _dRed,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DChip extends StatelessWidget {
  final String label;
  final Color color;
  const _DChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha:0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _DSectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _DSectionHeader({
    required this.label,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    ],
  );
}

class _DInfoRow extends StatelessWidget {
  final String label, value;
  final bool monospace, copyable;
  const _DInfoRow({
    required this.label,
    required this.value,
    this.monospace = false,
    this.copyable = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: _dSub,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: _dLabel,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFamily: monospace ? 'monospace' : null,
            ),
          ),
        ),
        if (copyable)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$label copied',
                    style: const TextStyle(color: _dWhite, fontSize: 12),
                  ),
                  backgroundColor: _dNavy,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(
                Icons.copy_rounded,
                size: 14,
                color: Color(0xFFA6B2AB),
              ),
            ),
          ),
      ],
    ),
  );
}

class _DActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _DActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: ElevatedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: color, strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha:0.1),
        foregroundColor: color,
        elevation: 0,
        side: BorderSide(color: color.withValues(alpha:0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

class _DEmptyState extends StatelessWidget {
  final String label;
  const _DEmptyState({required this.label});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_rounded, color: Color(0xFFA9B5AE), size: 52),
          const SizedBox(height: 14),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _dSub, fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    ),
  );
}

class _DErrorState extends StatelessWidget {
  final String error;
  const _DErrorState({required this.error});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: _dRed, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Failed to load data',
            style: TextStyle(
              color: _dLabel,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _dSub, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    ),
  );
}