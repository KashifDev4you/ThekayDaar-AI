// ============================================================
//  thekaydaar_public_profile.dart
//  LinkedIn-style public profile — clients view this
//  - Cover banner + overlapping avatar (LinkedIn-style header)
//  - Shows gig: title, description, price, portfolio
//  - Shows rating, completed-jobs count, and client reviews
//    (pulled from thekaydaars/{uid} + reviews collection)
//  - Shows work Experience (contractors don't have education,
//    so this replaces an "education" section)
//  - "Chat" button → opens chat (navigate to your chat screen)
//  - "Hire Now" button → creates hire request in Firestore
//  - Reads from: users/{uid} + gigs/{uid} + thekaydaars/{uid}
//
//  PRIVACY NOTE: this screen is deliberately public-facing only.
//  It shows a "verified" badge but never prints CNIC digits, phone
//  numbers, or home addresses — those stay in the client's own
//  contract/chat flow once a job is actually agreed, not on a
//  browsable public profile.
//
//  NEW FIRESTORE FIELD USED (optional, safe if missing):
//  thekaydaars/{uid}.experience = [
//    { "title": "...", "subtitle": "...", "duration": "...", "description": "..." },
//    ...
//  ]
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// NOTE: adjust this path to wherever you save time_ago.dart.
// Exports `timeAgo(dynamic)` — used for "2 days ago" on reviews.
import 'package:ali_app/utils/time_ago.dart';
import 'package:ali_app/profile_sub_pages/notifications/notification_service.dart';

class ThekaydaarPublicProfile extends StatefulWidget {
  final String thekaydaarUid; // uid of thekaydaar being viewed
  const ThekaydaarPublicProfile({super.key, required this.thekaydaarUid});

  @override
  State<ThekaydaarPublicProfile> createState() =>
      _ThekaydaarPublicProfileState();
}

class _ThekaydaarPublicProfileState extends State<ThekaydaarPublicProfile> {
  // ── Theme ──────────────────────────────────────────────────
  static const _amber = Color(0xFFC9A227);
  static const _amberDark = Color(0xFFE59A00);
  static const _amberLight = Color(0xFFFFF8E1);
  static const _green = Color(0xFF16A37F);
  static const _greenLight = Color(0xFFE6F9F3);
  static const _blue = Color(0xFF1A5C46);

  static const _border = Color(0xFFEEEEEE);
  static const _surface = Color(0xFFF7F7F7);
  static const _textPri = Color(0xFF111111);
  static const _textSec = Color(0xFF777777);

  // ── Portfolio image index ─────────────────────────────────
  int _selectedPortfolio = 0;
  bool _hiringInProgress = false;

  // ── Current client uid ────────────────────────────────────
  final String? _clientUid = FirebaseAuth.instance.currentUser?.uid;

  // ── Shared future so the app bar, body, and bottom bar all
  //    read the same snapshot instead of firing three separate
  //    reads. Index 0 = users/{uid}, 1 = gigs/{uid},
  //    2 = thekaydaars/{uid} (rating/completed-jobs source). ──
  late final Future<List<DocumentSnapshot>> _profileFuture = Future.wait([
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.thekaydaarUid)
        .get(),
    FirebaseFirestore.instance
        .collection('gigs')
        .doc(widget.thekaydaarUid)
        .get(),
    FirebaseFirestore.instance
        .collection('thekaydaars')
        .doc(widget.thekaydaarUid)
        .get(),
  ]);

  // ── Hire action ───────────────────────────────────────────
  //  Creates a hire_requests/{docId} document in Firestore
  //  Fields saved: clientUid, thekaydaarUid, gigTitle, price,
  //                status: 'pending', createdAt
  //  Admin/thekaydaar can see this in their jobs screen
  Future<void> _sendHireRequest(
    Map<String, dynamic> profile,
    Map<String, dynamic> gig,
  ) async {
    if (_clientUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _hiringInProgress = true);
    try {
      final hireRef = await FirebaseFirestore.instance
          .collection('hire_requests')
          .add({
        'clientUid': _clientUid,
        'thekaydaarUid': widget.thekaydaarUid,
        'thekaydaarName': profile['fullName'] ?? '',
        'gigTitle': gig['title'] ?? '',
        'price': gig['price'] ?? '',
        'status': 'pending', // thekaydaar accepts/declines
        'chatId': '${_clientUid}_${widget.thekaydaarUid}',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ── Notify the contractor about the hire request ────
      String clientName = 'A client';
      final clientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_clientUid)
          .get();
      final n = (clientDoc.data()?['fullName'] as String? ?? '').trim();
      if (n.isNotEmpty) clientName = n;
      await NotificationService.instance.notifyHireRequest(
        contractorUid: widget.thekaydaarUid,
        clientName: clientName,
        gigTitle: gig['title'] as String? ?? 'your gig',
        hireRequestId: hireRef.id,
      );

      setState(() => _hiringInProgress = false);
      if (mounted) _showHireSuccess(profile['fullName'] ?? 'Thekaydaar');
    } catch (e) {
      setState(() => _hiringInProgress = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Chat action ───────────────────────────────────────────
  //  Direct chat-before-hiring isn't supported yet — the real chat
  //  system only opens once a bid is accepted (see
  //  ClientProjectDetailScreen._acceptBid → ChatMetaService.createChat).
  //  This button intentionally writes nothing to Firestore, since an
  //  earlier version of this screen wrote a chat doc with an
  //  incompatible schema (clientUid/thekaydaarUid instead of
  //  clientId/contractorId, no jobId) that could break the inbox list.
  void _openChat(String thekaydaarName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Send a hire request to $thekaydaarName first — '
          'you can chat once they accept.',
        ),
        backgroundColor: _blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showHireSuccess(String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: _greenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: _green, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hire Request Sent!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$name will review your request and respond soon.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
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
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _profileFuture,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _amber),
            );
          }
          if (!snap.hasData || snap.data == null) {
            return const Center(child: Text('Profile not found'));
          }

          final usersData = snap.data![0].data() as Map<String, dynamic>? ?? {};
          final gig = snap.data![1].data() as Map<String, dynamic>? ?? {};
          final stats = snap.data![2].data() as Map<String, dynamic>? ?? {};
          // NOTE: fullName, profilePic, category, available, rate,
          // featuredListing, nicVerified, nicNumber, area all live in
          // thekaydaars/{uid} (confirmed via console), not users/{uid}.
          // Merge with thekaydaars taking priority so display fields
          // actually populate, while still falling back to users/{uid}
          // for anything only stored there.
          final profile = {...usersData, ...stats};
          final hasGig = gig.isNotEmpty && (gig['isActive'] as bool? ?? false);

          return CustomScrollView(
            slivers: [
              _buildAppBar(profile, gig, hasGig),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating / completed-jobs / success-rate stat strip
                    _ratingStatsSection(stats),

                    const SizedBox(height: 16),

                    // Gig portfolio photos
                    if (hasGig &&
                        (gig['portfolioUrls'] as List? ?? []).isNotEmpty)
                      _portfolioSection(
                        List<String>.from(gig['portfolioUrls']),
                      ),

                    // Gig details
                    if (hasGig) _gigSection(gig),

                    // Work history — completed contracts shown as a
                    // public record, so clients see previous projects,
                    // earnings volume and completion dates (confidence).
                    _workHistorySection(),

                    const SizedBox(height: 16),

                    // Skills
                    _skillsSection(
                      (stats['skills'] as List?)?.isNotEmpty == true
                          ? List<String>.from(stats['skills'])
                          : List<String>.from(profile['skills'] as List? ?? []),
                    ),

                    const SizedBox(height: 16),

                    // Experience (replaces "education" — contractors
                    // don't have degrees, they have work experience)
                    _experienceSection(stats),

                    const SizedBox(height: 16),

                    // About / Details (public-safe only)
                    _detailsSection(profile, stats),

                    const SizedBox(height: 16),

                    // Client reviews
                    _reviewsSection(),

                    const SizedBox(height: 100), // space for bottom bar
                  ],
                ),
              ),
            ],
          );
        },
      ),
      // ── Sticky bottom bar ────────────────────────────────
      bottomNavigationBar: FutureBuilder<List<DocumentSnapshot>>(
        future: _profileFuture,
        builder: (_, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          final profile = snap.data![0].data() as Map<String, dynamic>? ?? {};
          final gig = snap.data![1].data() as Map<String, dynamic>? ?? {};
          final name = profile['fullName'] as String? ?? 'Thekaydaar';

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Chat button
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => _openChat(name),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                    ),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textPri,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Hire button
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _hiringInProgress
                        ? null
                        : () => _sendHireRequest(profile, gig),
                    icon: _hiringInProgress
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.handshake_outlined, size: 16),
                    label: Text(_hiringInProgress ? 'Sending...' : 'Hire Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── LinkedIn-style Sliver App Bar: cover banner + overlapping
  //    avatar + name/headline/rate block underneath. ────────────
  Widget _buildAppBar(
    Map<String, dynamic> profile,
    Map<String, dynamic> gig,
    bool hasGig,
  ) {
    final name = profile['fullName'] as String? ?? '';
    final category = profile['category'] as String? ?? '';
    final profilePic = profile['profilePic'] as String?;
    final isOnline = profile['available'] as bool? ?? false;
    final isVerified = profile['verifiedBadge'] as bool? ?? false;
    final isFeatured = profile['featuredListing'] as bool? ?? false;
    final rate = profile['rate'] as String? ?? '';
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.only(left: 8, top: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPri, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Text(
        name.isEmpty ? 'Profile' : name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _textPri,
          letterSpacing: -0.3,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Column(
          children: [
            // ── Cover banner ─────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_amber, _amberDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    top: 52,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Avatar overlapping banner + white section below
                Positioned(
                  bottom: -44,
                  left: 20,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: (profilePic != null && profilePic.isNotEmpty)
                          ? Image.network(profilePic, fit: BoxFit.cover)
                          : Container(
                              color: _amberLight,
                              child: Center(
                                child: Text(
                                  initials.isEmpty ? '?' : initials,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: _amberDark,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            // ── Info block below banner (name / headline / rate) ──
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name.isEmpty ? '—' : name,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _textPri,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        if (isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.verified_rounded,
                              color: _blue,
                              size: 19,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Headline — LinkedIn style, plain text not a chip
                    if (category.isNotEmpty)
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _textSec,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (rate.isNotEmpty) ...[
                          const Icon(
                            Icons.payments_outlined,
                            size: 14,
                            color: _amberDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rate,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _amberDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F2ED),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFF0E3B2E,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Text(
                              '⭐ Elite',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0E3B2E),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _border, height: 1),
      ),
    );
  }

  // ── Rating / completed-jobs / success-rate stat strip.
  //    Pulled from thekaydaars/{uid} — same fields the bid card
  //    on ClientProjectDetailScreen already reads (rating,
  //    totalJobs, completionRate), so numbers stay consistent
  //    across the app. ──────────────────────────────────────
  Widget _ratingStatsSection(Map<String, dynamic> stats) {
    final rating = (stats['rating'] as num?)?.toDouble() ?? 0.0;
    final totalJobs = stats['totalJobs'] as int? ?? 0;
    final completionRate = stats['completionRate'] as String? ?? '—';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _statCell(
              Icons.star_rounded,
              rating.toStringAsFixed(1),
              'Rating',
              iconColor: _amber,
            ),
            VerticalDivider(width: 1, color: Colors.grey.shade200),
            _statCell(
              Icons.task_alt_rounded,
              '$totalJobs',
              'Jobs Completed',
              iconColor: _green,
            ),
            VerticalDivider(width: 1, color: Colors.grey.shade200),
            _statCell(
              Icons.trending_up_rounded,
              completionRate,
              'Success Rate',
              iconColor: _blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(
    IconData icon,
    String value,
    String label, {
    required Color iconColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textPri,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Portfolio section ─────────────────────────────────────
  Widget _portfolioSection(List<String> urls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 15,
                color: _textSec,
              ),
              const SizedBox(width: 6),
              const Text(
                'PORTFOLIO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _textSec,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${urls.length} photos',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
        // Main photo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(urls[_selectedPortfolio], fit: BoxFit.cover),
            ),
          ),
        ),
        // Thumbnails
        if (urls.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: urls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _selectedPortfolio = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == _selectedPortfolio
                          ? _amber
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(urls[i], fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Gig details section ───────────────────────────────────
  Widget _gigSection(Map<String, dynamic> gig) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            gig['title'] as String? ?? '',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _textPri,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _amberLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _amber),
                ),
                child: Text(
                  gig['price'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _amberDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 12),
          const Text(
            'About this service',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textPri,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            gig['description'] as String? ?? '',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Work history / previous project record ──────────────
  // Pulls this contractor's COMPLETED contracts and lists them as a
  // verifiable track record: project type, client, amount and date.
  // This is the "previous projects record" clients look for before
  // trusting someone with a big build.
  Widget _workHistorySection() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('contracts')
          .where('contractorId', isEqualTo: widget.thekaydaarUid)
          .limit(50)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }

        final completed = snap.data!.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .where((d) => d['status'] == 'completed')
            .toList()
          ..sort((a, b) {
            final ta = (a['payoutConfirmedAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            final tb = (b['payoutConfirmedAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            return tb.compareTo(ta);
          });

        if (completed.isEmpty) return const SizedBox.shrink();

        final shown = completed.take(5).toList();
        final totalEarned = completed.fold<double>(
          0,
          (sum, d) => sum + ((d['totalAmount'] as num?)?.toDouble() ?? 0),
        );

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 15,
                    color: _textSec,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'WORK HISTORY & RECORD',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _textSec,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F2ED),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${completed.length} completed',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _amberLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        size: 16, color: _amberDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total completed work value: Rs ${totalEarned.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _amberDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ...shown.map((d) => _workHistoryTile(d)),
              if (completed.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '+ ${completed.length - 5} more completed projects',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _workHistoryTile(Map<String, dynamic> d) {
    final type = d['projectType'] as String? ?? '';
    final brief = d['projectBriefDescription'] as String? ?? '';
    final title = type.isNotEmpty
        ? type
        : (brief.isNotEmpty ? brief : 'Construction Project');
    final client = d['clientName'] as String? ?? '';
    final amount = (d['totalAmount'] as num?)?.toDouble() ?? 0;
    final when = d['payoutConfirmedAt'] as Timestamp?;
    final dateStr = when != null
        ? '${when.toDate().day}/${when.toDate().month}/${when.toDate().year}'
        : '';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F2ED),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: _green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _textPri,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (client.isNotEmpty) 'Client: $client',
                    if (dateStr.isNotEmpty) dateStr,
                  ].join('  •  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Rs ${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _textPri,
            ),
          ),
        ],
      ),
    );
  }

  // ── Skills section ────────────────────────────────────────
  Widget _skillsSection(List<String> skills) {
    if (skills.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skills & Expertise',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textPri,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
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
                      color: _amberLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _amber.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _amberDark,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Experience section (LinkedIn-style) ───────────────────
  //    Replaces "education" — thekaydaars typically don't hold
  //    degrees, so this shows their work history instead.
  //    Reads thekaydaars/{uid}.experience — a List<Map> with
  //    keys: title, subtitle, duration, description. All keys
  //    are optional; entries missing everything are skipped.
  //    If the field is absent entirely, shows a friendly empty
  //    state instead of breaking. ─────────────────────────────
  Widget _experienceSection(Map<String, dynamic> stats) {
    final rawList = stats['experience'] as List? ?? [];
    final entries = rawList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(
          (e) =>
              (e['title'] as String? ?? '').trim().isNotEmpty ||
              (e['description'] as String? ?? '').trim().isNotEmpty,
        )
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work_history_outlined, size: 16, color: _textSec),
              const SizedBox(width: 8),
              const Text(
                'Experience',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPri,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              'No experience added yet.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            )
          else
            Column(
              children: List.generate(entries.length, (i) {
                final e = entries[i];
                final isLast = i == entries.length - 1;
                return _experienceTile(
                  title: e['title'] as String? ?? '',
                  subtitle: e['subtitle'] as String? ?? '',
                  duration: e['duration'] as String? ?? '',
                  description: e['description'] as String? ?? '',
                  showConnector: !isLast,
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _experienceTile({
    required String title,
    required String subtitle,
    required String duration,
    required String description,
    required bool showConnector,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: showConnector ? 16 : 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline dot + connecting line — LinkedIn-style
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: _amber,
                    shape: BoxShape.circle,
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: _border,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
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
                  if (subtitle.isNotEmpty || duration.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
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
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile details section — PUBLIC-SAFE ONLY.
  //    No CNIC digits, no phone number, no home address. Just a
  //    location string (area/city — already public elsewhere in
  //    the app) and a clean verified badge with zero digits shown. ──
  Widget _detailsSection(
    Map<String, dynamic> profile,
    Map<String, dynamic> stats,
  ) {
    final location = (profile['location'] as String?)?.trim().isNotEmpty == true
        ? profile['location'] as String
        : (stats['area'] as String? ?? '');
    final isVerified = ((profile['nicNumber'] as String?)?.isNotEmpty ??
            false) ||
        ((stats['nicNumber'] as String?)?.isNotEmpty ?? false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textPri,
            ),
          ),
          const SizedBox(height: 12),
          if (location.isNotEmpty)
            _detailRow(Icons.location_on_outlined, 'Location', location),
          // CNIC itself is never shown here — just whether identity
          // has been verified by the platform.
          if (isVerified)
            _detailRow(
              Icons.verified_user_outlined,
              'Identity',
              'Verified by Thekaydaar',
            ),
          _detailRow(
            Icons.shield_outlined,
            'Platform',
            'Thekaydaar verified member',
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _textSec),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _textPri,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Client reviews section.
  //    CONFIRMED against actual `reviews` collection schema (checked
  //    in Firestore console): a review doc looks like —
  //      contractId, createdAt, direction ("client_to_contractor" /
  //      "contractor_to_client"), overallRating, projectId,
  //      rating1/2/3, reviewText, revieweeId, revieweeName,
  //      reviewerId, reviewerName.
  //    So for THIS contractor's public profile we want docs where
  //    `revieweeId == thekaydaarUid` (they were the one reviewed) AND
  //    `direction == 'client_to_contractor'` (so a contractor's own
  //    reviews of clients don't leak onto their public page). ──────
  Widget _reviewsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client Reviews',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textPri,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reviews')
                .where('revieweeId', isEqualTo: widget.thekaydaarUid)
                .where('direction', isEqualTo: 'client_to_contractor')
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _amber,
                      ),
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                // This query needs a composite index on
                // (revieweeId ASC, direction ASC, createdAt DESC).
                // Print the error so the Firestore auto-index link
                // shows up in the debug console the first time this
                // runs — click that link once and it's fixed forever.
                debugPrint('Reviews query error: ${snap.error}');
                return Text(
                  'Reviews unavailable right now.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text(
                  'No reviews yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final r = doc.data() as Map<String, dynamic>;
                  return _reviewTile(r);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _reviewTile(Map<String, dynamic> r) {
    final clientName = r['reviewerName'] as String? ?? 'Client';
    final rating = (r['overallRating'] as num?)?.toDouble() ?? 0.0;
    final comment = r['reviewText'] as String? ?? '';
    final posted = timeAgo(r['createdAt']);
    final initial = clientName.trim().isNotEmpty
        ? clientName.trim()[0].toUpperCase()
        : 'C';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _amberLight,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _amberDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  clientName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _textPri,
                  ),
                ),
              ),
              if (posted.isNotEmpty)
                Text(
                  posted,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14,
                color: _amber,
              );
            }),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              comment,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}