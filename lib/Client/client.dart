import 'package:ali_app/Client/client_profile.dart';
import 'package:ali_app/Client/client_projects_list_screen.dart';
import 'package:ali_app/Client/contractor_search_screen.dart';
import 'package:ali_app/ui/material_estimator_screen.dart';
import 'package:ali_app/house_planner/screens/create_project_wizard.dart';
import 'package:ali_app/Client/client_project_detail.dart';
import 'package:ali_app/MessageAndNotification/new_badge_icon.dart';
import 'package:ali_app/Theekaydaar/thekaydaar_public_profile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ali_app/MessageAndNotification/conversations_inbox_screen.dart';
import 'package:ali_app/MessageAndNotification/cloudinary_service.dart';
import 'package:ali_app/MessageAndNotification/cloudinary_config.dart';
import 'package:ali_app/Widgets/language_toggle_widget.dart';
import 'package:ali_app/utils/feature_gate.dart';
import 'package:ali_app/profile_sub_pages/notifications/notification_bell.dart';
import 'package:ali_app/services/translation_service.dart';
// NOTE: adjust this path to wherever you save time_ago.dart in your project
// (e.g. lib/utils/time_ago.dart). It exports a single `timeAgo(dynamic)` function.
import 'package:ali_app/utils/time_ago.dart';
// NOTE: adjust this path too — same idea, exports `formatPriceShort(dynamic)`.
import 'package:ali_app/utils/price_formatter.dart';
// Public profile screen — real class is ThekaydaarPublicProfile,
// constructor takes `thekaydaarUid`.


class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});
  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  int _selectedNavIndex = 0;
  String _selectedFilter = 'All';

  final User? _authUser = FirebaseAuth.instance.currentUser;
  String get _uid => _authUser?.uid ?? '';

  // ── DESIGN SYSTEM: Navy/Amber brand palette ─────────────────
  // These replace the old green (#198754) brand colors. Green is
  // now reserved ONLY for true status indicators (Verified badge,
  // Available badge, Open project status) — never for buttons,
  // logo, avatars, or active nav/filter states.
  static const _bg = Color(0xFFF7F5EF);
  static const _surface = Colors.white;
  static const _amberLight = Color(0xFFFBF6E3);
  static const _amber = Color(0xFFC9A227);
  static const _amberDark = Color(0xFFA8861D);
  static const _navy = Color(0xFF0E3B2E);
  static const _textPri = Color(0xFF0E3B2E);
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  // ── Semantic status colors (kept separate from brand) ───────
  static const _success = Color(0xFF10B981);
  static const _successLight = Color(0xFFD1FAE5);

  final List<String> _filters = [
    'All',
    'Plumber',
    'Electrician',
    'Carpenter',
    'Painter',
  ];

  Future<void> _ensureClientDoc(Map<String, dynamic> userData) async {
    if (_uid.isEmpty) return;
    final ref = FirebaseFirestore.instance.collection('clients').doc(_uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': _uid,
        'fullName': userData['fullName'] ?? '',
        'nicNumber': userData['nicNumber'] ?? '',
        'role': 'client',
        'displayId': userData['displayId'] ?? '',
        'email': userData['email'] ?? '',
        'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
        'area': '',
        'phone': '',
        // ── FIX: carry the profile picture over from users/{uid}
        //         so it's available on the client doc too. ────
        'profilePic': userData['profilePic'] ?? '',
      }, SetOptions(merge: true));
    }
  }

  Stream<DocumentSnapshot> get _userStream =>
      FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
  Stream<DocumentSnapshot> get _clientStream =>
      FirebaseFirestore.instance.collection('clients').doc(_uid).snapshots();
  // ── NEW: only show contractors who've pinged `lastActive` within
  //         the last 5 minutes — i.e. "online now". This assumes the
  //         contractor-side (thekaydaar) app writes a `lastActive`
  //         Timestamp to `users/{uid}` periodically (e.g. every 60s
  //         while the app is foregrounded, or at minimum on login/
  //         resume). If that heartbeat isn't wired up yet on that
  //         side, this list will just come back empty — ping me and
  //         I'll help add the heartbeat write there too.
  static const _onlineWindow = Duration(minutes: 5);

Stream<QuerySnapshot> get _contractorStream {
  final threshold = DateTime.now().subtract(_onlineWindow);
  Query q = FirebaseFirestore.instance
      .collection('thekaydaars')
      .where('role', isEqualTo: 'Contractor')
      .where('lastActive', isGreaterThan: Timestamp.fromDate(threshold));
  if (_selectedFilter != 'All') {
    q = q.where('skills', arrayContains: _selectedFilter);   // ← changed from 'skill'
  }
  return q.snapshots();
}

  Stream<QuerySnapshot> get _projectsStream => FirebaseFirestore.instance
      .collection('projects')
      .where('clientId', isEqualTo: _uid)
      .snapshots();

  String _initials(String n) {
    final t = n.trim();
    if (t.isEmpty) return 'U';
    final p = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : p[0][0].toUpperCase();
  }

  // ── FIX: avatar now shows the uploaded profilePic (Cloudinary
  //         URL) when available, falls back to initials otherwise.
  //         Avatar background stays _navy — matches the treatment
  //         used everywhere else in the app (profile screens). ──
  Widget _avatar(String n, double r, double fs, {String? profilePicUrl}) {
    final hasPic = profilePicUrl != null && profilePicUrl.trim().isNotEmpty;
    return CircleAvatar(
      radius: r,
      backgroundColor: _navy,
      backgroundImage: hasPic ? NetworkImage(profilePicUrl) : null,
      onBackgroundImageError: hasPic ? (_, _) {} : null,
      child: hasPic
          ? null
          : Text(
              _initials(n),
              style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.0,
              ),
            ),
    );
  }

void _onNavTap(int i) async {
  if (i == _selectedNavIndex) return;
  setState(() => _selectedNavIndex = i);

  if (i == 1) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContractorSearchScreen()),
    );
    if (mounted) setState(() => _selectedNavIndex = 0);
  } else if (i == 2) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientProjectsListScreen()),
    );
    if (mounted) setState(() => _selectedNavIndex = 0);
  } else if (i == 3) {
    final ok = await FeatureGate.check(context, 'canAccessChat', isContractor: false);
    if (!ok || !mounted) {
      if (mounted) setState(() => _selectedNavIndex = 0);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationsInboxScreen(
          currentUserId: _uid,
          currentUserRole: 'client',
          cloudinaryService: CloudinaryService(
            cloudName: CloudinaryConfig.cloudName,
            uploadPreset: CloudinaryConfig.uploadPreset,
          ),
        ),
      ),
    );
    if (mounted) setState(() => _selectedNavIndex = 0);
  } else if (i == 4) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientProfileScreen()),
    );
    if (mounted) setState(() => _selectedNavIndex = 0);
  }
}
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (_, uSnap) => StreamBuilder<DocumentSnapshot>(
        stream: _clientStream,
        builder: (_, cSnap) {
          final waiting =
              (uSnap.connectionState == ConnectionState.waiting &&
                  !uSnap.hasData) ||
              (cSnap.connectionState == ConnectionState.waiting &&
                  !cSnap.hasData);
          if (waiting) {
            return const Scaffold(
              backgroundColor: _bg,
              body: Center(
                child: CircularProgressIndicator(
                  color: _amber,
                  strokeWidth: 2.5,
                ),
              ),
            );
          }

          final uData = (uSnap.hasData && uSnap.data!.exists)
              ? uSnap.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};
          final cData = (cSnap.hasData && cSnap.data!.exists)
              ? cSnap.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};
          if (uData.isNotEmpty) _ensureClientDoc(uData);

          final name = _pick('fullName', cData, uData);
          final did = _pick('displayId', cData, uData);
          // ── FIX: resolve the profile picture from either doc,
          //         preferring the clients/{uid} doc if set. ────
          final profilePic = _pick('profilePic', cData, uData);

          return LanguageBuilder(
            builder: (context, t) {
              return Scaffold(
                backgroundColor: _bg,
                appBar: _appBar(name, did, profilePic),
                body: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    _heroCard({...uData, ...cData}, name, profilePic),
                    const SizedBox(height: 16),
                    _buildAiToolsCard(),
                    const SizedBox(height: 12),
                    _buildHousePlannerCard(),
                    const SizedBox(height: 24),
                    _sectionHeader(t.t('Online Contractors'), Icons.search_rounded),
                    const SizedBox(height: 10),
                    _filterRow(),
                    const SizedBox(height: 12),
                    _contractorList(),
                    const SizedBox(height: 24),
                    _sectionHeader(t.t('My Projects'), Icons.folder_open_rounded),
                    const SizedBox(height: 12),
                    _projectsList(),
                    const SizedBox(height: 100),
                  ],
                ),
                // FAB now uses amber bg + navy foreground (matches the
                // primary-button rule in the design system) instead of
                // green bg + white foreground.
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateProjectWizard()),
                  ),
                  backgroundColor: _amber,
                  foregroundColor: _navy,
                  elevation: 2,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(
                    t.t('Create Project'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                bottomNavigationBar: _bottomNav(),
              );
            },
          );
        },
      ),
    );
  }

  String _pick(String field, Map<String, dynamic> c, Map<String, dynamic> u) {
    final fc = (c[field] as String? ?? '').trim();
    return fc.isNotEmpty ? fc : (u[field] as String? ?? '').trim();
  }

  PreferredSizeWidget _appBar(String name, String did, String profilePic) => AppBar(
    backgroundColor: _navy,
    elevation: 0,
    automaticallyImplyLeading: false,
    titleSpacing: 20,
    title: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo icon chip — subtle white glass on emerald
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.home_work_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Theeka',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'ydaar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _amber,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      // Language toggle (EN/UR) — wrapped in FittedBox so the row
      // shrinks gracefully on narrow screens instead of overflowing.
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Notifications bell (unread count + dropdown)
            NotificationBell(iconColor: Colors.white),
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 12, bottom: 12),
              child: LanguageToggleChip(compact: true),
            ),
            // Display-ID chip — goldSoft bg / goldDark text
            if (did.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _amberLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _amber.withValues(alpha: 0.4)),
                ),
                child: Text(
                  did,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _amberDark,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _onNavTap(4),
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _avatar(name, 16, 12, profilePicUrl: profilePic),
              ),
            ),
          ],
        ),
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(color: _border, height: 1),
    ),
  );

  Widget _heroCard(Map<String, dynamic> data, String name, String profilePic) {
    final did = data['displayId'] as String? ?? '';
    final nic = data['nicNumber'] as String? ?? '';
    final area = data['area'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    final sub = [
      if (area.isNotEmpty) area,
      if (phone.isNotEmpty) phone,
    ].join('  •  ');
    return StreamBuilder<QuerySnapshot>(
      stream: _projectsStream,
      builder: (_, snap) {
        final total = snap.data?.docs.length ?? 0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _avatar(name, 28, 20, profilePicUrl: profilePic),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name.isNotEmpty
                                      ? name
                                      : 'Complete your profile',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: _textPri,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (did.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _bg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    did,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _textSec,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (sub.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              sub,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _textSec,
                              ),
                            ),
                          ],
                          if (nic.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'CNIC: $nic',
                              style: TextStyle(
                                fontSize: 11,
                                color: _textSec,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // ── STATUS INDICATOR: "Verified Client" ──
                          // This stays semantic success-green — it is
                          // a true status badge, not a brand element.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _successLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 14,
                                  color: _success,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Verified Client',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _success,
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
              ),
              Container(height: 1, color: _border),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _statCell('$total', 'Projects', Icons.folder_open_rounded),
                    Container(width: 1, color: _border),
                    _statCell(
                      'Active',
                      'Status',
                      Icons.check_circle_outline_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCell(String v, String l, IconData icon) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, size: 18, color: _textSec),
          const SizedBox(height: 6),
          Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPri,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: _textSec,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );

  // ── AI Agent quick-access card (prominent) ──────────────────
  Widget _buildAiToolsCard() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GestureDetector(
      onTap: () async {
        final ok = await FeatureGate.check(context, 'canUseAiTools', isContractor: false);
        if (!ok || !mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MaterialEstimatorScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0E3B2E), Color(0xFF1A5C46), Color(0xFF0E3B2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E3B2E).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // AI icon with badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Color(0xFFC9A227), size: 30),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC9A227),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AI',
                          style: TextStyle(
                            color: Color(0xFF0E3B2E),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Material Estimator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Powered by Gemini AI',
                        style: TextStyle(
                          color: Color(0xFFC9A227),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Color(0xFFC9A227), size: 18),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _aiFeatureChip(Icons.calculate_rounded, 'Quantities'),
                  const SizedBox(width: 8),
                  _aiFeatureChip(Icons.verified_rounded, 'Top Brands'),
                  const SizedBox(width: 8),
                  _aiFeatureChip(Icons.shield_rounded, 'Strength Tips'),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── AI House Planner Card ───────────────────────────────
  // Replaces the removed AI Plot Scanner. Opens the multi-step
  // Create Project wizard: info → location → plot → requirements →
  // AI-generated, editable floor plan (works fully offline via the
  // built-in rule-based planner; Gemini enhancement is optional).
  Widget _buildHousePlannerCard() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateProjectWizard()),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A5C46), Color(0xFF0E3B2E), Color(0xFF1A5C46)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E3B2E).withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.architecture_rounded,
                    color: Color(0xFFC9A227),
                    size: 28,
                  ),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A227),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: Color(0xFF0E3B2E),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI House Planner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Describe your house \u2192 Get a floor plan',
                    style: TextStyle(
                      color: Color(0xFFC9A227),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Color(0xFFC9A227), size: 18),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _aiFeatureChip(IconData icon, String label) => Expanded(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _sectionHeader(String t, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Row(
      children: [
        Icon(icon, size: 16, color: _textSec),
        const SizedBox(width: 8),
        Text(
          t.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _textSec,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );

  // Filter chips — active state now amberLight/amber/amberDark
  // (was green50/green500/green700).
  Widget _filterRow() => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filters.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final f = _filters[i];
        final active = f == _selectedFilter;
        return GestureDetector(
          onTap: () => setState(() => _selectedFilter = f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: active ? _amberLight : _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? _amber : _border),
            ),
            child: Text(
              f,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? _amberDark : _textSec,
              ),
            ),
          ),
        );
      },
    ),
  );

Widget _contractorList() => StreamBuilder<QuerySnapshot>(
  stream: _contractorStream,
  builder: (_, snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: _amber, strokeWidth: 2),
        ),
      );
    }
    if (snap.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Error: ${snap.error}',
          style: const TextStyle(color: Colors.red, fontSize: 13),
        ),
      );
    }
    final docs = snap.data?.docs ?? [];

      if (docs.isEmpty) {
        return _empty(
          Icons.wifi_off_rounded,
          'No contractors online right now.\nCheck back in a bit.',
        );
      }
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: docs.length,
        itemBuilder: (_, i) {
          final doc = docs[i];
          final d = doc.data() as Map<String, dynamic>;
          final avail = d['available'] as bool? ?? false;
          final skillsList = (d['skills'] as List?)?.map((e) => e.toString()).toList() ?? [];
          return _ContractorCard(
            contractorId: doc.id,
           name: (d['fullName'] as String? ?? '').trim(),
           skill: skillsList.isNotEmpty ? skillsList.join(' · ') : '—',   // ← changed
            area: d['area'] as String? ?? '—',
            rate: d['rate'] as String? ?? '—',
            rating: (d['rating'] ?? 0.0).toStringAsFixed(1),
            available: avail,
            status: avail ? 'Available now' : 'Busy',
            profilePic: d['profilePic'] as String? ?? '',
          );
        },
      );
    },
  );

  Widget _projectsList() => StreamBuilder<QuerySnapshot>(
    stream: _projectsStream,
    builder: (_, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: _amber, strokeWidth: 2),
          ),
        );
      }
      if (snap.hasError) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Error: ${snap.error}',
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        );
      }

      var docs = snap.data?.docs ?? [];
      docs.sort((a, b) {
        final aT = (a.data() as Map<String, dynamic>)['createdAt'];
        final bT = (b.data() as Map<String, dynamic>)['createdAt'];
        if (aT == null && bT == null) return 0;
        if (aT == null) return 1;
        if (bT == null) return -1;
        return (bT as Timestamp).compareTo(aT as Timestamp);
      });

      if (docs.isEmpty) {
        return _empty(
          Icons.construction_outlined,
          'No projects yet.\nTap + to post your first!',
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: docs.length,
        itemBuilder: (_, i) {
          final doc = docs[i];
          final d = doc.data() as Map<String, dynamic>;
          // ── FIX: pull the cover photo the client uploaded when
          //         posting the project. Prefer coverImage, then
          //         fall back to the first entry of images[]. ──
          final coverImage = d['coverImage'] as String?;
          final images = (d['images'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final projectImageUrl =
              (coverImage != null && coverImage.isNotEmpty)
                  ? coverImage
                  : ((images != null && images.isNotEmpty)
                      ? images.first
                      : null);
          return _ProjectCard(
            projectId: doc.id,
            data: d,
            title: d['title'] as String? ?? '',
            type: d['projectType'] as String? ?? '',
            area: d['area'] as String? ?? '',
            city: d['city'] as String? ?? '',
            budgetMin: d['budgetMin'] as String? ?? '0',
            budgetMax: d['budgetMax'] as String? ?? '0',
            bidsCount: (d['bids'] as List?)?.length ?? 0,
            status: d['status'] as String? ?? 'open',
            isUrgent: d['urgentRequired'] == true,
            duration: d['duration'] as String? ?? '',
            imageUrl: projectImageUrl,
            // ── NEW: passed through so the card can show
            //         "Posted X ago" Upwork-style. ──────────
            createdAt: d['createdAt'],
          );
        },
      );
    },
  );

  Widget _empty(IconData icon, String msg) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Icon(icon, color: _textSec, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            msg,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _textSec,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );

  // Bottom nav — active icon/label now amber (was green).
  Widget _bottomNav() {
    final ts = TranslationService.instance;
    final items = [
      {'icon': Icons.grid_view_rounded, 'label': ts.t('Home')},
      {'icon': Icons.search_rounded, 'label': ts.t('Search')},
      {'icon': Icons.list_alt_outlined, 'label': ts.t('Projects')},
      {'icon': Icons.chat_bubble_outline_rounded, 'label': ts.t('Messages')},
      {'icon': Icons.person_outline_rounded, 'label': ts.t('Profile')},
    ];
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == _selectedNavIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onNavTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      i == 3
                          ? NavBadgeIcon(
                              userId: _uid,
                              icon: Icon(
                                items[i]['icon'] as IconData,
                                size: 22,
                                color: active ? _amber : _textSec,
                              ),
                            )
                          : Icon(
                              items[i]['icon'] as IconData,
                              size: 22,
                              color: active ? _amber : _textSec,
                            ),
                      const SizedBox(height: 4),
                      Text(
                        items[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active ? _amber : _textSec,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PROJECT CARD
// =============================================================================
class _ProjectCard extends StatelessWidget {
  final String projectId,
      title,
      type,
      area,
      city,
      budgetMin,
      budgetMax,
      status,
      duration;
  final Map<String, dynamic> data;
  final int bidsCount;
  final bool isUrgent;
  final String? imageUrl;
  // ── NEW: Firestore Timestamp (or null) used to render
  //         "Posted X ago" the Upwork-style way. ──────────
  final dynamic createdAt;

  // "Open" is a STATUS indicator — keeps semantic success green,
  // recolored to match the design system's exact success tokens.
  static const _statusOpenBg = Color(0xFFD1FAE5);
  static const _statusOpenText = Color(0xFF10B981);
  // Budget row is a BRAND element (pricing emphasis), not a status
  // — moved from green to amber/navy to match the design system.
  static const _amberAccent = Color(0xFFC9A227);
  static const _navy = Color(0xFF0E3B2E);
  // "Urgent" badge — already amber, unchanged.
  static const _amber50 = Color(0xFFFBF6E3);
  static const _amber700 = Color(0xFFA8861D);
  // "bids" info badge — emeraldMid to stay on-brand.
  static const _blue = Color(0xFF1A5C46);
  static const _textPri = Color(0xFF0E3B2E);
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);

  const _ProjectCard({
    required this.projectId,
    required this.data,
    required this.title,
    required this.type,
    required this.area,
    required this.city,
    required this.budgetMin,
    required this.budgetMax,
    required this.bidsCount,
    required this.status,
    required this.isUrgent,
    required this.duration,
    this.imageUrl,
    this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = status == 'open';
    final hasBids = bidsCount > 0 && isOpen;
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final postedLabel = timeAgo(createdAt);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ClientProjectDetailScreen(projectId: projectId, data: data),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasBids ? _blue.withValues(alpha: 0.3) : _border,
            width: hasBids ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FIX: render the project's cover photo, OLX/Upwork
            //         style, at the top of the card. ──────────────
            if (hasImage)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: const Color(0xFFF7F5EF),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _amberAccent,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFF7F5EF),
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: _textSec,
                      size: 26,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isUrgent)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _amber50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Urgent',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _amber700,
                                  ),
                                ),
                              ),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _textPri,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              type,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textSec,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isOpen ? _statusOpenBg : _amber50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isOpen ? 'Open' : status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOpen ? _statusOpenText : _amber700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: _textSec,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$area, $city',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textSec,
                          ),
                        ),
                      ),
                      if (duration.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.schedule_outlined,
                          size: 13,
                          color: _textSec,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          duration,
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSec,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // ── NEW: Upwork-style "Posted X ago" line ──
                  if (postedLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: _textSec,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Posted $postedLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSec,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF7F5EF),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        size: 16,
                        color: _amberAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Rs ${formatPriceShort(budgetMin)} – ${formatPriceShort(budgetMax)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.gavel_outlined,
                        size: 14,
                        color: hasBids ? _blue : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$bidsCount bid${bidsCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: hasBids ? _blue : Colors.grey.shade400,
                        ),
                      ),
                      if (hasBids) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _blue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
// CONTRACTOR CARD
// =============================================================================
class _ContractorCard extends StatelessWidget {
  final String contractorId, name, skill, area, rate, rating, status;
  final bool available;
  final String profilePic;

  // Avatar chip — now amberLight/amberDark (was green) since this
  // is a decorative identity element, not a status indicator.
  static const _amberLight = Color(0xFFFBF6E3);
  static const _amberDark = Color(0xFFA8861D);
  // "Available now" — STATUS indicator, keeps semantic success green.
  static const _statusAvailBg = Color(0xFFD1FAE5);
  static const _statusAvailText = Color(0xFF10B981);
  // "Busy" — already amber, unchanged.
  static const _amber50 = Color(0xFFFBF6E3);
  static const _amber700 = Color(0xFFA8861D);
  static const _textPri = Color(0xFF0E3B2E);
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);

  const _ContractorCard({
    required this.contractorId,
    required this.name,
    required this.skill,
    required this.area,
    required this.rate,
    required this.rating,
    required this.available,
    required this.status,
    this.profilePic = '',
  });

  String get _ini {
    final t = name.trim();
    if (t.isEmpty) return 'C';
    final p = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : p[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasPic = profilePic.trim().isNotEmpty;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ThekaydaarPublicProfile(thekaydaarUid: contractorId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            // ── FIX: show contractor's real profilePic if set, plus
            //         a small green dot — this list is already
            //         filtered to online-only, so the dot is just a
            //         quick visual confirmation, not a new query. ──
 Stack(
  clipBehavior: Clip.none,
  children: [
    Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: _amberLight,
        shape: BoxShape.circle,        // ← changed from BorderRadius.circular(12)
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPic
          ? Image.network(
              profilePic,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  _ini,
                  style: const TextStyle(
                    color: _amberDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                _ini,
                style: const TextStyle(
                  color: _amberDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    ),
    Positioned(
      right: -1,
      bottom: -1,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: _statusAvailText,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    ),
  ],
),  
     
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Contractor' : name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _textPri,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$skill  ·  $area',
                  style: const TextStyle(fontSize: 12, color: _textSec),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: available ? _statusAvailBg : _amber50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: available ? _statusAvailText : _amber700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rate,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _textPri,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: Color(0xFFC9A227),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    rating,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFA8861D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}