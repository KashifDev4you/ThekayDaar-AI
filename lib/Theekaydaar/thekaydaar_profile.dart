// =============================================================================
// thekaydaar_profile_screen.dart — COMPLETE REWRITE
//
// FIXES:
//   1. Reads from thekaydaars/{uid} — matches signup collection
//   2. fullName, nicNumber, city, area shown from signup (READ ONLY)
//   3. phone, category, rate, nic images, profilePic filled manually
//   4. Progress chips show exactly which fields are still missing
//   5. Drawer with logout → confirm dialog → pushNamedAndRemoveUntil('/')
//   6. Persistent login: handled in main.dart via authStateChanges()
//   7. Online/Offline toggle in app bar
//   8. NEW: Work Experience section — add/edit/delete entries, saved to
//      thekaydaars/{uid}.experience (array of maps: title, subtitle,
//      duration, description). Read by the public profile screen.
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:ali_app/Payment&Requests/billing_screen.dart';
import 'package:ali_app/Theekaydaar/my_bids_screen.dart';
import 'package:ali_app/profile_sub_pages/notifications/notifications_screen.dart';
import 'package:ali_app/profile_sub_pages/help_support_screen.dart';
import 'package:ali_app/utils/app_theme.dart';
// ─────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────
const _navy = Color(0xFF0E3B2E);
const _amber = Color(0xFFC9A227);
const _amberD = Color(0xFFA8861D);
const _amberL = Color(0xFFFBF6E3);
const _green = Color(0xFF10B981);
const _greenL = Color(0xFFD1FAE5);
const _border = Color(0xFFE3E0D5);
const _surface = Color(0xFFF7F5EF);
const _white = Color(0xFFFFFFFF);
const _textPri = Color(0xFF0E3B2E);
const _textSec = Color(0xFF5D6B64);

// ─────────────────────────────────────────────────────────────
// PLAN CONFIG
// ─────────────────────────────────────────────────────────────
class _Plan {
  final String key, label, price;
  final int bids;
  final bool canBid, canPost;
  final Color bg, fg;
  final List<String> perks;
  const _Plan({
    required this.key,
    required this.label,
    required this.price,
    required this.bids,
    required this.canBid,
    required this.canPost,
    required this.bg,
    required this.fg,
    required this.perks,
  });
}

const _plans = [
  _Plan(
    key: 'Free',
    label: 'Free',
    price: 'Rs 0/month',
    bids: 0,
    canBid: false,
    canPost: false,
    bg: AppTheme.bg,
    fg: AppTheme.textMuted,
    perks: [
      'Browse all projects',
      'View contractor profiles',
      'Basic visibility',
    ],
  ),
  _Plan(
    key: 'Pro',
    label: 'Pro',
    price: 'Rs 999/month',
    bids: 10,
    canBid: true,
    canPost: true,
    bg: Color(0xFFFBF6E3),
    fg: Color(0xFFA8861D),
    perks: [
      '10 bids/month',
      'Post gig & profile',
      'Verified badge',
      'Priority listing',
      'View all bids',
    ],
  ),
  _Plan(
    key: 'Elite',
    label: 'Elite',
    price: 'Rs 2499/month',
    bids: 15,
    canBid: true,
    canPost: true,
    bg: AppTheme.emeraldSoft,
    fg: AppTheme.emerald,
    perks: [
      '15 bids/month',
      'Featured in search',
      'Elite badge',
      'Analytics report',
      'Dedicated support',
    ],
  ),
];

_Plan _getPlan(String key) =>
    _plans.firstWhere((p) => p.key == key, orElse: () => _plans.first);

bool _planExpired(dynamic ts) {
  if (ts == null) return false;
  if (ts is Timestamp) {
    return DateTime.now().difference(ts.toDate()).inDays >= 30;
  }
  return false;
}

// =============================================================================
// SCREEN
// =============================================================================
class ThekaydaarProfileScreen extends StatefulWidget {
  const ThekaydaarProfileScreen({super.key});
  @override
  State<ThekaydaarProfileScreen> createState() =>
      _ThekaydaarProfileScreenState();
}

class _ThekaydaarProfileScreenState extends State<ThekaydaarProfileScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final String? uid = FirebaseAuth.instance.currentUser?.uid;
  bool _uploading = false;

  static const _cloudName = 'doblp5gf6';
  static const _uploadPreset = 'Thekaydaar';

  // ── Cloudinary ────────────────────────────────────────────
  Future<String?> _uploadToCloudinary(XFile f) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final bytes = await f.readAsBytes();
    final req = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: f.name),
      );
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

  // ── Firestore helpers ─────────────────────────────────────
  Future<void> _set(String field, dynamic value) async {
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('thekaydaars').doc(uid).set({
      field: value,
    }, SetOptions(merge: true));
  }

  Future<void> _setMap(Map<String, dynamic> map) async {
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('thekaydaars')
        .doc(uid)
        .set(map, SetOptions(merge: true));
  }

  // ── Progress: 4 from signup + 6 manual ───────────────────
  double _progress(Map<String, dynamic> d) {
    const fields = [
      'fullName', 'nicNumber', 'city', 'area', // signup
      'phone', 'category', 'rate', // manual
      'nic_front_url', 'nic_back_url', 'profilePic', // manual uploads
    ];
    if (d.isEmpty) return 0;
    return fields
            .where((f) => (d[f]?.toString().trim().isNotEmpty) == true)
            .length /
        fields.length;
  }

  // ── Which chips to show in progress card ─────────────────
  List<String> _missingChips(Map<String, dynamic> d) {
    final map = {
      'fullName': 'Full Name',
      'nicNumber': 'NIC',
      'city': 'City',
      'area': 'Area',
      'phone': 'Phone',
      'category': 'Category',
      'rate': 'Rate',
      'nic_front_url': 'NIC Front',
      'nic_back_url': 'NIC Back',
      'profilePic': 'Profile Pic',
    };
    return map.entries
        .where((e) => (d[e.key]?.toString().trim().isNotEmpty) != true)
        .map((e) => e.value)
        .toList();
  }

  // ── Plan activation ───────────────────────────────────────
  // ignore: unused_element
  Future<void> _activatePlan(String key) async {
    final p = _getPlan(key);
    await _setMap({
      'isPremium': key != 'Free',
      'planName': key,
      'bidsRemaining': p.bids,
      'bidsTotal': p.bids,
      'canBid': p.canBid,
      'canPostGig': p.canPost,
      'verifiedBadge': key != 'Free',
      'featuredListing': key == 'Elite',
      'planActivatedAt': FieldValue.serverTimestamp(),
      'paymentPending': false,
      'pendingPlan': FieldValue.delete(),
    });
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

  // ── Logout with confirm dialog ────────────────────────────
  Future<void> _logout() async {
    Navigator.pop(context); // close drawer
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _textPri,
          ),
        ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      }
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
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Exit App?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            content: const Text(
              'You will remain logged in.',
              style: TextStyle(fontSize: 13, color: _textSec),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay', style: TextStyle(color: _amberD)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: _navy,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Exit',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
        if (exit == true && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('thekaydaars')
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

          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final prog = _progress(data);
          final isComplete = prog >= 1.0;
          final missing = _missingChips(data);
          final planKey = data['planName'] as String? ?? 'Free';
          final isPremium = data['isPremium'] as bool? ?? false;
          final isPending = data['paymentPending'] as bool? ?? false;
          final pendingPlan = data['pendingPlan'] as String? ?? '';
          final bidsLeft = data['bidsRemaining'] as int? ?? 0;
          final canBid = data['canBid'] as bool? ?? false;
          final canPost = data['canPostGig'] as bool? ?? false;
          final nicVerified = data['nicVerified'] as bool? ?? false;
          final skills = List<String>.from(data['skills'] as List? ?? []);
          // ── NEW: work experience entries ──────────────────────
          final experience = (data['experience'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final planExpired = _planExpired(data['planActivatedAt']);

          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: _surface,
            drawer: _buildDrawer(data),
            body: CustomScrollView(
              slivers: [
                _buildAppBar(data, bidsLeft, planKey, isPremium),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _planBanner(
                        planKey,
                        bidsLeft,
                        isPremium,
                        canBid,
                        canPost,
                        planExpired,
                      ),
                      _progressCard(prog, missing),
                      const SizedBox(height: 24),
                      _sectionLabel('PERSONAL INFO'),
                      const SizedBox(height: 8),
                      _personalCard(data),
                      const SizedBox(height: 24),
                      _sectionLabel('SKILLS'),
                      const SizedBox(height: 8),
                      _skillsCard(skills),
                      const SizedBox(height: 24),
                      // ── NEW: Work Experience section ────────────
                      _sectionLabel('WORK EXPERIENCE'),
                      const SizedBox(height: 8),
                      _experienceCard(experience),
                      const SizedBox(height: 24),
                      _sectionLabel('NIC VERIFICATION'),
                      const SizedBox(height: 8),
                      _nicSection(data, nicVerified),
                      const SizedBox(height: 24),
                      _sectionLabel('SUBSCRIPTION'),
                      const SizedBox(height: 8),
                      _planSection(
                        isComplete,
                        isPremium,
                        isPending,
                        pendingPlan,
                        planKey,
                        planExpired,
                      ),
                      if (canPost) ...[
                        const SizedBox(height: 24),
                        _sectionLabel('MY GIG'),
                        const SizedBox(height: 8),
                        _gigButton(),
                      ],
                      const SizedBox(height: 24),
                      _mainButton(
                        isComplete,
                        isPremium,
                        isPending,
                        pendingPlan,
                        planKey,
                      ),
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
    final name = data['fullName'] as String? ?? '';
    final category = data['category'] as String? ?? '';
    final city = data['city'] as String? ?? '';
    final area = data['area'] as String? ?? '';
    final pic = data['profilePic'] as String?;
    final planKey = data['planName'] as String? ?? 'Free';
    final bidsLeft = data['bidsRemaining'] as int? ?? 0;
    final displayId = data['displayId'] as String? ?? '';
    final plan = _getPlan(planKey);

    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    final subtitle = category.isNotEmpty
        ? category
        : city.isNotEmpty
        ? '$city${area.isNotEmpty ? ' · $area' : ''}'
        : '';

    return Drawer(
      backgroundColor: _white,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              color: _navy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _amber, width: 2.5),
                    ),
                    child: ClipOval(
                      child: pic != null && pic.isNotEmpty
                          ? Image.network(pic, fit: BoxFit.cover)
                          : Container(
                              color: _amberL,
                              child: Center(
                                child: Text(
                                  initials.isNotEmpty ? initials : '?',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: _amberD,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Name
                  Text(
                    name.isNotEmpty ? name : 'Thekaydaar',
                    style: const TextStyle(
                      color: _white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  // Subtitle (category or city)
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFA6B2AB),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  // Display ID
                  if (displayId.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      displayId,
                      style: const TextStyle(
                        color: Color(0xFF5D6B64),
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Badges row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: plan.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          plan.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: plan.fg,
                          ),
                        ),
                      ),
                      if (bidsLeft > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _amberL.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _amber.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '$bidsLeft bids left',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _amber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Menu Items ────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(
                    Icons.person_outline_rounded,
                    'My Profile',
                    // Already on the profile screen — just close the drawer.
                    () => Navigator.pop(context),
                  ),
                  _drawerItem(
                    Icons.workspace_premium_rounded,
                    'Plans & Billing',
                    () {
                      Navigator.pop(context); // close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const BillingScreen(role: 'thekaydaar'),
                        ),
                      );
                    },
                  ),
                  _drawerItem(
                    Icons.gavel_rounded,
                    'My Bids',
                    () {
                      Navigator.pop(context); // close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyBidsScreen(),
                        ),
                      );
                    },
                  ),
                  _drawerItem(
                    Icons.work_outline_rounded,
                    'My Gig',
                    () {
                      Navigator.pop(context); // close drawer
                      if (uid == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GigPostScreen(uid: uid!),
                        ),
                      );
                    },
                  ),
                  _drawerItem(
                    Icons.receipt_long_outlined,
                    'Payment History',
                    () {
                      Navigator.pop(context); // close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BillingScreen(
                            role: 'thekaydaar',
                            initialTab: 1,
                          ),
                        ),
                      );
                    },
                  ),
                  _drawerItem(
                    Icons.notifications_outlined,
                    'Notifications',
                    () {
                      Navigator.pop(context); // close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  _drawerItem(
                    Icons.help_outline_rounded,
                    'Help & Support',
                    () {
                      Navigator.pop(context); // close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Logout ────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.red.shade400,
                    size: 18,
                  ),
                ),
                title: Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade400,
                  ),
                ),
                onTap: _logout,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) =>
      ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _amberL,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: _amberD),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textPri,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: _border,
        ),
        onTap: onTap,
      );

  // ==========================================================================
  // APP BAR — shows name, city·area, category from Firestore
  // ==========================================================================
  Widget _buildAppBar(
    Map<String, dynamic> data,
    int bidsLeft,
    String planKey,
    bool isPremium,
  ) {
    final name = data['fullName'] as String? ?? '';
    final category = data['category'] as String? ?? '';
    final city = data['city'] as String? ?? '';
    final area = data['area'] as String? ?? '';
    final displayId = data['displayId'] as String? ?? '';
    final pic = data['profilePic'] as String?;
    final isOnline = data['available'] as bool? ?? true;
    final plan = _getPlan(planKey);

    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
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
      title: const Text(
        'My Profile',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _textPri,
        ),
      ),
      actions: [
        // Wrapped in FittedBox — 4 chips here (menu + ID + bids + online)
        // can overflow on narrow screens, so the row scales down instead.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    border: Border.all(color: _amber.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    displayId,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _amber,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              if (bidsLeft > 0)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 9),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _amberL,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _amber),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.gavel_rounded, size: 13, color: _amberD),
                      const SizedBox(width: 4),
                      Text(
                        '$bidsLeft',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _amberD,
                        ),
                      ),
                    ],
                  ),
                ),
              // Online/Offline toggle
              GestureDetector(
                onTap: () => _set('available', !isOnline),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 9, 14, 9),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isOnline ? _greenL : AppTheme.bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isOnline ? _green : _border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOnline ? _green : _textSec,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOnline ? _green : _textSec,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
                  // Profile picture
                  GestureDetector(
                    onTap: () => _pickImage('profile'),
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _amber, width: 2.5),
                          ),
                          child: ClipOval(
                            child: pic != null && pic.isNotEmpty
                                ? Image.network(pic, fit: BoxFit.cover)
                                : Container(
                                    color: _amberL,
                                    child: Center(
                                      child: Text(
                                        initials.isNotEmpty ? initials : '?',
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: _amberD,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: _amber,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 12,
                              color: _white,
                            ),
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
                        // Name from signup
                        Text(
                          name.isNotEmpty ? name : 'Your Name',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _textPri,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // City · Area from signup
                        if (locationLine.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: _textSec,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                locationLine,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textSec,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 5),
                        // Category chip (set manually in profile)
                        if (category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _amberL,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _amberD,
                              ),
                            ),
                          ),
                        if (category.isNotEmpty) const SizedBox(height: 5),
                        // Plan badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: plan.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: plan.fg.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            plan.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: plan.fg,
                            ),
                          ),
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
  // PLAN BANNER
  // ==========================================================================
  Widget _planBanner(
    String key,
    int bidsLeft,
    bool isPremium,
    bool canBid,
    bool canPost,
    bool expired,
  ) {
    final plan = _getPlan(key);
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
            key == 'Elite'
                ? Icons.star_rounded
                : key == 'Pro'
                ? Icons.workspace_premium_rounded
                : Icons.person_outline_rounded,
            color: plan.fg,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              expired && key != 'Free'
                  ? '${plan.label} Plan — Expired · Renew now'
                  : '${plan.label} Plan — ${canBid ? '$bidsLeft bids left' : 'Browse only'}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: plan.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PROGRESS CARD — shows missing field chips
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
              const Text(
                'Profile Completion',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPri,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pct == 100 ? _greenL : _amberL,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: pct == 100 ? _green : _amberD,
                  ),
                ),
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
            Text(
              '${missing.length} field${missing.length == 1 ? '' : 's'} remaining:',
              style: const TextStyle(fontSize: 11, color: _textSec),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: missing
                  .map(
                    (m) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF6E3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        m,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _amberD,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 13, color: _green),
                const SizedBox(width: 5),
                const Text(
                  'Profile complete! You can now subscribe.',
                  style: TextStyle(fontSize: 11, color: _green),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // PERSONAL CARD
  // fullName, nicNumber, city, area → readOnly (from signup)
  // phone, category, rate → editable
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
        _infoRow(
          Icons.person_outline_rounded,
          'Full Name',
          data['fullName'],
          'fullName',
          readOnly: true,
          first: true,
        ),
        _div(),
        _infoRow(
          Icons.badge_outlined,
          'NIC Number',
          data['nicNumber'],
          'nicNumber',
          readOnly: true,
        ),
        _div(),
        _infoRow(
          Icons.location_city_outlined,
          'City',
          data['city'],
          'city',
          readOnly: true,
        ),
        _div(),
        _infoRow(
          Icons.location_on_outlined,
          'Area / Mohalla',
          data['area'],
          'area',
          readOnly: true,
        ),
        _div(),
        _infoRow(
          Icons.phone_outlined,
          'Phone',
          data['phone'],
          'phone',
          isPhone: true,
        ),
        _div(),
        _categoryRow(data['category']),
        _div(),
        _rateRow(data['rate'], last: true),
      ],
    ),
  );

  Widget _div() => const Divider(height: 1, color: _border, indent: 62);

  Widget _infoRow(
    IconData icon,
    String label,
    String? value,
    String field, {
    bool isPhone = false,
    bool readOnly = false,
    bool first = false,
    bool last = false,
  }) {
    final has = value?.trim().isNotEmpty ?? false;
    return InkWell(
      onTap: readOnly
          ? null
          : () => _editDialog(label, value ?? '', field, phone: isPhone),
      borderRadius: BorderRadius.vertical(
        top: first ? const Radius.circular(16) : Radius.zero,
        bottom: last ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _amberL,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: _amberD),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: _textSec,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    has ? value! : (readOnly ? 'Not provided' : 'Tap to add'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                      color: has ? _textPri : Colors.grey.shade400,
                    ),
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

  Widget _categoryRow(String? current) {
    final has = current?.trim().isNotEmpty ?? false;
    return InkWell(
      onTap: () => _categoryDialog(current ?? ''),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _amberL,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.handyman_outlined,
                size: 17,
                color: _amberD,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Primary Category',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: _textSec,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    has ? current! : 'Tap to select',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                      color: has ? _textPri : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: _border),
          ],
        ),
      ),
    );
  }

  Widget _rateRow(String? rate, {bool last = false}) {
    final has = rate?.trim().isNotEmpty ?? false;
    return InkWell(
      onTap: () => _rateDialog(rate ?? ''),
      borderRadius: last
          ? const BorderRadius.vertical(bottom: Radius.circular(16))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _amberL,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.payments_outlined,
                size: 17,
                color: _amberD,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Rate',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: _textSec,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    has ? rate! : 'Tap to set rate',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                      color: has ? _textPri : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: _border),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SKILLS CARD
  // ==========================================================================
  Widget _skillsCard(List<String> skills) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
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
            const Text(
              'Your Skills',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textPri,
              ),
            ),
            GestureDetector(
              onTap: () => _skillPicker(skills),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _amberL,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _amber),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 13, color: _amberD),
                    SizedBox(width: 3),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _amberD,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        skills.isEmpty
            ? Text(
                'No skills added. Tap "Add" to begin.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills
                    .map(
                      (s) => GestureDetector(
                        onTap: () => _set(
                          'skills',
                          skills.where((x) => x != s).toList(),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _amberL,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _amber.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _amberD,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.close, size: 11, color: _amberD),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ],
    ),
  );

  // ==========================================================================
  // WORK EXPERIENCE CARD (NEW)
  // Reads/writes thekaydaars/{uid}.experience — array of maps:
  // { title, subtitle, duration, description }. Consumed by the public
  // profile screen's LinkedIn-style Experience section.
  // ==========================================================================
  Widget _experienceCard(List<Map<String, dynamic>> experience) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
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
            const Text(
              'Work Experience',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textPri,
              ),
            ),
            GestureDetector(
              onTap: () => _experienceDialog(experience),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _amberL,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _amber),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 13, color: _amberD),
                    SizedBox(width: 3),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _amberD,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Shows on your public profile — clients see this before hiring.',
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 12),
        experience.isEmpty
            ? Text(
                'No experience added yet. Tap "Add" to begin.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              )
            : Column(
                children: List.generate(experience.length, (i) {
                  return _experienceTile(experience[i], i, experience);
                }),
              ),
      ],
    ),
  );

  Widget _experienceTile(
    Map<String, dynamic> e,
    int index,
    List<Map<String, dynamic>> all,
  ) {
    final title = e['title'] as String? ?? '';
    final subtitle = e['subtitle'] as String? ?? '';
    final duration = e['duration'] as String? ?? '';
    final description = e['description'] as String? ?? '';
    final isLast = index == all.length - 1;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: _amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _textPri,
                    ),
                  ),
                if (subtitle.isNotEmpty || duration.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        subtitle,
                        duration,
                      ].where((s) => s.isNotEmpty).join('  ·  '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: () => _experienceDialog(all, editIndex: index),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: _textSec,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  final updated = List<Map<String, dynamic>>.from(all)
                    ..removeAt(index);
                  _set('experience', updated);
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _experienceDialog(List<Map<String, dynamic>> current, {int? editIndex}) {
    final isEdit = editIndex != null;
    final existing = isEdit ? current[editIndex] : <String, dynamic>{};
    final titleCtrl = TextEditingController(
      text: existing['title'] as String? ?? '',
    );
    final subtitleCtrl = TextEditingController(
      text: existing['subtitle'] as String? ?? '',
    );
    final durationCtrl = TextEditingController(
      text: existing['duration'] as String? ?? '',
    );
    final descCtrl = TextEditingController(
      text: existing['description'] as String? ?? '',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEdit ? 'Edit Experience' : 'Add Experience',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _expField(titleCtrl, 'Role / Title', 'e.g. Senior Electrician'),
              const SizedBox(height: 10),
              _expField(
                subtitleCtrl,
                'Company / Type',
                'e.g. Self-employed',
              ),
              const SizedBox(height: 10),
              _expField(durationCtrl, 'Duration', 'e.g. 2019 - Present'),
              const SizedBox(height: 10),
              _expField(
                descCtrl,
                'Description',
                'What did you do, tools used, notable work...',
                lines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          if (isEdit)
            TextButton(
              onPressed: () {
                final updated = List<Map<String, dynamic>>.from(current)
                  ..removeAt(editIndex);
                _set('experience', updated);
                Navigator.pop(context);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              final entry = {
                'title': titleCtrl.text.trim(),
                'subtitle': subtitleCtrl.text.trim(),
                'duration': durationCtrl.text.trim(),
                'description': descCtrl.text.trim(),
              };
              // Skip saving a completely empty entry
              if (entry['title']!.isEmpty && entry['description']!.isEmpty) {
                Navigator.pop(context);
                return;
              }
              final updated = List<Map<String, dynamic>>.from(current);
              if (isEdit) {
                updated[editIndex] = entry;
              } else {
                updated.add(entry);
              }
              _set('experience', updated);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber,
              foregroundColor: _navy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expField(
    TextEditingController ctrl,
    String label,
    String hint, {
    int lines = 1,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _textPri,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        maxLines: lines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _amber, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    ],
  );

  // ==========================================================================
  // NIC SECTION
  // ==========================================================================
  Widget _nicSection(Map<String, dynamic> data, bool nicVerified) {
    final frontUrl = data['nic_front_url'] as String?;
    final backUrl = data['nic_back_url'] as String?;
    final bothUp =
        (frontUrl?.isNotEmpty ?? false) && (backUrl?.isNotEmpty ?? false);

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
                    color: _greenL,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: _green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CNIC Verified',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Your identity has been verified.',
                        style: TextStyle(
                          fontSize: 11,
                          color: _textSec,
                          height: 1.4,
                        ),
                      ),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: _amberD,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CNIC Under Review',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _amberD,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Verification usually takes 2–24 hours.',
                        style: TextStyle(
                          fontSize: 11,
                          color: _textSec,
                          height: 1.4,
                        ),
                      ),
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
                    Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: _textSec,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Upload both sides of your CNIC for identity verification.',
                        style: TextStyle(fontSize: 11, color: _textSec),
                      ),
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
                      minHeight: 3,
                      color: _amber,
                      backgroundColor: _border,
                    ),
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
                    child: Image.network(
                      url!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: _green,
                        shape: BoxShape.circle,
                      ),
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
                      color: _amberL,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      size: 19,
                      color: _amberD,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _textSec,
                    ),
                  ),
                  const Text(
                    'Tap to upload',
                    style: TextStyle(fontSize: 10, color: Color(0xFFBBBBBB)),
                  ),
                ],
              ),
      ),
    );
  }

  // ==========================================================================
  // PLAN SECTION
  // ==========================================================================
  Widget _planSection(
    bool isComplete,
    bool isPremium,
    bool isPending,
    String pendingPlan,
    String activePlanKey,
    bool planExpired,
  ) {
    final visible = (isPremium && !planExpired)
        ? _plans.where((p) => p.key == activePlanKey).toList()
        : List<_Plan>.from(_plans);

    return Opacity(
      opacity: isComplete ? 1.0 : 0.45,
      child: AbsorbPointer(
        absorbing: !isComplete,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              if (!isComplete)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: _amberD),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Complete your profile to unlock plans.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isPremium && planExpired)
                Container(
                  margin: const EdgeInsets.all(14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_off_outlined,
                        size: 14,
                        color: Colors.red.shade500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your plan has expired. Renew below.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ...visible.asMap().entries.map(
                (e) => Column(
                  children: [
                    if (e.key > 0)
                      Divider(height: 1, color: Colors.grey.shade100),
                    _planTile(
                      e.value,
                      isSel: activePlanKey == e.value.key,
                      isPendingThis: isPending && pendingPlan == e.value.key,
                      onTap: () {
                        if (!isPending && activePlanKey != e.value.key) {
                          _showPaymentSheet(
                            e.value.key,
                            e.value.label,
                            e.value.price,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planTile(
    _Plan p, {
    required bool isSel,
    required bool isPendingThis,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSel ? p.bg : _white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSel ? p.fg : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                p.key == 'Elite'
                    ? Icons.star_rounded
                    : p.key == 'Pro'
                    ? Icons.workspace_premium_rounded
                    : Icons.person_outline_rounded,
                size: 20,
                color: isSel ? _white : Colors.grey.shade400,
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
                        p.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSel ? _textPri : _textSec,
                        ),
                      ),
                      if (isPendingThis) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF6E3),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFFE6D694)),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFFA8861D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.price,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.fg,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...p.perks.map(
                    (perk) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            isSel
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 12,
                            color: isSel ? p.fg : Colors.grey.shade300,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            perk,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSel ? _textPri : _textSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (p.key != 'Free' && !isSel && !isPendingThis) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p.fg,
                          foregroundColor: _white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Get ${p.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isSel
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSel ? p.fg : Colors.grey.shade300,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // GIG BUTTON
  // ==========================================================================
  Widget _gigButton() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GigPostScreen(uid: uid!)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _amber, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _amberL,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.work_outline_rounded,
                size: 20,
                color: _amberD,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage My Gig',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPri,
                    ),
                  ),
                  Text(
                    'Post your services for clients to find you',
                    style: TextStyle(fontSize: 11, color: _textSec),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _amberD),
          ],
        ),
      ),
    ),
  );

  // ==========================================================================
  // MAIN BUTTON
  // ==========================================================================
  Widget _mainButton(
    bool isComplete,
    bool isPremium,
    bool isPending,
    String pendingPlan,
    String planKey,
  ) {
    final plan = _getPlan(isPending ? pendingPlan : planKey);
    if (isPremium && !isPending) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _greenL,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _green.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: _green, size: 18),
              const SizedBox(width: 8),
              Text(
                '${plan.label} Plan Active',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _green,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // In thekaydaar_profile_screen.dart — _mainButton()
    // ignore: unused_element
    Widget mainButton(
      bool isComplete,
      bool isPremium,
      bool isPending,
      String pendingPlan,
      String planKey,
    ) {
      final plan = _getPlan(isPending ? pendingPlan : planKey);

      // Already active
      if (isPremium && !isPending) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _greenL,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: _green, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${plan.label} Plan Active',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // REPLACE the old "Activate" button with a pending notice
      if (isComplete && isPending && pendingPlan.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFBF6E3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: _amberD,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${plan.label} — Awaiting Admin Approval',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _amberD,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Not complete or no plan selected
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          onPressed: isComplete
              ? () => _snack('Select a Pro or Elite plan above.')
              : () => _snack('Complete your profile first.'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _amber,
            foregroundColor: _navy,
            minimumSize: const Size(double.infinity, 52),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            isComplete ? 'Select a Plan Above' : 'Complete Profile First',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: isComplete
            ? () => _snack('Select a Pro or Elite plan above.')
            : () => _snack('Complete your profile first.'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _amber,
          foregroundColor: _navy,
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          isComplete ? 'Select a Plan Above' : 'Complete Profile First',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================
  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: _textSec,
        letterSpacing: 1.2,
      ),
    ),
  );

  void _pickImage(String side) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _amberL,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: _amberD,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Camera',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
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
                    color: _amberL,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: _amberD,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
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

  void _editDialog(
    String title,
    String current,
    String field, {
    bool phone = false,
  }) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit $title',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: phone ? TextInputType.number : TextInputType.text,
          maxLength: phone ? 11 : null,
          inputFormatters: phone
              ? [FilteringTextInputFormatter.digitsOnly]
              : [],
          decoration: InputDecoration(
            hintText: 'Enter $title',
            counterText: '',
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _amber, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _rateDialog(String current) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Set Daily Rate',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            prefixText: 'Rs  ',
            hintText: 'e.g. 1500',
            suffixText: '/ Day',
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _amber, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                _set('rate', 'Rs ${ctrl.text.trim()}/Day');
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber,
              foregroundColor: _navy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _categoryDialog(String current) async {
    final cats = await _fetchCategories();
    if (!mounted) return;
    String sel = cats.contains(current) ? current : cats.first;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: _white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Select Category',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: sel,
                isExpanded: true,
                items: cats
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 14)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setD(() => sel = v);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _textSec)),
            ),
            ElevatedButton(
              onPressed: () {
                _set('category', sel);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: _navy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _skillPicker(List<String> current) async {
    final all = await _fetchCategories();
    if (!mounted) return;
    final sel = Set<String>.from(current);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Select Skills',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap to toggle',
                style: TextStyle(fontSize: 11, color: _textSec),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: all.map((cat) {
                  final isOn = sel.contains(cat);
                  return GestureDetector(
                    onTap: () =>
                        setS(() => isOn ? sel.remove(cat) : sel.add(cat)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isOn ? _amber : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isOn ? _amberD : Colors.grey.shade200,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isOn ? _white : _textSec,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _set('skills', sel.toList());
                    Navigator.pop(ctx);
                  },
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
                    'Save Skills',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentSheet(String key, String label, String price) {
    if (uid == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(
        uid: uid!,
        planKey: key,
        planLabel: label,
        planPrice: price,
        collection: 'thekaydaars',
      ),
    );
  }

  Future<List<String>> _fetchCategories() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('categories')
          .orderBy('name')
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) => (d.data()['name'] as String?) ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return _defaultCats;
  }

  static const _defaultCats = [
    'Electrician',
    'Plumber',
    'Painter',
    'Carpenter',
    'Mason (Mistri)',
    'Interior Designer',
    'Laborer (Mazdoor)',
    'AC Technician',
    'Welder',
    'Tiles Expert',
  ];

  void _snack(String msg, {bool success = false}) {
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
// PAYMENT SHEET
// =============================================================================
class _PaymentSheet extends StatefulWidget {
  final String uid, planKey, planLabel, planPrice, collection;
  const _PaymentSheet({
    required this.uid,
    required this.planKey,
    required this.planLabel,
    required this.planPrice,
    required this.collection,
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
          content: Text('Enter Transaction ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('payment_requests').add({
        'uid': widget.uid,
        'plan': widget.planKey,
        'planLabel': widget.planLabel,
        'amount': widget.planPrice,
        'txnId': _ctrl.text.trim(),
        'method': _method,
        'role': widget.collection,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection(widget.collection)
          .doc(widget.uid)
          .set({
            'paymentPending': true,
            'pendingPlan': widget.planKey,
          }, SetOptions(merge: true));
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
      const SizedBox(height: 20),
      Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(color: _greenL, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: _green, size: 36),
      ),
      const SizedBox(height: 16),
      const Text(
        'Payment Request Submitted!',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Plan will activate within 24 hours after verification.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: _textSec, height: 1.5),
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
            'Done',
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
          _bar(),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _amberL,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: _amberD,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade to ${widget.planLabel}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    widget.planPrice,
                    style: const TextStyle(fontSize: 12, color: _amberD),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _step('Step 1 — Choose method'),
          const SizedBox(height: 10),
          Row(
            children: [
              _methodChip('EasyPaisa', Icons.account_balance_wallet_outlined),
              const SizedBox(width: 10),
              _methodChip('JazzCash', Icons.payment_outlined),
            ],
          ),
          const SizedBox(height: 20),
          _step('Step 2 — Send payment to:'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _amberL,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  num,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: _textPri,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: num));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: _amberD,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _step('Step 3 — Enter Transaction ID'),
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
          const SizedBox(height: 20),
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

  Widget _step(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade500,
      letterSpacing: 0.5,
    ),
  );

  Widget _methodChip(String name, IconData icon) {
    final sel = _method == name;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _method = name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
              Icon(icon, color: sel ? _amberD : Colors.grey.shade400, size: 24),
              const SizedBox(height: 4),
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

// =============================================================================
// GIG POST SCREEN
// =============================================================================
class GigPostScreen extends StatefulWidget {
  final String uid;
  const GigPostScreen({super.key, required this.uid});
  @override
  State<GigPostScreen> createState() => _GigPostScreenState();
}

class _GigPostScreenState extends State<GigPostScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  static const _cloudName = 'doblp5gf6';
  static const _uploadPreset = 'Thekaydaar';

  List<String> _portfolioUrls = [];
  bool _saving = false, _uploading = false, _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance
        .collection('gigs')
        .doc(widget.uid)
        .get();
    if (doc.exists) {
      final d = doc.data()!;
      _titleCtrl.text = d['title'] ?? '';
      _descCtrl.text = d['description'] ?? '';
      _priceCtrl.text = (d['price'] ?? '')
          .toString()
          .replaceAll('Rs ', '')
          .replaceAll('/Day', '');
      _portfolioUrls = List<String>.from(d['portfolioUrls'] ?? []);
    }
    setState(() => _loaded = true);
  }

  Future<String?> _upload(XFile f) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final bytes = await f.readAsBytes();
    final req = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: f.name),
      );
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

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty ||
        _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('gigs').doc(widget.uid).set({
      'uid': widget.uid,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'price': 'Rs ${_priceCtrl.text.trim()}/Day',
      'portfolioUrls': _portfolioUrls,
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    }, SetOptions(merge: true));
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _surface,
    appBar: AppBar(
      backgroundColor: _white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _textPri,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'My Gig',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _textPri,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _border, height: 1),
      ),
    ),
    body: !_loaded
        ? const Center(child: CircularProgressIndicator(color: _amber))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(
                'Gig Title',
                _titleCtrl,
                'e.g. Expert Plumber for Home & Office',
              ),
              const SizedBox(height: 16),
              _field(
                'Description',
                _descCtrl,
                'Describe your experience, tools, and skills...',
                lines: 5,
              ),
              const SizedBox(height: 16),
              _field(
                'Daily Rate (Rs)',
                _priceCtrl,
                'e.g. 1500',
                num: true,
                prefix: 'Rs ',
                suffix: '/Day',
              ),
              const SizedBox(height: 24),
              const Text(
                'Portfolio Photos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPri,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add work photos to build trust',
                style: TextStyle(fontSize: 11, color: _textSec),
              ),
              const SizedBox(height: 12),
              _grid(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: _navy,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _white,
                          ),
                        )
                      : const Text(
                          'Save & Publish',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
  );

  Widget _field(
    String lbl,
    TextEditingController ctrl,
    String hint, {
    int lines = 1,
    bool num = false,
    String? prefix,
    String? suffix,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        lbl,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _textPri,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        maxLines: lines,
        keyboardType: num ? TextInputType.number : TextInputType.text,
        inputFormatters: num ? [FilteringTextInputFormatter.digitsOnly] : [],
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          suffixText: suffix,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          filled: true,
          fillColor: _white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
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
    ],
  );

  Widget _grid() {
    final items = [..._portfolioUrls, 'add'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, i) {
        if (items[i] == 'add') {
          return GestureDetector(
            onTap: _uploading
                ? null
                : () async {
                    final f = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 60,
                    );
                    if (f == null) return;
                    setState(() => _uploading = true);
                    final url = await _upload(f);
                    if (url != null) setState(() => _portfolioUrls.add(url));
                    setState(() => _uploading = false);
                  },
            child: Container(
              decoration: BoxDecoration(
                color: _amberL,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber),
              ),
              child: _uploading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _amber,
                        strokeWidth: 2,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: _amberD,
                          size: 26,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 10,
                            color: _amberD,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        }
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                items[i],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => setState(() => _portfolioUrls.remove(items[i])),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: _white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}