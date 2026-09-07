// =============================================================================
// client_profile_screen.dart
//
// CHANGES:
//   1. Payment/subscription section REMOVED — plans only activate via admin
//   2. Plan banner shows current plan status (read-only)
//   3. Avatar fixed — reads profilePic from clients/{uid}, falls back to initials
//   4. _activatePlan() removed from client side entirely
//   5. No payment sheet, no plan selection tiles
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:ali_app/Payment&Requests/billing_screen.dart';
import 'package:ali_app/profile_sub_pages/project/my_project_screen.dart';

import 'package:ali_app/profile_sub_pages/notifications/notifications_screen.dart';
import 'package:ali_app/profile_sub_pages/help_support_screen.dart';
// ─────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────
const _navy    = Color(0xFF0E3B2E);
const _amber   = Color(0xFFC9A227);
const _amberD  = Color(0xFFA8861D);
const _amberL  = Color(0xFFFBF6E3);
const _green   = Color(0xFF10B981);
const _greenL  = Color(0xFFD1FAE5);
const _blue    = Color(0xFF1A5C46);
const _blueL   = Color(0xFFE7F2ED);
const _border  = Color(0xFFE3E0D5);
const _surface = Color(0xFFF7F5EF);
const _white   = Color(0xFFFFFFFF);
const _textPri = Color(0xFF0E3B2E);
const _textSec = Color(0xFF5D6B64);

// ─────────────────────────────────────────────────────────────
// PLAN CONFIG  (display-only — no purchasing from client side)
// ─────────────────────────────────────────────────────────────
class _CPlan {
  final String key, label, price;
  final bool isPremium, verifiedBadge;
  final Color bg, fg;
  final List<String> perks;
  const _CPlan({
    required this.key,
    required this.label,
    required this.price,
    required this.isPremium,
    required this.verifiedBadge,
    required this.bg,
    required this.fg,
    required this.perks,
  });
}

const _cPlans = [
  _CPlan(
    key: 'Free',
    label: 'Free',
    price: 'Rs 0/month',
    isPremium: false,
    verifiedBadge: false,
    bg: Color(0xFFF7F5EF),
    fg: Color(0xFF5D6B64),
    perks: ['1 project post/month', 'View up to 5 bids', 'Basic listing'],
  ),
  _CPlan(
    key: 'Standard',
    label: 'Standard',
    price: 'Rs 499/month',
    isPremium: true,
    verifiedBadge: false,
    bg: Color(0xFFFBF6E3),
    fg: Color(0xFFA8861D),
    perks: [
      '5 project posts/month',
      'All bids visible',
      'Priority in search',
      'Email support',
    ],
  ),
  _CPlan(
    key: 'Premium',
    label: 'Premium',
    price: 'Rs 1499/month',
    isPremium: true,
    verifiedBadge: true,
    bg: Color(0xFFE7F2ED),
    fg: Color(0xFF1A5C46),
    perks: [
      'Unlimited project posts',
      'All bids visible',
      'Verified client badge',
      'Featured in search',
      'Priority support',
    ],
  ),
];

_CPlan _getCPlan(String key) =>
    _cPlans.firstWhere((p) => p.key == key, orElse: () => _cPlans.first);

bool _cPlanExpired(dynamic ts) {
  if (ts == null) return false;
  if (ts is Timestamp) {
    return DateTime.now().difference(ts.toDate()).inDays >= 30;
  }
  return false;
}

// =============================================================================
// SCREEN
// =============================================================================
class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});
  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final String? uid = FirebaseAuth.instance.currentUser?.uid;
  bool _uploading = false;

  static const _cloudName    = 'doblp5gf6';
  static const _uploadPreset = 'Thekaydaar';

  // ── Cloudinary upload ─────────────────────────────────────
  Future<String?> _uploadToCloudinary(XFile f) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final bytes = await f.readAsBytes();
    final req = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: f.name));
    try {
      final res = await req.send();
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(await res.stream.toBytes()));
        return data['secure_url'] as String?;
      }
    } catch (e) {
      debugPrint('Cloudinary: $e');
    }
    return null;
  }

  // ── Firestore helpers — clients/{uid} ─────────────────────
  Future<void> _set(String field, dynamic value) async {
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('clients')
        .doc(uid)
        .set({field: value}, SetOptions(merge: true));
  }

  // ── Profile completion progress ───────────────────────────
  double _progress(Map<String, dynamic> d) {
    const fields = [
      'fullName', 'nicNumber', 'city', 'area', // from signup (read-only)
      'phone',                                  // manual
      'nic_front_url', 'nic_back_url',          // manual uploads
      'profilePic',                             // manual
    ];
    if (d.isEmpty) return 0;
    return fields
            .where((f) => (d[f]?.toString().trim().isNotEmpty) == true)
            .length /
        fields.length;
  }

  List<String> _missingChips(Map<String, dynamic> d) {
    final map = {
      'fullName':     'Full Name',
      'nicNumber':    'NIC',
      'city':         'City',
      'area':         'Area',
      'phone':        'Phone',
      'nic_front_url':'NIC Front',
      'nic_back_url': 'NIC Back',
      'profilePic':   'Profile Pic',
    };
    return map.entries
        .where((e) => (d[e.key]?.toString().trim().isNotEmpty) != true)
        .map((e) => e.value)
        .toList();
  }

  // ── Avatar initials helper ────────────────────────────────
  String _initials(String fullName) {
    final auth = FirebaseAuth.instance.currentUser;
    final namesToTry = [fullName, auth?.displayName ?? '', auth?.email ?? ''];
    for (final name in namesToTry) {
      final cleaned = name.trim();
      if (cleaned.isEmpty) continue;
      if (cleaned.contains('@')) return cleaned[0].toUpperCase();
      final parts  = cleaned.split(RegExp(r'\s+'));
      final result = parts
          .where((w) => w.isNotEmpty)
          .take(2)
          .map((w) => w[0].toUpperCase())
          .join();
      if (result.isNotEmpty) return result;
    }
    return 'U';
  }

  // ── Image handling ────────────────────────────────────────
  Future<void> _handleImage(String target, ImageSource src) async {
    final picked = await ImagePicker().pickImage(source: src, imageQuality: 50);
    if (picked == null) return;
    setState(() => _uploading = true);
    final url = await _uploadToCloudinary(picked);
    if (url != null) {
      await _set(target == 'profile' ? 'profilePic' : 'nic_${target}_url', url);
      if (mounted) _snack('Uploaded!', success: true);
    }
    if (mounted) setState(() => _uploading = false);
  }

  // ── Logout ────────────────────────────────────────────────
  Future<void> _logout() async {
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textPri)),
        content: const Text(
          'You will be taken back to the role selection screen.',
          style: TextStyle(fontSize: 13, color: _textSec, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: _white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Login required')));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Exit App?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            content: const Text('You will remain logged in.',
                style: TextStyle(fontSize: 13, color: _textSec)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Stay', style: TextStyle(color: _amberD)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: _navy,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Exit', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
        if (exit == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(uid!)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: _amber)),
            );
          }
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('Error: ${snap.error}')));
          }

          final data         = snap.data?.data() as Map<String, dynamic>? ?? {};
          final prog         = _progress(data);
         
          final missing      = _missingChips(data);
          final planKey      = data['planName']        as String? ?? 'Free';
          final isPremium    = data['isPremium']        as bool?   ?? false;
          final isPending    = data['paymentPending']   as bool?   ?? false;
          final pendingPlan  = data['pendingPlan']      as String? ?? '';
          final projLeft     = data['projectsRemaining'] as int?   ?? 1;
          final nicVerified  = data['nicVerified']      as bool?   ?? false;
          final verifiedBadge= data['verifiedBadge']    as bool?   ?? false;
          final planExpired  = _cPlanExpired(data['planActivatedAt']);

          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: _surface,
            drawer: _buildDrawer(data),
            body: CustomScrollView(
              slivers: [
                _buildAppBar(data, verifiedBadge, planKey, isPremium),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Current plan status banner ──────────────────────
                      _planStatusBanner(
                          planKey, projLeft, isPremium, isPending,
                          pendingPlan, planExpired, verifiedBadge),
                      // ── Profile completion ──────────────────────────────
                      _progressCard(prog, missing),
                      const SizedBox(height: 24),
                      // ── Personal info ───────────────────────────────────
                      _sectionLabel('PERSONAL INFO'),
                      const SizedBox(height: 8),
                      _personalCard(data),
                      const SizedBox(height: 24),
                      // ── NIC verification ────────────────────────────────
                      _sectionLabel('NIC VERIFICATION'),
                      const SizedBox(height: 8),
                      _nicSection(data, nicVerified),
                      const SizedBox(height: 24),
                      // ── Plan info (read-only) ───────────────────────────
                      _sectionLabel('SUBSCRIPTION'),
                      const SizedBox(height: 8),
                      _planInfoCard(planKey, isPremium, isPending,
                          pendingPlan, projLeft, planExpired),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // DRAWER
  // ==========================================================================
  Widget _buildDrawer(Map<String, dynamic> data) {
    final name      = data['fullName']  as String? ?? '';
    final city      = data['city']      as String? ?? '';
    final area      = data['area']      as String? ?? '';
    final pic       = data['profilePic'] as String?;
    final planKey   = data['planName']  as String? ?? 'Free';
    final displayId = data['displayId'] as String? ?? '';
    final plan      = _getCPlan(planKey);
    final initials  = _initials(name);
    final subtitle  = city.isNotEmpty
        ? '$city${area.isNotEmpty ? ' · $area' : ''}'
        : '';

    return Drawer(
      backgroundColor: _white,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              color: _navy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar — shows profilePic or initials
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _blue, width: 2.5),
                    ),
                    child: ClipOval(
                      child: pic != null && pic.isNotEmpty
                          ? Image.network(pic, fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _initialsCircle(
                                  initials, 64, 22))
                          : _initialsCircle(initials, 64, 22),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name.isNotEmpty ? name : 'Client',
                    style: const TextStyle(
                        color: _white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: Color(0xFFA6B2AB), fontSize: 12)),
                  ],
                  if (displayId.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(displayId,
                        style: const TextStyle(
                            color: Color(0xFF5D6B64), fontSize: 11, letterSpacing: 0.4)),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: plan.bg, borderRadius: BorderRadius.circular(6)),
                    child: Text('${plan.label} Plan',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: plan.fg)),
                  ),
                ],
              ),
            ),
            // ── Menu items ──────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(Icons.person_outline_rounded, 'My Profile',
                      () => Navigator.pop(context)),
                  _drawerItem(
                    Icons.workspace_premium_rounded,
                    'Plans & Billing',
                    () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const BillingScreen(role: 'client')));
                    },
                  ),
     _drawerItem(Icons.folder_open_rounded, 'My Projects', () {
  Navigator.pop(context); // close drawer first
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const MyProjectsScreen()),
  );
}),
_drawerItem(Icons.receipt_long_outlined, 'Payment History', () {
  Navigator.pop(context);
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const BillingScreen(role: 'client')),
  );
}),
_drawerItem(Icons.notifications_outlined, 'Notifications', () {
  Navigator.pop(context);
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
  );
}),
_drawerItem(Icons.help_outline_rounded, 'Help & Support', () {
  Navigator.pop(context);
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
  );
}),
                ],
              ),
            ),
            // ── Logout ──────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _border))),
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.logout_rounded,
                      color: Colors.red.shade400, size: 18),
                ),
                title: Text('Log Out',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade400)),
                onTap: _logout,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) => ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: _blueL, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: _blue),
        ),
        title: Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: _textPri)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: _border),
        onTap: onTap,
      );

  // ── Initials circle widget (shared) ──────────────────────
  Widget _initialsCircle(String initials, double size, double fontSize) =>
      Container(
        width: size,
        height: size,
        color: _blueL,
        child: Center(
          child: Text(initials,
              style: TextStyle(
                  fontSize: fontSize, fontWeight: FontWeight.w800, color: _blue)),
        ),
      );

  // ==========================================================================
  // APP BAR
  // ==========================================================================
  Widget _buildAppBar(
    Map<String, dynamic> data,
    bool verifiedBadge,
    String planKey,
    bool isPremium,
  ) {
    final name      = data['fullName']  as String? ?? '';
    final city      = data['city']      as String? ?? '';
    final area      = data['area']      as String? ?? '';
    final displayId = data['displayId'] as String? ?? '';
    final pic       = data['profilePic'] as String?;
    final plan      = _getCPlan(planKey);
    final initials  = _initials(name);
    final locationLine = city.isNotEmpty
        ? '$city${area.isNotEmpty ? ' · $area' : ''}'
        : '';

    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: _white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: _textPri),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('My Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPri)),
      actions: [
        IconButton(
          icon: const Icon(Icons.menu_rounded, color: _textPri),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        if (displayId.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 9),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _blue.withValues(alpha: 0.5)),
            ),
            child: Text(displayId,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: _blue)),
          ),
        const SizedBox(width: 14),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          color: _white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 58, 20, 16),
              child: Row(
                children: [
                  // ── Profile picture / initials avatar ──────
                  GestureDetector(
                    onTap: () => _pickImage('profile'),
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _blue, width: 2.5),
                          ),
                          child: ClipOval(
                            child: pic != null && pic.isNotEmpty
                                ? Image.network(
                                    pic,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _initialsCircle(initials, 80, 26),
                                  )
                                : _initialsCircle(initials, 80, 26),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                                color: _amber, shape: BoxShape.circle),
                            child: const Icon(Icons.edit_rounded,
                                size: 12, color: _white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name.isNotEmpty ? name : 'Your Name',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: _textPri,
                                    letterSpacing: -0.5),
                              ),
                            ),
                            if (verifiedBadge)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.verified_rounded,
                                    color: _blue, size: 18),
                              ),
                          ],
                        ),
                        if (locationLine.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 12, color: _textSec),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(locationLine,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12, color: _textSec)),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 5),
                        // Client role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: _blueL,
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('Client',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _blue)),
                        ),
                        const SizedBox(height: 5),
                        // Plan badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: plan.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: plan.fg.withValues(alpha: 0.3)),
                          ),
                          child: Text(plan.label,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: plan.fg)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _border, height: 1),
      ),
    );
  }

  // ==========================================================================
  // PLAN STATUS BANNER  (top of page — read-only, no buttons)
  // ==========================================================================
  Widget _planStatusBanner(
    String planKey,
    int projLeft,
    bool isPremium,
    bool isPending,
    String pendingPlan,
    bool expired,
    bool verifiedBadge,
  ) {
    // ── Awaiting admin approval ─────────────────────────────
    if (isPending && pendingPlan.isNotEmpty) {
      final pending = _getCPlan(pendingPlan);
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF6E3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: _amberD, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${pending.label} Plan — Awaiting Admin Approval',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _amberD)),
                  const SizedBox(height: 2),
                  const Text(
                      'Your payment is under review. Plan will activate within 24 hours.',
                      style: TextStyle(fontSize: 11, color: _textSec, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Expired plan ────────────────────────────────────────
    if (isPremium && expired) {
      final plan = _getCPlan(planKey);
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_off_outlined, color: Colors.red.shade500, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${plan.label} Plan — Expired',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade600)),
                  const SizedBox(height: 2),
                  Text('Contact support to renew your plan.',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Active plan ─────────────────────────────────────────
    final plan = _getCPlan(planKey);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: plan.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: plan.fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            planKey == 'Premium'
                ? Icons.star_rounded
                : planKey == 'Standard'
                    ? Icons.workspace_premium_rounded
                    : Icons.person_outline_rounded,
            color: plan.fg,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPremium
                  ? '${plan.label} Plan — ${projLeft == 999 ? 'Unlimited' : '$projLeft'} project${projLeft == 1 ? '' : 's'} left'
                  : '${plan.label} Plan — ${projLeft == 1 ? '1 project' : '$projLeft projects'} per month',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: plan.fg),
            ),
          ),
          if (verifiedBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration:
                  BoxDecoration(color: _blueL, borderRadius: BorderRadius.circular(6)),
              child: const Text('Verified',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: _blue)),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PROGRESS CARD
  // ==========================================================================
  Widget _progressCard(double prog, List<String> missing) {
    final pct = (prog * 100).toInt();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profile Completion',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _textPri)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: pct == 100 ? _greenL : _amberL,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('$pct%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: pct == 100 ? _green : _amberD)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: prog,
              minHeight: 7,
              backgroundColor: _border,
              valueColor: AlwaysStoppedAnimation(pct == 100 ? _green : _amber),
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${missing.length} field${missing.length == 1 ? '' : 's'} remaining:',
                style: const TextStyle(fontSize: 11, color: _textSec)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: missing
                  .map((m) => Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF6E3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _amber.withValues(alpha: 0.4)),
                        ),
                        child: Text(m,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _amberD)),
                      ))
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 13, color: _green),
                SizedBox(width: 5),
                Text('Profile complete!',
                    style: TextStyle(fontSize: 11, color: _green)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // PERSONAL CARD
  // fullName, nicNumber, city, area → READ-ONLY
  // phone → editable
  // ==========================================================================
  Widget _personalCard(Map<String, dynamic> data) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            _infoRow(Icons.person_outline_rounded, 'Full Name',
                data['fullName'], 'fullName',
                readOnly: true, first: true),
            _div(),
            _infoRow(Icons.badge_outlined, 'NIC Number',
                data['nicNumber'], 'nicNumber',
                readOnly: true),
            _div(),
            _infoRow(Icons.location_city_outlined, 'City',
                data['city'], 'city',
                readOnly: true),
            _div(),
            _infoRow(Icons.location_on_outlined, 'Area / Mohalla',
                data['area'], 'area',
                readOnly: true),
            _div(),
            _infoRow(Icons.phone_outlined, 'Phone',
                data['phone'], 'phone',
                isPhone: true, last: true),
          ],
        ),
      );

  Widget _div() => const Divider(height: 1, color: _border, indent: 62);

  Widget _infoRow(
    IconData icon,
    String label,
    String? value,
    String field, {
    bool isPhone  = false,
    bool readOnly = false,
    bool first    = false,
    bool last     = false,
  }) {
    final has = value?.trim().isNotEmpty ?? false;
    return InkWell(
      onTap: readOnly
          ? null
          : () => _editDialog(label, value ?? '', field, phone: isPhone),
      borderRadius: BorderRadius.vertical(
        top:    first ? const Radius.circular(16) : Radius.zero,
        bottom: last  ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: readOnly ? _surface : _amberL,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: readOnly ? _textSec : _amberD),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: _textSec,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    has ? value! : (readOnly ? 'Not provided' : 'Tap to add'),
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                        color: has ? _textPri : Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            Icon(
              readOnly
                  ? Icons.lock_outline_rounded
                  : Icons.chevron_right_rounded,
              size: 16,
              color: readOnly ? Colors.grey.shade300 : _border,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // NIC SECTION
  // ==========================================================================
  Widget _nicSection(Map<String, dynamic> data, bool nicVerified) {
    final frontUrl = data['nic_front_url'] as String?;
    final backUrl  = data['nic_back_url']  as String?;
    final bothUp   = (frontUrl?.isNotEmpty ?? false) &&
        (backUrl?.isNotEmpty ?? false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: nicVerified
          ? Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: _greenL, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.verified_rounded, color: _green, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CNIC Verified',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _green)),
                      SizedBox(height: 3),
                      Text('Your identity has been verified.',
                          style: TextStyle(
                              fontSize: 11, color: _textSec, height: 1.4)),
                    ],
                  ),
                ),
              ],
            )
          : bothUp
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: _amberL,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.hourglass_top_rounded,
                          color: _amberD, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CNIC Under Review',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _amberD)),
                          SizedBox(height: 3),
                          Text('Verification usually takes 2–24 hours.',
                              style: TextStyle(
                                  fontSize: 11, color: _textSec, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified_user_outlined,
                            size: 14, color: _textSec),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              'Upload both sides of your CNIC for identity verification.',
                              style: TextStyle(fontSize: 11, color: _textSec)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _nicBox('Front Side', frontUrl, 'front')),
                        const SizedBox(width: 12),
                        Expanded(child: _nicBox('Back Side', backUrl, 'back')),
                      ],
                    ),
                    if (_uploading) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                            minHeight: 3, color: _amber, backgroundColor: _border),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _nicBox(String label, String? url, String side) {
    final ok = url?.isNotEmpty ?? false;
    return GestureDetector(
      onTap: () => _pickImage(side),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _surface,
          border: Border.all(color: ok ? _green : _border, width: ok ? 1.5 : 1),
        ),
        child: ok
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.network(url!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: _green, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 10, color: _white),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                        color: _amberL, shape: BoxShape.circle),
                    child: const Icon(Icons.add_a_photo_outlined,
                        size: 19, color: _amberD),
                  ),
                  const SizedBox(height: 7),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textSec)),
                  const Text('Tap to upload',
                      style:
                          TextStyle(fontSize: 10, color: Color(0xFFBBBBBB))),
                ],
              ),
      ),
    );
  }

  // ==========================================================================
  // PLAN INFO CARD  (read-only — no purchase buttons)
  // Shows current plan perks + how to upgrade notice
  // ==========================================================================
  Widget _planInfoCard(
    String planKey,
    bool isPremium,
    bool isPending,
    String pendingPlan,
    int projLeft,
    bool expired,
  ) {
    final plan = _getCPlan(planKey);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Plan header ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: plan.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: plan.fg,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(
                    planKey == 'Premium'
                        ? Icons.star_rounded
                        : planKey == 'Standard'
                            ? Icons.workspace_premium_rounded
                            : Icons.person_outline_rounded,
                    size: 20,
                    color: _white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.label,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textPri)),
                      Text(plan.price,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: plan.fg)),
                    ],
                  ),
                ),
                // Active / pending / expired status chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending
                        ? _amberL
                        : isPremium && !expired
                            ? _greenL
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPending
                        ? 'Pending'
                        : isPremium && !expired
                            ? 'Active'
                            : expired
                                ? 'Expired'
                                : 'Current',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isPending
                          ? _amberD
                          : isPremium && !expired
                              ? _green
                              : expired
                                  ? Colors.red.shade500
                                  : _textSec,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Perks list ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...plan.perks.map((perk) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 14, color: plan.fg),
                          const SizedBox(width: 8),
                          Text(perk,
                              style: const TextStyle(
                                  fontSize: 13, color: _textPri)),
                        ],
                      ),
                    )),
                const SizedBox(height: 4),
                // ── Upgrade notice (no button — contact support) ──
                if (planKey == 'Free' || expired)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _blueL,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: _blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            expired
                                ? 'Your plan expired. Contact support or visit the billing screen to renew.'
                                : 'To upgrade your plan, visit Plans & Billing in the menu.',
                            style: const TextStyle(
                                fontSize: 11, color: _blue, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================
  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Text(t,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _textSec,
                letterSpacing: 1.2)),
      );

  void _pickImage(String side) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: _amberL, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: _amberD, size: 18),
                ),
                title: const Text('Camera',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _handleImage(side, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: _amberL, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library_rounded,
                      color: _amberD, size: 18),
                ),
                title: const Text('Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _handleImage(side, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _editDialog(String title, String current, String field,
      {bool phone = false}) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $title',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: phone ? TextInputType.number : TextInputType.text,
          maxLength: phone ? 11 : null,
          inputFormatters:
              phone ? [FilteringTextInputFormatter.digitsOnly] : [],
          decoration: InputDecoration(
            hintText: 'Enter $title',
            counterText: '',
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _amber, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              _set(field, ctrl.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber,
              foregroundColor: _navy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w500, color: _white)),
      backgroundColor: success ? _green : _amberD,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }
}