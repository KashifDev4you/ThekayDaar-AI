// =============================================================================
// lib/admin/Super_admin_dashboard/super_admin_requests_screen.dart
//
// PURPOSE:
//   The main landing screen after Super Admin logs in.
//   Shows ALL pending admin access requests from admin_passcodes/ collection
//   where status == 'pending' and isUsed == false.
//
// SUPER ADMIN ACTIONS per request:
//   • View the generated passcode (only Super Admin can see this)
//   • Copy passcode to clipboard (to share privately with the applicant)
//   • Approve  → updates status to 'approved' in Firestore
//   • Reject   → updates status to 'rejected' in Firestore
//
// NAVIGATION:
//   SuperAdminLoginScreen → SuperAdminRequestsScreen (this file)
//     └─ Bottom nav tab 2 → SuperAdminDashboardScreen (all users by category)
//
// FIRESTORE COLLECTION READ:
//   admin_passcodes/  — each doc has:
//     isUsed       : bool
//     status       : 'pending' | 'approved' | 'rejected'
//     requestedBy  : email string
//     city         : string
//     area         : string
//     passwordSeed : string
//     createdAt    : Timestamp
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import'package:ali_app/admin/Super_admin/Super_admin_dashboard/super_admin_issue_passcode_screen.dart';
// Import the full user management dashboard (all users by category)
import 'super_admin_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME  (matches the rest of the admin UI — navy + amber)
// ─────────────────────────────────────────────────────────────────────────────
const Color _navy   = Color(0xFF0E3B2E);
const Color _amber  = Color(0xFFC9A227);
const Color _white  = Color(0xFFFFFFFF);
const Color _label  = Color(0xFF1F2A26);
const Color _sub    = Color(0xFF5D6B64);
const Color _border = Color(0xFFE3E0D5);
const Color _fill   = Color(0xFFF7F5EF);
const Color _green  = Color(0xFF10B981);
const Color _red    = Color(0xFFDC2626);
const Color _orange = Color(0xFFA8861D);

// Helper: Firestore Timestamp → readable date string
String _fmt(dynamic ts) {
  if (ts == null) return '—';
  if (ts is Timestamp) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
  }
  return ts.toString();
}

// =============================================================================
// ENTRY POINT — SuperAdminRequestsScreen
//
// This is a full-screen scaffold with a bottom nav bar:
//   Tab 0: Pending Requests   ← default landing tab
//   Tab 1: All Users          ← SuperAdminDashboardScreen (full user mgmt)
// =============================================================================
class SuperAdminRequestsScreen extends StatefulWidget {
  const SuperAdminRequestsScreen({super.key});

  @override
  State<SuperAdminRequestsScreen> createState() =>
      _SuperAdminRequestsScreenState();
}

class _SuperAdminRequestsScreenState
    extends State<SuperAdminRequestsScreen> {
  int _currentTab = 0; // 0 = Requests, 1 = All Users

  // Tab bodies — built once, kept alive via IndexedStack
// To this:
final List<Widget> _tabs = const [
  _RequestsTab(),
  SuperAdminDashboardScreen(),
  SuperAdminIssuePasscodeScreen(),
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fill,
      // ── AppBar ──────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SUPER ADMIN',
              style: TextStyle(
                  color: _amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5),
            ),
            Text(
              _currentTab == 0
                  ? 'Access Requests'
                  : _currentTab == 1
                      ? 'User Management'
                      : 'Issue Passcode',
              style: const TextStyle(
                  color: _white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          // Sign out button
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: Color(0xFFA6B2AB), size: 20),
            tooltip: 'Sign Out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/', (r) => false);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Body — IndexedStack keeps both tabs alive ────────────
      body: IndexedStack(
        index: _currentTab,
        children: _tabs,
      ),

      // ── Bottom Navigation Bar ────────────────────────────────
      bottomNavigationBar:  ClipRRect(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30.0), topRight: Radius.circular(30.0), ),
        child: Container(
          decoration: const BoxDecoration(
            color: _white,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.pending_actions_rounded,
                    label: 'Requests',
                    isSelected: _currentTab == 0,
                    onTap: () => setState(() => _currentTab = 0),
                  ),
                  // In the bottom nav Row, add after the existing two _NavItems:
        _NavItem(
          icon: Icons.vpn_key_rounded,
          label: 'Passcodes',
          isSelected: _currentTab == 2,
          onTap: () => setState(() => _currentTab = 2),
        ),
                  _NavItem(
                    icon: Icons.people_alt_rounded,
                    label: 'All Users',
                    isSelected: _currentTab == 1,
                    onTap: () => setState(() => _currentTab = 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// REQUESTS TAB
// Streams admin_passcodes/ and splits into 3 sub-tabs:
//   Pending | Approved | Rejected
// =============================================================================
class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Sub-tab bar
          Container(
            color: _white,
            child: const TabBar(
              labelColor: _navy,
              unselectedLabelColor: _sub,
              indicatorColor: _amber,
              indicatorWeight: 2.5,
              labelStyle: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                Tab(text: 'Pending'),
                Tab(text: 'Approved'),
                Tab(text: 'Rejected'),
              ],
            ),
          ),
          // Tab content
          const Expanded(
            child: TabBarView(
              children: [
                _RequestListView(status: 'pending'),
                _RequestListView(status: 'approved'),
                _RequestListView(status: 'rejected'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REQUEST LIST VIEW
// Streams admin_passcodes filtered by status, renders request cards.
// =============================================================================
class _RequestListView extends StatelessWidget {
  final String status; // 'pending' | 'approved' | 'rejected'
  const _RequestListView({required this.status});

  Color get _statusColor => switch (status) {
        'approved' => _green,
        'rejected' => _red,
        _          => _orange,
      };

  @override
  Widget build(BuildContext context) {
    // Stream passcodes filtered by status, newest first
    final stream = FirebaseFirestore.instance
        .collection('admin_passcodes')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                color: _statusColor, strokeWidth: 2.5),
          );
        }

        // Error
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error.toString());
        }

        final docs = snapshot.data?.docs ?? [];

        // Empty
        if (docs.isEmpty) {
          return _EmptyState(
            icon: switch (status) {
              'approved' => Icons.check_circle_outline_rounded,
              'rejected' => Icons.cancel_outlined,
              _          => Icons.inbox_rounded,
            },
            label: 'No $status requests.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data   = docs[i].data();
            final docId  = docs[i].id; // this IS the passcode
            return _RequestCard(
              passcode: docId, // passcode = the document ID
              data    : data,
              status  : status,
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// REQUEST CARD
// Shows the applicant's info AND the passcode (visible to Super Admin only).
// Tap to open full detail sheet with approve/reject actions.
// =============================================================================
class _RequestCard extends StatelessWidget {
  final String passcode; // the actual generated passcode (doc ID)
  final Map<String, dynamic> data;
  final String status;

  const _RequestCard({
    required this.passcode,
    required this.data,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final email     = (data['requestedBy'] ?? '—').toString();
    final city      = (data['city'] ?? '—').toString();
    final area      = (data['area'] ?? '—').toString();
    final createdAt = _fmt(data['createdAt']);
    final isUsed    = data['isUsed'] as bool? ?? false;

    final Color statusColor = switch (status) {
      'approved' => _green,
      'rejected' => _red,
      _          => _orange,
    };

    final IconData statusIcon = switch (status) {
      'approved' => Icons.check_circle_rounded,
      'rejected' => Icons.cancel_rounded,
      _          => Icons.pending_rounded,
    };

    return GestureDetector(
      onTap: () => _RequestDetailSheet.show(
          context, passcode, data, status),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header row ────────────────────────────────────
              Row(
                children: [
                  // Avatar initial
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(statusIcon,
                        color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: const TextStyle(
                            color: _label,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$city · $area',
                          style: const TextStyle(
                              color: _sub, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 12),

              // ── PASSCODE — visible to Super Admin only ────────
              // This is the KEY information Super Admin needs to share
              // with the applicant. Never shown in the admin's own UI.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E3B2E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_rounded,
                        color: _amber, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACCESS PASSCODE',
                            style: TextStyle(
                              color: Color(0xFFA6B2AB),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          // ── THE PASSCODE IS DISPLAYED HERE ────
                          // Only Super Admin reaches this screen.
                          // Applicant's UI never shows this value.
                          Text(
                            passcode,
                            style: const TextStyle(
                              color: _amber,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Copy button
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: passcode));
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content: const Text(
                              'Passcode copied to clipboard',
                              style: TextStyle(
                                  color: _white, fontSize: 13),
                            ),
                            backgroundColor: _navy,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                            margin: const EdgeInsets.all(16),
                          ));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.copy_rounded,
                            color: _amber, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Footer: timestamp + used status ───────────────
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 12, color: _sub),
                  const SizedBox(width: 4),
                  Text(
                    createdAt,
                    style: const TextStyle(
                        color: _sub, fontSize: 11),
                  ),
                  const Spacer(),
                  if (isUsed)
                    const _SmallChip(
                        label: 'Used', color: Color(0xFF0E3B2E)),
                ],
              ),

              // ── Quick actions (pending only) ──────────────────
              if (status == 'pending') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        label: 'Approve',
                        icon: Icons.check_rounded,
                        color: _green,
                        onTap: () =>
                            _updateStatus(context, passcode, 'approved'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionButton(
                        label: 'Reject',
                        icon: Icons.close_rounded,
                        color: _red,
                        onTap: () =>
                            _updateStatus(context, passcode, 'rejected'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick approve / reject ─────────────────────────────────────
  Future<void> _updateStatus(
      BuildContext context, String passcode, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_passcodes')
          .doc(passcode)
          .update({
        'status'    : newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            'Request ${newStatus == 'approved' ? 'approved' : 'rejected'}.',
            style: const TextStyle(color: _white, fontSize: 13),
          ),
          backgroundColor:
              newStatus == 'approved' ? _green : _red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e',
            style: const TextStyle(color: _white)),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ));
    }
  }
}

// =============================================================================
// REQUEST DETAIL BOTTOM SHEET
// Full detail view with all fields + full approve/reject actions.
// =============================================================================
class _RequestDetailSheet extends StatefulWidget {
  final String passcode;
  final Map<String, dynamic> data;
  final String status;

  const _RequestDetailSheet({
    required this.passcode,
    required this.data,
    required this.status,
  });

  static void show(BuildContext context, String passcode,
      Map<String, dynamic> data, String status) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestDetailSheet(
          passcode: passcode, data: data, status: status),
    );
  }

  @override
  State<_RequestDetailSheet> createState() =>
      _RequestDetailSheetState();
}

class _RequestDetailSheetState extends State<_RequestDetailSheet> {
  bool _loading = false;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
  }

  // ── Update request status ──────────────────────────────────────
  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('admin_passcodes')
          .doc(widget.passcode)
          .update({
        'status'    : newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _currentStatus = newStatus);
      _snack(
        newStatus == 'approved'
            ? 'Request approved. Share the passcode with the applicant.'
            : 'Request rejected.',
        newStatus == 'approved' ? _green : _red,
      );
    } catch (e) {
      _snack('Error: $e', _red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:
            Text(msg, style: const TextStyle(color: _white, fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final email       = (widget.data['requestedBy'] ?? '—').toString();
    final city        = (widget.data['city'] ?? '—').toString();
    final area        = (widget.data['area'] ?? '—').toString();
    final seed        = (widget.data['passwordSeed'] ?? '—').toString();
    final createdAt   = _fmt(widget.data['createdAt']);
    final reviewedAt  = _fmt(widget.data['reviewedAt']);
    final isUsed      = widget.data['isUsed'] as bool? ?? false;
    final isPending   = _currentStatus == 'pending';
    final isApproved  = _currentStatus == 'approved';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pending_actions_rounded,
                        color: _amber, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Access Request',
                          style: TextStyle(
                              color: _label,
                              fontSize: 17,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(email,
                            style: const TextStyle(
                                color: _sub, fontSize: 12.5),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        _StatusBadge(status: _currentStatus),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: _border),

            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [

                  // ── Request Info ──────────────────────────────
                  _SectionHeader(
                      label: 'Request Details',
                      icon: Icons.info_outline_rounded,
                      color: _navy),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Email', value: email),
                  _InfoRow(label: 'City', value: city),
                  _InfoRow(label: 'Area', value: area),
                  _InfoRow(label: 'Submitted', value: createdAt),
                  if (reviewedAt != '—')
                    _InfoRow(label: 'Reviewed At', value: reviewedAt),
                  _InfoRow(
                    label: 'Passcode Used',
                    value: isUsed ? 'Yes — registration complete' : 'No — awaiting use',
                    valueColor: isUsed ? _green : _orange,
                  ),
                  const SizedBox(height: 20),

                  // ── Passcode Block ────────────────────────────
                  // SUPER ADMIN ONLY: This passcode must be shared
                  // privately with the applicant after approval.
                  _SectionHeader(
                      label: 'Access Passcode (Super Admin Only)',
                      icon: Icons.vpn_key_outlined,
                      color: _amber),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _navy,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GENERATED PASSCODE',
                          style: TextStyle(
                            color: Color(0xFFA6B2AB),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // ── PASSCODE SHOWN TO SUPER ADMIN ─────────
                        Text(
                          widget.passcode,
                          style: const TextStyle(
                            color: _amber,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Copy button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text: widget.passcode));
                              _snack(
                                  'Passcode copied to clipboard',
                                  _navy);
                            },
                            icon: const Icon(Icons.copy_rounded,
                                size: 16, color: _amber),
                            label: const Text(
                              'Copy Passcode',
                              style: TextStyle(
                                  color: _amber,
                                  fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: _amber.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Reminder to share privately
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color:
                                    _amber.withValues(alpha: 0.7),
                                size: 14),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Share this passcode privately with the applicant '
                                '(WhatsApp, call, or secure message). '
                                'Never send via public channels.',
                                style: TextStyle(
                                  color: Color(0xFFA6B2AB),
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Password Seed reference ───────────────────
                  _SectionHeader(
                      label: 'Password Seed Reference',
                      icon: Icons.lock_outline_rounded,
                      color: _sub),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _fill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: _sub, size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pre-filled password seed (for reference only):',
                                style: TextStyle(
                                    color: _sub,
                                    fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                seed,
                                style: const TextStyle(
                                  color: _label,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: seed));
                            _snack('Password seed copied', _navy);
                          },
                          child: const Icon(Icons.copy_rounded,
                              size: 14, color: _sub),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Actions ───────────────────────────────────
                  if (isPending) ...[
                    _SectionHeader(
                        label: 'Actions',
                        icon: Icons.admin_panel_settings_outlined,
                        color: _red),
                    const SizedBox(height: 12),

                    // Approve button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed:
                            _loading ? null : () => _updateStatus('approved'),
                        icon: _loading
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    color: _green, strokeWidth: 2))
                            : const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18),
                        label: const Text('Approve Request',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green.withValues(alpha: 0.1),
                          foregroundColor: _green,
                          elevation: 0,
                          side: BorderSide(
                              color: _green.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Reject button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed:
                            _loading ? null : () => _updateStatus('rejected'),
                        icon: const Icon(Icons.block_rounded,
                            size: 18),
                        label: const Text('Reject Request',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red.withValues(alpha: 0.1),
                          foregroundColor: _red,
                          elevation: 0,
                          side: BorderSide(
                              color: _red.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Already actioned — show status info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? _green.withValues(alpha: 0.08)
                            : _red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isApproved
                              ? _green.withValues(alpha: 0.25)
                              : _red.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isApproved
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color:
                                isApproved ? _green : _red,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isApproved
                                  ? 'This request has been approved. The passcode above can be shared with the applicant.'
                                  : 'This request has been rejected.',
                              style: TextStyle(
                                color: isApproved ? _green : _red,
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
// REUSABLE SMALL WIDGETS
// =============================================================================

// ── Bottom nav item ─────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? _amber : const Color(0xFFA6B2AB),
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? _navy
                      : const Color(0xFFA6B2AB),
                  fontSize: 11,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Status badge ────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color => switch (status) {
        'approved' => _green,
        'rejected' => _red,
        _          => _orange,
      };

  String get _label => switch (status) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        _          => 'Pending',
      };

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _color.withValues(alpha: 0.3)),
        ),
        child: Text(
          _label,
          style: TextStyle(
            color: _color,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      );
}

// ── Small chip ──────────────────────────────────────────────────
class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700),
        ),
      );
}

// ── Quick action button (approve/reject on card) ─────────────────
class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Section header in detail sheet ──────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHeader(
      {required this.label, required this.icon, required this.color});

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

// ── Info row in detail sheet ─────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(
                    color: _sub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? _label,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Empty state ──────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFA9B5AE), size: 52),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _sub, fontSize: 13.5, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

// ── Error state ──────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: _red, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Failed to load requests',
                style: TextStyle(
                    color: _label,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _sub, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      );
}