// =============================================================================
// area_handler_dashboard.dart  (FIXED)
//
// Key fixes:
//   1. _city now reads 'city' (not 'operationalCity') — matches Firestore doc.
//   2. _area now reads 'area' (not 'assignedArea') — matches Firestore doc.
//   3. _name now reads 'fullName' — matches Firestore doc.
//   4. Stats Row: Contractors stat queries 'users' collection with 'city' field.
//   5. Stats Row: client-side area filter uses 'area' field.
//   6. Suspension watcher checks 'users' collection (not 'areaHandlers').
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ali_app/admin/Area_Handler/area_handler_clients.dart';
import 'package:ali_app/admin/Area_Handler/area_handler_contractors.dart';
import 'package:ali_app/admin/Area_Handler/area_handler_disputes.dart';
import 'package:ali_app/admin/Area_Handler/area_handler_payments.dart';
import 'package:ali_app/admin/Area_Handler/area_handler_reports.dart';
import 'package:ali_app/admin/Area_Handler/area_handler_proj_screen.dart';
import 'package:ali_app/admin/Area_Handler/area_handler_account_screen.dart';

class AreaHandlerDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AreaHandlerDashboard({super.key, required this.userData});

  @override
  State<AreaHandlerDashboard> createState() => _AreaHandlerDashboardState();
}

class _AreaHandlerDashboardState extends State<AreaHandlerDashboard> {
  static const Color _navy  = Color(0xFF0E3B2E);
  static const Color _amber = Color(0xFFC9A227);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _bg    = Color(0xFFF7F5EF);

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // FIX 1: Read 'city' not 'operationalCity'
  // FIX 2: Read 'area' not 'assignedArea'
  // FIX 3: Read 'fullName' not 'name'
  late final String _city = widget.userData['city']     as String? ?? '';
  late final String _area = widget.userData['area']     as String? ?? '';
  late final String _name = widget.userData['fullName'] as String? ?? 'Area Handler';

  bool _suspendedDialogShown = false;

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF5D6B64))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: _white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      }
    }
  }

  Future<void> _showSuspendedDialog() async {
    if (_suspendedDialogShown || !mounted) return;
    _suspendedDialogShown = true;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
        contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
        actionsPadding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.block_rounded,
                color: Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Account Suspended',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: const Text(
          'Your account has been suspended by the Super Admin.\n\n'
          'You have been signed out. Please contact support if you '
          'believe this is a mistake.',
          style: TextStyle(
              fontSize: 13.5, color: Color(0xFF5D6B64), height: 1.55),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
            child: const Text('OK, Sign Out'),
          ),
        ],
      ),
    );
    if (mounted) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/admin_login', (r) => false);
      }
    }
  }

  void _go(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final features = [
      _FeatureDef(
        color: const Color(0xFF0E3B2E),
        icon: Icons.engineering_rounded,
        title: 'Contractors',
        lines: ['Verify NIC + skills', 'Approve / suspend'],
        // FIX: passes correct _city and _area now
        onTap: () => _go(AreaHandlerContractorsScreen(city: _city, area: _area)),
      ),
      _FeatureDef(
        color: const Color(0xFF1A5C46),
        icon: Icons.people_rounded,
        title: 'Clients',
        lines: ['Review complaints', 'Refund decisions'],
        onTap: () => _go(AreaHandlerClientsScreen(city: _city, area: _area)),
      ),
      _FeatureDef(
        color: const Color(0xFFA8861D),
        icon: Icons.work_rounded,
        title: 'Projects',
        lines: ['Monitor active bids', 'Flag suspicious gigs'],
        onTap: () => _go(ProjectsScreen(city: _city, area: _area)),
      ),
      _FeatureDef(
        color: const Color(0xFF10B981),
        icon: Icons.payments_rounded,
        title: 'Payments',
        lines: ['Review transactions', 'Approve plan upgrades'],
        onTap: () => _go(AdminPaymentsScreen(city: _city, area: _area)),
      ),
      _FeatureDef(
        color: const Color(0xFFDC2626),
        icon: Icons.gavel_rounded,
        title: 'Disputes',
        lines: ['Mediate contractor', 'vs client conflicts'],
        onTap: () => _go(AreaHandlerDisputesScreen(city: _city, area: _area)),
      ),
      _FeatureDef(
        color: const Color(0xFF0E3B2E),
        icon: Icons.bar_chart_rounded,
        title: 'Reports',
        lines: ['Weekly area stats', 'Escalate to Super Admin'],
        onTap: () => _go(AreaHandlerReportsScreen(city: _city, area: _area)),
      ),
    ];

    return Scaffold(
      backgroundColor: _bg,
      // FIX 4: Watch suspension in 'users' collection, not 'areaHandlers'
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasData && snap.data!.exists) {
            final data = snap.data!.data() as Map<String, dynamic>;
            final status = data['accountStatus'] as String? ?? 'active';
            if (status == 'suspended') {
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _showSuspendedDialog());
            }
          }

          return Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(
              backgroundColor: _navy,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Area Handler',
                      style: TextStyle(
                          color: _white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  Text(
                    _city.isEmpty && _area.isEmpty
                        ? 'No location assigned'
                        : '$_city • $_area',
                    style: TextStyle(
                        color: _white.withValues(alpha: 0.55),
                        fontSize: 11.5),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.account_circle_rounded,
                      color: _white, size: 24),
                  tooltip: 'My Account',
                  onPressed: () =>
                      _go(AccountScreen(userData: widget.userData)),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded,
                      color: _white, size: 20),
                  tooltip: 'Sign Out',
                  onPressed: _signOut,
                ),
              ],
            ),
            body: RefreshIndicator(
              color: _amber,
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _GreetingBanner(name: _name, city: _city, area: _area),
                  const SizedBox(height: 20),
                  _StatsRow(city: _city, area: _area),
                  const SizedBox(height: 24),
                  const Text('Manage Your Area',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2A26))),
                  const SizedBox(height: 4),
                  const Text(
                    'Cannot access other areas · Reports to Super Admin',
                    style:
                        TextStyle(fontSize: 11.5, color: Color(0xFFA6B2AB)),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                    children: features
                        .map((f) => _FeatureCard(def: f))
                        .toList(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Greeting Banner
// ─────────────────────────────────────────────────────────────
class _GreetingBanner extends StatelessWidget {
  final String name, city, area;
  const _GreetingBanner(
      {required this.name, required this.city, required this.area});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E3B2E), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.location_on_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $name',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  area.isEmpty ? 'No area assigned' : '$area · $city',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Area Handler',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stats Row
// ─────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────
// Stats Row  — FIXED
// ─────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final String city, area;
  const _StatsRow({required this.city, required this.area});

  @override
  Widget build(BuildContext context) {
    if (city.isEmpty || area.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF6E3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6D694)),
        ),
        child: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFA8861D), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'City or area not assigned. Stats cannot load.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFFA8861D)),
            ),
          ),
        ]),
      );
    }

    return Row(
      children: [
        // ── CONTRACTORS ──────────────────────────────────────
        // Queries 'contractors' collection directly (same as
        // AreaHandlerContractorsScreen does) — filtered by city + area
        Expanded(
          child: _StatCard(
            label: 'Contractors',
            icon: Icons.engineering_rounded,
            color: const Color(0xFF1A5C46),
            stream: FirebaseFirestore.instance
                .collection('contractors')         // ← correct collection
                .where('city', isEqualTo: city)
                .where('area', isEqualTo: area)
                .snapshots(),
          ),
        ),
        const SizedBox(width: 10),

        // ── CLIENTS ──────────────────────────────────────────
        // Queries 'clients' collection directly (same as
        // AreaHandlerClientsScreen does) — filtered by city + area
        Expanded(
          child: _StatCard(
            label: 'Clients',
            icon: Icons.people_outline_rounded,
            color: const Color(0xFFC9A227),
            stream: FirebaseFirestore.instance
                .collection('clients')             // ← correct collection
                .where('city', isEqualTo: city)
                .where('area', isEqualTo: area)
                .snapshots(),
          ),
        ),
        const SizedBox(width: 10),

        // ── PENDING PAYMENTS ─────────────────────────────────
        Expanded(
          child: _StatCard(
            label: 'Pending',
            icon: Icons.pending_actions_rounded,
            color: Colors.redAccent,
            stream: FirebaseFirestore.instance
                .collection('payment_requests')
                .where('city', isEqualTo: city)    // ← add city filter too
                .where('area', isEqualTo: area)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot> stream;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E0D5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (_, s) {
            if (s.hasError) {
              return Text('!',
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800));
            }
            if (!s.hasData) {
              return SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              );
            }
            return Text(
              '${s.data!.docs.length}',
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800),
            );
          },
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF5D6B64), fontSize: 11)),
      ]),
    );
  }
}// ─────────────────────────────────────────────────────────────
// Feature card model + widget
// ─────────────────────────────────────────────────────────────
class _FeatureDef {
  final Color color;
  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onTap;
  const _FeatureDef({
    required this.color,
    required this.icon,
    required this.title,
    required this.lines,
    required this.onTap,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureDef def;
  const _FeatureCard({required this.def});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: def.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: def.color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(def.icon, color: Colors.white, size: 28),
            const Spacer(),
            Text(def.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            ...def.lines.map((l) => Text(l,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11.5))),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.6), size: 16),
            ),
          ],
        ),
      ),
    );
  }
}