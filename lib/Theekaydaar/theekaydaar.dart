import 'package:ali_app/Theekaydaar/thekaydaar_profile.dart';
import 'package:ali_app/Theekaydaar/browse_projects_screen.dart';
import 'package:ali_app/ui/material_estimator_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ali_app/Theekaydaar/thekaydaar_active_jobs.dart';
import 'package:ali_app/MessageAndNotification/conversations_inbox_screen.dart';
import 'package:ali_app/MessageAndNotification/cloudinary_service.dart';
import 'package:ali_app/MessageAndNotification/cloudinary_config.dart';
import 'package:ali_app/MessageAndNotification/new_badge_icon.dart';
import 'package:ali_app/services/presence_service.dart'; // apna actual path lagao
import 'package:ali_app/Widgets/language_toggle_widget.dart';
import 'package:ali_app/utils/feature_gate.dart';
import 'package:ali_app/profile_sub_pages/notifications/notification_bell.dart';
import 'package:ali_app/services/translation_service.dart';

class Thekaydaar extends StatefulWidget {
  const Thekaydaar({super.key});

  @override
  State<Thekaydaar> createState() => _ThekaydaarState();
}

class _ThekaydaarState extends State<Thekaydaar> {
  int _selectedNavIndex = 0;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isCheckingDoc = true;

  // ── NEW: search + category state ──────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;

  static const _bg = Color(0xFFF7F5EF);
  static const _surface = Colors.white;
  static const _green50 = Color(0xFFE7F2ED);
  static const _green500 = Color(0xFF0E3B2E);
  static const _green700 = Color(0xFF1A5C46);
  static const _amber500 = Color(0xFFC9A227);
  static const _textPri = Color(0xFF0E3B2E);
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);

  // ── NEW: quick category chips (tap → Browse Projects) ────────
  static const List<Map<String, dynamic>> _categories = [
    {'label': 'Plumbing', 'icon': Icons.plumbing_rounded},
    {'label': 'Electrical', 'icon': Icons.electrical_services_rounded},
    {'label': 'Painting', 'icon': Icons.format_paint_rounded},
    {'label': 'Carpentry', 'icon': Icons.carpenter_rounded},
    {'label': 'Cleaning', 'icon': Icons.cleaning_services_rounded},
    {'label': 'Construction', 'icon': Icons.construction_rounded},
  ];

  @override
  void initState() {
    super.initState();
    // Start writing lastActive heartbeats to Firestore (thekaydaars
    // collection) so clients can see this contractor in the
    // "Online Contractors" list.
    PresenceService.instance.start();
    _initializeProfile();
  }

  @override
  void dispose() {
    PresenceService.instance.stop();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeProfile() async {
    if (_uid.isEmpty) {
      setState(() => _isCheckingDoc = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        final profileRef = FirebaseFirestore.instance
            .collection('thekaydaars')
            .doc(_uid);
        final profileSnap = await profileRef.get();

        if (!profileSnap.exists) {
          // First time ever — safe to write everything, even blanks,
          // since there's nothing to overwrite yet.
          await profileRef.set({
            'uid': _uid,
            'fullName': userData['fullName'] ?? '',
            'nicNumber': userData['nicNumber'] ?? '',
            'displayId': userData['displayId'] ?? '',
            'city': userData['city'] ?? '',
            'area': userData['area'] ?? '',
            'assignedArea': userData['assignedArea'] ?? '',
            'role': 'thekaydaar',
            'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
            'skill': '',
            'rate': '',
            'rating': 0.0,
            'totalJobs': 0,
            'activeJobs': 0,
            'monthlyEarnings': 'Rs 0',
            'completionRate': '0%',
            'available': true,
            'skills': <String>[],
            'busyUntil': '',
            'profilePic': userData['profilePic'] ?? '',
          }, SetOptions(merge: true));
        } else {
          // ── FIX (data-loss bug): the old code did
          //   `fullName: userData['fullName'] ?? ''`
          // which writes '' whenever users/{uid} doesn't have that
          // field — and it ran on EVERY app open, silently wiping
          // fullName/nicNumber/displayId/city/etc in `thekaydaars`
          // each time. Now we only sync a field if users/{uid} has
          // a real non-empty value for it. Nothing here can ever
          // blank out existing thekaydaars data again.
          final Map<String, dynamic> syncFields = {};
          void addIfNotEmpty(String key, dynamic value) {
            if (value is String && value.trim().isNotEmpty) {
              syncFields[key] = value;
            }
          }

          addIfNotEmpty('fullName', userData['fullName']);
          addIfNotEmpty('nicNumber', userData['nicNumber']);
          addIfNotEmpty('displayId', userData['displayId']);
          addIfNotEmpty('city', userData['city']);
          addIfNotEmpty('area', userData['area']);
          addIfNotEmpty('assignedArea', userData['assignedArea']);

          if (syncFields.isNotEmpty) {
            await profileRef.update(syncFields);
          }
        }
      }
    } catch (e) {
      debugPrint('Error initializing thekaydaar profile: $e');
    } finally {
      if (mounted) setState(() => _isCheckingDoc = false);
    }
  }

  // ── Streams ──────────────────────────────────────────────────
  Stream<DocumentSnapshot> get _profileStream => FirebaseFirestore.instance
      .collection('thekaydaars')
      .doc(_uid)
      .snapshots();

  // ── FIX: removed orderBy to avoid composite index error ──────
  Stream<QuerySnapshot> get _jobRequestsStream => FirebaseFirestore.instance
      .collection('jobRequests')
      .where('thekaydaarId', isEqualTo: _uid)
      .where('status', isEqualTo: 'pending')
      .snapshots();

  // ── NEW: open marketplace projects, used for the Featured
  //         carousel below. Adjust collection/field names to
  //         match your actual schema if different. ─────────────
  Stream<QuerySnapshot> get _openProjectsStream => FirebaseFirestore.instance
      .collection('projects')
      .where('status', isEqualTo: 'open')
      .snapshots();

  // ── Actions ──────────────────────────────────────────────────
  Future<void> _updateJobStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('jobRequests')
        .doc(docId)
        .update({'status': newStatus});
    if (newStatus == 'accepted') {
      await FirebaseFirestore.instance
          .collection('thekaydaars')
          .doc(_uid)
          .update({'activeJobs': FieldValue.increment(1)});
    }
  }

  Future<void> _toggleOnline(bool current) async {
    await FirebaseFirestore.instance.collection('thekaydaars').doc(_uid).update(
      {'available': !current},
    );
  }

  // ── Helpers ──────────────────────────────────────────────────
  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final result = parts
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return result.isEmpty ? '?' : result;
  }

  // ── FIX: avatar now shows the uploaded profilePic (Cloudinary URL)
  //         when available, falls back to initials otherwise. ─────
  Widget _avatar(
    String fullName,
    double radius,
    double fontSize, {
    String? profilePicUrl,
  }) {
    final hasPic = profilePicUrl != null && profilePicUrl.trim().isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: _green500,
      backgroundImage: hasPic ? NetworkImage(profilePicUrl) : null,
      onBackgroundImageError: hasPic ? (_, _) {} : null,
      child: hasPic
          ? null
          : Text(
              _initials(fullName),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.0,
              ),
            ),
    );
  }

  void _onNavTap(int index) async {
    if (index == _selectedNavIndex) return;

    // Tab 1 = Browse Projects — navigate to screen
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BrowseProjectsScreen()),
      );
      return;
    }
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ThekaydaarActiveJobsScreen()),
      );
      return;
    }
    if (index == 3) {
      final ok = await FeatureGate.check(context, 'canAccessChat', isContractor: true);
      if (!ok || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationsInboxScreen(
            currentUserId: _uid,
            currentUserRole: 'contractor',
            cloudinaryService: CloudinaryService(
              cloudName: CloudinaryConfig.cloudName,
              uploadPreset: CloudinaryConfig.uploadPreset,
            ),
          ),
        ),
      );
      return;
    }
    // Tab 4 = Profile
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ThekaydaarProfileScreen()),
      );
      return;
    }

    setState(() => _selectedNavIndex = index);
  }

  // ── UPDATED: now supports passing a category / search query
  //             through to BrowseProjectsScreen. If your
  //             BrowseProjectsScreen constructor doesn't yet have
  //             `initialCategory` / `initialSearchQuery`, add them
  //             there (see note in chat) or this call won't compile. ─
  void _goToBrowse({String? category, String? searchQuery}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrowseProjectsScreen(
          initialCategory: category,
          initialSearchQuery: searchQuery,
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isCheckingDoc) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _green500, strokeWidth: 2.5),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _profileStream,
      builder: (context, profileSnap) {
        if (profileSnap.hasError) {
          return Scaffold(
            backgroundColor: _bg,
            body: Center(
              child: Text(
                'Error: ${profileSnap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!profileSnap.hasData || !profileSnap.data!.exists) {
          return const Scaffold(
            backgroundColor: _bg,
            body: Center(
              child: CircularProgressIndicator(
                color: _green500,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        final profile = profileSnap.data!.data() as Map<String, dynamic>;
        final fullName = profile['fullName'] as String? ?? '';
        final displayId = profile['displayId'] as String? ?? '';
        final nicNumber = profile['nicNumber'] as String? ?? '';
        final skill = profile['skill'] as String? ?? '';
        final area = profile['area'] as String? ?? '';
        final rating = (profile['rating'] ?? 0.0).toStringAsFixed(1);
        final totalJobs = (profile['totalJobs'] ?? 0).toString();
        final monthly = profile['monthlyEarnings'] as String? ?? 'Rs 0';
        final activeJobs = (profile['activeJobs'] ?? 0).toString();
        final completion = profile['completionRate'] as String? ?? '0%';
        final isOnline = profile['available'] as bool? ?? true;
        final skills = List<String>.from(profile['skills'] as List? ?? []);
        // ── FIX: read the actual Cloudinary profile picture URL ──
        final profilePic = profile['profilePic'] as String? ?? '';

        return LanguageBuilder(
          builder: (context, t) {
            return Scaffold(
              backgroundColor: _bg,
              appBar: _buildAppBar(
                fullName: fullName,
                displayId: displayId,
                isOnline: isOnline,
                profilePic: profilePic,
              ),
              body: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _buildHeroCard(
                    fullName: fullName,
                    nicNumber: nicNumber,
                    displayId: displayId,
                    skill: skill,
                    area: area,
                    rating: rating,
                    totalJobs: totalJobs,
                    monthly: monthly,
                    activeJobs: activeJobs,
                    completion: completion,
                    profilePic: profilePic,
                  ),
                  const SizedBox(height: 16),

                  // ── NEW: OLX-style discovery row ──────────────────
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildCategoryChips(),
                  const SizedBox(height: 20),
                  _buildFeaturedProjectsSection(),
                  const SizedBox(height: 16),
                  _buildNearbyTeaser(area),
                  const SizedBox(height: 16),
                  // ───────────────────────────────────────────────────

                  // Browse Projects Banner
                  _buildBrowseBanner(),
                  const SizedBox(height: 12),
                  _buildAiEstimatorCard(),
                  const SizedBox(height: 24),

                  _buildSectionHeader(
                    t.t('Incoming Requests'),
                    Icons.assignment_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildJobRequestsList(),
                  const SizedBox(height: 24),
                  _buildSkillsSection(skills),
                  const SizedBox(height: 100),
                ],
              ),
              bottomNavigationBar: _buildBottomNav(),
            );
          },
        );
      },
    );
  }

  // ── NEW: Search bar (OLX-style, now actually functional) ──────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20, color: _textSec),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search projects by skill, area, or keyword',
                  hintStyle: TextStyle(fontSize: 13, color: _textSec),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13, color: _textPri),
                onSubmitted: (value) {
                  final q = value.trim();
                  if (q.isNotEmpty) _goToBrowse(searchQuery: q);
                },
              ),
            ),
            GestureDetector(
              onTap: () {
                final q = _searchController.text.trim();
                if (q.isNotEmpty) {
                  _goToBrowse(searchQuery: q);
                } else {
                  _goToBrowse();
                }
              },
              child: const Icon(Icons.tune_rounded, size: 18, color: _green500),
            ),
          ],
        ),
      ),
    );
  }

  // ── NEW: Skill-category quick filters (now selects + filters) ──
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final label = cat['label'] as String;
          final isSelected = _selectedCategory == label;
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = label);
                _goToBrowse(category: label);
              },
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isSelected ? _green500 : _green50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      cat['icon'] as IconData,
                      color: isSelected ? Colors.white : _green500,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? _green700 : _textPri,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── NEW: Featured / promoted projects carousel ─────────────────
  Widget _buildFeaturedProjectsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _openProjectsStream,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        var docs = snap.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['featured'] == true;
        }).toList();

        docs.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['postedAt'];
          final bTs = (b.data() as Map<String, dynamic>)['postedAt'];
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });

        if (docs.length > 6) docs = docs.sublist(0, 6);
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Featured Projects',
              Icons.local_fire_department_rounded,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;

                  // ── FIX: pull the actual photo the client uploaded
                  //         in Post Project. Prefer coverImage, then
                  //         fall back to the first entry of images[].
                  final coverImage = d['coverImage'] as String?;
                  final images = (d['images'] as List?)
                      ?.map((e) => e.toString())
                      .toList();
                  final imageUrl = (coverImage != null && coverImage.isNotEmpty)
                      ? coverImage
                      : ((images != null && images.isNotEmpty)
                          ? images.first
                          : null);

                  return _FeaturedProjectCard(
                    title: d['title'] as String? ?? '',
                    area: d['area'] as String? ?? '',
                    price:
                        d['price'] as String? ?? d['budget'] as String? ?? '',
                    imageUrl: imageUrl,
                    onTap: _goToBrowse,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── NEW: "new projects near you" teaser ─────────────────────────
  Widget _buildNearbyTeaser(String area) {
    if (area.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('status', isEqualTo: 'open')
          .where('area', isEqualTo: area)
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: _goToBrowse,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _amber500.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _amber500.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _amber500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: _amber500,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count new ${count == 1 ? "project" : "projects"} in $area',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textPri,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to view and place a bid',
                        style: TextStyle(fontSize: 11, color: _textSec),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _textSec,
                  size: 14,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Browse Projects Banner ───────────────────────────────────
  Widget _buildBrowseBanner() {
    return GestureDetector(
      onTap: _goToBrowse,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0E3B2E), Color(0xFF1A5C46)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse Open Projects',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Find jobs in your area and place bids',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Material Estimator Card (prominent) ─────────────────
  Widget _buildAiEstimatorCard() {
    return GestureDetector(
      onTap: () async {
        final ok = await FeatureGate.check(context, 'canUseMaterialEstimator', isContractor: true);
        if (!ok || !mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MaterialEstimatorScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
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
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFC9A227),
                        size: 30,
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
    );
  }

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

  // ── AppBar ───────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar({
    required String fullName,
    required String displayId,
    required bool isOnline,
    required String profilePic,
  }) {
    return AppBar(
      backgroundColor: _green500,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.construction_rounded,
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
                      color: Color(0xFFC9A227),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _toggleOnline(isOnline),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFFE7F2ED) : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isOnline
                          ? const Color(0xFFC9A227).withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFFC9A227) : Colors.white70,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnline ? 'Active' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOnline ? const Color(0xFF0E3B2E) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Notifications bell (unread count + dropdown)
              NotificationBell(iconColor: Colors.white),
              // Language toggle for contractors (EN/UR)
              Padding(
                padding: const EdgeInsets.only(right: 4, top: 12, bottom: 12),
                child: LanguageToggleChip(compact: true),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _onNavTap(4),
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _avatar(fullName, 16, 12, profilePicUrl: profilePic),
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
  }

  // ── Hero Card ────────────────────────────────────────────────
  Widget _buildHeroCard({
    required String fullName,
    required String nicNumber,
    required String displayId,
    required String skill,
    required String area,
    required String rating,
    required String totalJobs,
    required String monthly,
    required String activeJobs,
    required String completion,
    required String profilePic,
  }) {
    final subtext = [skill, area].where((s) => s.isNotEmpty).join('  •  ');

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
                _avatar(fullName, 28, 20, profilePicUrl: profilePic),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fullName.isEmpty
                                  ? 'Verified Contractor'
                                  : fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _textPri,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (displayId.isNotEmpty)
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
                                displayId,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _textSec,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (subtext.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtext,
                          style: const TextStyle(fontSize: 13, color: _textSec),
                        ),
                      ],
                      if (nicNumber.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'CNIC: $nicNumber',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _textSec,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _green50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: _amber500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$rating  ·  $totalJobs Orders',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _green700,
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
                _buildStatCell(
                  monthly,
                  'Revenue',
                  Icons.account_balance_wallet_outlined,
                ),
                Container(width: 1, color: _border),
                _buildStatCell(
                  activeJobs,
                  'Live Jobs',
                  Icons.folder_open_rounded,
                ),
                Container(width: 1, color: _border),
                _buildStatCell(completion, 'Success', Icons.analytics_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell(String value, String label, IconData icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, size: 18, color: _textSec),
            const SizedBox(height: 6),
            Text(
              value,
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
              label,
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
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _textSec),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
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
  }

  // ── Job Requests ─────────────────────────────────────────────
  Widget _buildJobRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _jobRequestsStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Error loading requests: ${snap.error}',
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: _green500,
                strokeWidth: 2,
              ),
            ),
          );
        }

        var docs = snap.data?.docs ?? [];

        // Sort client-side
        docs.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['createdAt'];
          final bTs = (b.data() as Map<String, dynamic>)['createdAt'];
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });

        if (docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: _textSec, size: 20),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Queue clear',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPri,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'No pending requests right now.',
                        style: TextStyle(fontSize: 12, color: _textSec),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, idx) {
            final d = docs[idx].data() as Map<String, dynamic>;
            return _JobCard(
              docId: docs[idx].id,
              title: d['title'] as String? ?? '',
              clientName: d['clientName'] as String? ?? '',
              area: d['area'] as String? ?? '',
              description: d['description'] as String? ?? '',
              price: d['price'] as String? ?? '',
              badgeLabel: d['badgeLabel'] as String? ?? 'New',
              onAccept: () => _updateJobStatus(docs[idx].id, 'accepted'),
              onDecline: () => _updateJobStatus(docs[idx].id, 'declined'),
            );
          },
        );
      },
    );
  }

  // ── Skills Section ───────────────────────────────────────────
  Widget _buildSkillsSection(List<String> skills) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: _green500),
                SizedBox(width: 8),
                Text(
                  'Verified Competencies',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPri,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            skills.isEmpty
                ? const Text(
                    'No skills added yet.',
                    style: TextStyle(fontSize: 12, color: _textSec),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skills
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _border),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _textPri,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Nav ───────────────────────────────────────────────
  Widget _buildBottomNav() {
    final ts = TranslationService.instance;
    final items = [
      {'icon': Icons.grid_view_rounded, 'label': ts.t('Overview')},
      {'icon': Icons.search_rounded, 'label': ts.t('Browse')},
      {'icon': Icons.account_balance_wallet_outlined, 'label': ts.t('Earnings')},
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
                                color: active ? _amber500 : _textSec,
                              ),
                            )
                          : Icon(
                              items[i]['icon'] as IconData,
                              size: 22,
                              color: active ? _amber500 : _textSec,
                            ),
                      const SizedBox(height: 4),
                      Text(
                        items[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active ? _amber500 : _textSec,
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
// JOB CARD
// =============================================================================
class _JobCard extends StatelessWidget {
  final String docId, title, clientName, area, description, price, badgeLabel;
  final VoidCallback onAccept, onDecline;

  static const _bg = Color(0xFFF7F5EF);
  static const _surface = Colors.white;
  static const _green50 = Color(0xFFE7F2ED);
  static const _green500 = Color(0xFF0E3B2E);
  static const _green700 = Color(0xFF1A5C46);
  static const _amber50 = Color(0xFFFBF6E3);
  static const _amber700 = Color(0xFFA8861D);
  static const _textPri = Color(0xFF0E3B2E);
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);

  const _JobCard({
    required this.docId,
    required this.title,
    required this.clientName,
    required this.area,
    required this.description,
    required this.price,
    required this.badgeLabel,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final isNew = badgeLabel.toLowerCase() == 'new';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textPri,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            // ── FIX: don't show a bare "· area" when
                            //         clientName is missing/empty ────
                            [clientName, area]
                                .where((s) => s.trim().isNotEmpty)
                                .join('  ·  ')
                                .isEmpty
                                ? 'Client'
                                : [clientName, area]
                                    .where((s) => s.trim().isNotEmpty)
                                    .join('  ·  '),
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
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isNew ? _green50 : _amber50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isNew ? _green700 : _amber700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textSec,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 16,
                      color: _green500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _amber700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _surface,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 13,
                        color: _textPri,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green500,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FEATURED PROJECT CARD (OLX-style promoted listing card)
// =============================================================================
class _FeaturedProjectCard extends StatelessWidget {
  final String title, area, price;
  final String? imageUrl;
  final VoidCallback onTap;

  static const _surface = Colors.white;
  static const _amber50 = Color(0xFFFBF6E3);
  static const _amber700 = Color(0xFFA8861D);
  static const _textPri = Color(0xFF0E3B2E);
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _green50 = Color(0xFFE7F2ED);
  static const _green500 = Color(0xFF0E3B2E);

  const _FeaturedProjectCard({
    required this.title,
    required this.area,
    required this.price,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FIX: actually render the project's cover photo ──
            SizedBox(
              height: 80,
              width: double.infinity,
              child: hasImage
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: _green50,
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _green500,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: _green50,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: _green500,
                          size: 22,
                        ),
                      ),
                    )
                  : Container(
                      color: _green50,
                      child: const Icon(
                        Icons.construction_rounded,
                        color: _green500,
                        size: 22,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _amber50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FEATURED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _amber700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textPri,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: _textSec,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          area,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _textSec),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _amber700,
                    ),
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