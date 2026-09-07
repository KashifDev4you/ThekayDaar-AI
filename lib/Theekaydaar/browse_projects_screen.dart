import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:ali_app/utils/app_theme.dart';
import 'package:ali_app/profile_sub_pages/notifications/notification_service.dart';
import 'package:ali_app/house_planner/screens/blueprint_view_screen.dart';
import 'package:ali_app/house_planner/services/house_plan_service.dart';
import 'package:ali_app/house_planner/widgets/blueprint_painter.dart';

class BrowseProjectsScreen extends StatefulWidget {
  // ── NEW: optional deep-link params from Thekaydaar dashboard's
  //         search bar / category chips. ─────────────────────────
  final String? initialCategory;
  final String? initialSearchQuery;

  const BrowseProjectsScreen({
    super.key,
    this.initialCategory,
    this.initialSearchQuery,
  });

  @override
  State<BrowseProjectsScreen> createState() => _BrowseProjectsScreenState();
}

class _BrowseProjectsScreenState extends State<BrowseProjectsScreen> {
  late String _selectedFilter;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  bool _canBid = false;
  int _bidsRemaining = 0;
  String _planName = 'Free';
  bool _checkingPlan = true;
  String _blockReason = '';
  String? _contractorCity;

  // ── UPDATED: added 'Cleaning' and 'Construction' so category
  //             chips from the Thekaydaar dashboard always match
  //             a real filter here (they didn't before). ─────────
  static const _filters = [
    'All',
    'New Construction',
    'Renovation',
    'Plumbing',
    'Electrical',
    'Painting',
    'Carpentry',
    'Cleaning',
    'Construction',
  ];
  static const _amber = AppTheme.gold;

  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFDC2626);

  static const _label = AppTheme.textBody;

  @override
  void initState() {
    super.initState();
    // ── NEW: seed filter + search box from whatever the dashboard
    //         passed in. ────────────────────────────────────────
    final cat = widget.initialCategory?.trim();
    _selectedFilter = (cat != null && cat.isNotEmpty) ? cat : 'All';

    final q = widget.initialSearchQuery?.trim() ?? '';
    _searchCtrl.text = q;
    _searchQuery = q.toLowerCase();

    _checkTkPlan();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkTkPlan() async {
    setState(() => _checkingPlan = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        setState(() {
          _canBid = false;
          _blockReason = 'You must be logged in.';
          _checkingPlan = false;
        });
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('thekaydaars')
          .doc(uid)
          .get();
      if (!doc.exists) {
        setState(() {
          _canBid = false;
          _blockReason = 'Profile not found. Please complete your profile.';
          _checkingPlan = false;
        });
        return;
      }
      final data = doc.data()!;

      // ── capture contractor's city so the feed can be filtered ──
      // _checkTkPlan() mein, contractorCity capture karte waqt:
      final contractorCity = (data['city'] as String?)?.trim();

      // Agar city missing hai to bidding hi allow mat karo, city select karwao pehle
      if (contractorCity == null || contractorCity.isEmpty) {
        setState(() {
          _canBid = false;
          _blockReason =
              'Please set your city in your profile before browsing projects.';
          _checkingPlan = false;
        });
        return;
      }

      final canBid = data['canBid'] as bool? ?? false;
      final bidsRemaining = data['bidsRemaining'] as int? ?? 0;
      final planName = data['planName'] as String? ?? 'Free';
      setState(() {
        _planName = planName;
        _bidsRemaining = bidsRemaining;
        _contractorCity = contractorCity;
      });

      if (planName == 'Free' || !canBid) {
        setState(() {
          _canBid = false;
          _blockReason =
              'Your Free plan does not include bidding.\n\nUpgrade to Pro (10 bids/month) or Elite (15 bids/month) to start bidding on projects.';
          _checkingPlan = false;
        });
        return;
      }
      if (bidsRemaining <= 0) {
        setState(() {
          _canBid = false;
          _blockReason =
              'You have used all your bids for this month on your $_planName plan.\n\nUpgrade to Elite for more bids, or wait for next month\'s reset.';
          _checkingPlan = false;
        });
        return;
      }
      setState(() {
        _canBid = true;
        _checkingPlan = false;
      });
    } catch (e) {
      setState(() {
        _canBid = false;
        _blockReason = 'Error checking your plan: $e';
        _checkingPlan = false;
      });
    }
  }

  Stream<QuerySnapshot> get _projectsStream {
    Query q = FirebaseFirestore.instance
        .collection('projects')
        .where('status', isEqualTo: 'open');

    if (_contractorCity != null && _contractorCity!.isNotEmpty) {
      q = q.where('city', isEqualTo: _contractorCity);
    }
    if (_selectedFilter != 'All') {
      q = q.where('projectType', isEqualTo: _selectedFilter);
    }
    return q.snapshots();
  }

  // ── NEW: client-side text match — Firestore doesn't support
  //         substring search out of the box, so this filters
  //         whatever the stream already returned. ─────────────
  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;
    final haystack = [
      data['title'],
      data['description'],
      data['projectType'],
      data['area'],
      data['city'],
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _label),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Browse Projects',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _label,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      // SafeArea bottom — keeps the project list clear of the gesture
      // bar / home indicator (top is handled by the AppBar).
      body: _checkingPlan
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : SafeArea(
              top: false,
              child: Column(
              children: [
                _planBanner(),
                if (_contractorCity != null && _contractorCity!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Showing projects in $_contractorCity',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                _searchBar(),
                _filterRow(),
                Expanded(child: _projectList()),
              ],
            ),
            ),
    );
  }

  // ── NEW: search box at top of Browse, seeded from the dashboard
  //         and editable here too. ─────────────────────────────
  Widget _searchBar() => Container(
    width: double.infinity,
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by skill, area, or keyword',
                hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() {
                _searchCtrl.clear();
                _searchQuery = '';
              }),
              child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade500),
            ),
        ],
      ),
    ),
  );

  Widget _planBanner() {
    if (!_canBid) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: _red.withValues(alpha: 0.08),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_rounded, color: _red, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _blockReason.isNotEmpty
                    ? _blockReason
                    : _planName == 'Free'
                        ? 'Free plan — Upgrade to Pro or Elite to bid on projects'
                        : 'No bids remaining this month — Upgrade to Elite for more',
                style: const TextStyle(
                  fontSize: 12,
                  color: _red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _green.withValues(alpha: 0.07),
      child: Row(
        children: [
          const Icon(Icons.gavel_rounded, color: _green, size: 16),
          const SizedBox(width: 8),
          Text(
            '$_planName Plan — $_bidsRemaining bid${_bidsRemaining == 1 ? '' : 's'} remaining this month',
            style: const TextStyle(
              fontSize: 12,
              color: _green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow() => Container(
    color: Colors.white,
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              color: active ? const Color(0xFFE1F5EE) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? const Color(0xFF5DCAA5) : Colors.grey.shade300,
              ),
            ),
            child: Text(
              f,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? const Color(0xFF0F6E56) : Colors.grey.shade600,
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _projectList() => StreamBuilder<QuerySnapshot>(
    stream: _projectsStream,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.emerald),
        );
      }
      if (snap.hasError) {
        return Center(
          child: Text(
            'Error: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          ),
        );
      }
      var docs = snap.data?.docs ?? [];

      // ── NEW: apply client-side search filter on top of the
      //         Firestore city/category filters. ───────────────
      if (_searchQuery.isNotEmpty) {
        docs = docs
            .where((d) => _matchesSearch(d.data() as Map<String, dynamic>))
            .toList();
      }

      docs.sort((a, b) {
        final aT = (a.data() as Map<String, dynamic>)['createdAt'];
        final bT = (b.data() as Map<String, dynamic>)['createdAt'];
        if (aT == null && bT == null) return 0;
        if (aT == null) return 1;
        if (bT == null) return -1;
        return (bT as Timestamp).compareTo(aT as Timestamp);
      });
      if (docs.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 52,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No projects match "$_searchQuery"'
                    : 'No open projects right now',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
              ),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final doc = docs[i];
          final data = doc.data() as Map<String, dynamic>;
          return _ProjectCard(
            projectId: doc.id,
            data: data,
            canBid: _canBid,
            bidsRemaining: _bidsRemaining,
            planName: _planName,
            onBidSuccess: _checkTkPlan,
          );
        },
      );
    },
  );
}

class _ProjectCard extends StatelessWidget {
  final String projectId, planName;
  final Map<String, dynamic> data;
  final bool canBid;
  final int bidsRemaining;
  final VoidCallback onBidSuccess;

  const _ProjectCard({
    required this.projectId,
    required this.data,
    required this.canBid,
    required this.bidsRemaining,
    required this.planName,
    required this.onBidSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final bids = (data['bids'] as List?)?.length ?? 0;
    final isUrgent = data['urgentRequired'] == true;
    final area = data['area'] as String? ?? '';
    final city = data['city'] as String? ?? '';
    final location = [area, city].where((s) => s.isNotEmpty).join(', ');
    final createdAt = data['createdAt'] as Timestamp?;

    // ── FIX: resolve the project's cover photo, same field names
    //         used by Post Project (coverImage, falls back to
    //         images[0]). ─────────────────────────────────────────
    final coverImage = data['coverImage'] as String?;
    final images = (data['images'] as List?)?.map((e) => e.toString()).toList();
    final thumbUrl = (coverImage != null && coverImage.trim().isNotEmpty)
        ? coverImage
        : ((images != null && images.isNotEmpty) ? images.first : null);
    final hasThumb = thumbUrl != null && thumbUrl.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(
            projectId: projectId,
            data: data,
            canBid: canBid,
            bidsRemaining: bidsRemaining,
            planName: planName,
            onBidSuccess: onBidSuccess,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── NEW: OLX/Upwork-style cover photo on the list card ──
            if (hasThumb)
              SizedBox(
                height: 130,
                width: double.infinity,
                child: Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: AppTheme.bg,
                      child: const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppTheme.bg,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top of card: relative post time ("2 hours ago") ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            createdAt != null
                                ? timeago.format(createdAt.toDate())
                                : 'Just now',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$bids bid${bids == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── Client trust chip — the client's star rating from ──
                  // completed projects, so contractors can judge
                  // reliability (timely payment, cooperation) before bidding.
                  _ClientTrustChip(data: data),
                  const SizedBox(height: 8),
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
                                  color: const Color(0xFFFAEEDA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Urgent',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF854F0B),
                                  ),
                                ),
                              ),
                            Text(
                              data['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.emerald,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['projectType'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rs ${data['budgetMin'] ?? '?'} – ${data['budgetMax'] ?? '?'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.emerald,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['description'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!canBid) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            planName == 'Free'
                                ? 'Upgrade to bid'
                                : 'No bids remaining',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
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
}

// ── Client trust chip ────────────────────────────────────────────────
// Fetches the client's aggregate rating (clients/{uid}.rating — kept
// accurate by ReviewService) once per card and shows it as a small
// "name + star (count)" row. New clients show a neutral "New client"
// badge. This is the contractor-side half of the confidence system.
class _ClientTrustChip extends StatefulWidget {
  final Map<String, dynamic> data;

  const _ClientTrustChip({required this.data});

  @override
  State<_ClientTrustChip> createState() => _ClientTrustChipState();
}

class _ClientTrustChipState extends State<_ClientTrustChip> {
  double? _rating;
  int? _count;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = widget.data['clientId'] as String? ?? '';
    if (uid.isEmpty) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('clients')
          .doc(uid)
          .get();
      final d = snap.data();
      if (mounted) {
        setState(() {
          _rating = (d?['rating'] as num?)?.toDouble();
          _count = (d?['ratingCount'] as num?)?.toInt();
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.data['clientName'] as String? ?? 'Client';
    final hasRating = _rating != null && _rating! > 0;

    return Row(
      children: [
        Icon(Icons.person_outline_rounded,
            size: 13, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            clientName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        if (!_loaded)
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          )
        else if (hasRating)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F2ED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    size: 11, color: Color(0xFFC9A227)),
                const SizedBox(width: 2),
                Text(
                  '${_rating!.toStringAsFixed(1)} (${_count ?? 0})',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E3B2E),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'New client',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ),
      ],
    );
  }
}

class ProjectDetailScreen extends StatefulWidget {
  final String projectId, planName;
  final Map<String, dynamic> data;
  final bool canBid;
  final int bidsRemaining;
  final VoidCallback onBidSuccess;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.data,
    required this.canBid,
    required this.bidsRemaining,
    required this.planName,
    required this.onBidSuccess,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  bool _alreadyBid = false;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── NEW: which gallery photo is currently shown big at the top ──
  int _activeImageIndex = 0;

  static const _amber = Color(0xFFC9A227);
  static const _navy = Color(0xFF0E3B2E);
  static const _green = AppTheme.emerald;
  static const _red = Color(0xFFDC2626);

  static const _white = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _checkAlreadyBid();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  void _checkAlreadyBid() {
    final bids = widget.data['bids'] as List? ?? [];
    if (bids.any((b) => (b as Map<String, dynamic>)['theekaydaarId'] == _uid)) {
      setState(() => _alreadyBid = true);
    }
  }

  Future<void> _submitBid() async {
    if (_amountCtrl.text.isEmpty) {
      _snack('Please enter your bid amount');
      return;
    }
    setState(() => _submitting = true);
    try {
      final db = FirebaseFirestore.instance;
      final tkDoc = await db.collection('thekaydaars').doc(_uid).get();
      if (!tkDoc.exists) {
        _snack('Profile not found.');
        setState(() => _submitting = false);
        return;
      }
      final tkData = tkDoc.data()!;
      final canBid = tkData['canBid'] as bool? ?? false;
      final bidsRemaining = tkData['bidsRemaining'] as int? ?? 0;
      final planName = tkData['planName'] as String? ?? 'Free';

      if (!canBid || planName == 'Free') {
        _snack('Your plan does not allow bidding. Please upgrade.');
        setState(() => _submitting = false);
        return;
      }
      if (bidsRemaining <= 0) {
        _snack('No bids remaining this month. Upgrade to Elite for more.');
        setState(() => _submitting = false);
        return;
      }

      final projDoc = await db
          .collection('projects')
          .doc(widget.projectId)
          .get();
      if (projDoc.exists) {
        final bids = List.from((projDoc.data() as Map)['bids'] as List? ?? []);
        if (bids.any((b) => (b as Map)['theekaydaarId'] == _uid)) {
          _snack('You have already bid on this project.');
          setState(() {
            _submitting = false;
            _alreadyBid = true;
          });
          return;
        }
      }

      final tkName = (tkData['fullName'] as String? ?? '').trim();
      final bidData = {
        'theekaydaarId': _uid,
        'theekaydaarName': tkName,
        'amount': _amountCtrl.text.trim(),
        'note': _noteCtrl.text.trim(),
        'completionDays': _daysCtrl.text.trim(),
        'submittedAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      };

      await db.collection('projects').doc(widget.projectId).update({
        'bids': FieldValue.arrayUnion([bidData]),
      });
      await db.collection('thekaydaars').doc(_uid).update({
        'bidsRemaining': FieldValue.increment(-1),
      });

      // ── Notify the client about the new bid ─────────────
      final projData = projDoc.data() ?? {};
      final clientUid = projData['clientId'] as String? ?? '';
      final projectTitle = projData['title'] as String? ?? 'your project';
      await NotificationService.instance.notifyNewBid(
        clientUid: clientUid,
        contractorName: tkName.isNotEmpty ? tkName : 'A contractor',
        projectTitle: projectTitle,
        amount: _amountCtrl.text.trim(),
        projectId: widget.projectId,
      );

      widget.onBidSuccess();
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      setState(() => _submitting = false);
      _snack('Error: $e');
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _snack('Could not open maps app.');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Project Details',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: Colors.grey.shade200),
      ),
    ),
    body: _submitted ? _successView() : _detailView(widget.data),
  );

  // ── NEW: builds the hero image + thumbnail strip, OLX/Upwork style.
  //         Reads coverImage / images[] the same way Post Project saved
  //         them. Shows a neutral placeholder if no photos exist. ─────
  Widget _buildImageGallery(Map<String, dynamic> d) {
    final coverImage = d['coverImage'] as String?;
    final images = (d['images'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];

    final gallery = <String>[
      if (coverImage != null && coverImage.trim().isNotEmpty) coverImage,
      ...images.where((u) => u.trim().isNotEmpty && u != coverImage),
    ];

    if (gallery.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        color: AppTheme.bg,
        child: Center(
          child: Icon(
            Icons.construction_rounded,
            size: 36,
            color: Colors.grey.shade400,
          ),
        ),
      );
    }

    final activeIndex = _activeImageIndex.clamp(0, gallery.length - 1);

    return Column(
      children: [
        SizedBox(
          height: 240,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                gallery[activeIndex],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppTheme.bg,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _amber,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppTheme.bg,
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 32,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              if (gallery.length > 1)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${activeIndex + 1}/${gallery.length}',
                      style: const TextStyle(
                        color: _white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (gallery.length > 1)
          Container(
            color: Colors.white,
            height: 70,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: gallery.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = i == activeIndex;
                return GestureDetector(
                  onTap: () => setState(() => _activeImageIndex = i),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? _amber : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      gallery[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppTheme.bg,
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Divider(color: Colors.grey.shade100, height: 1),
      ],
    );
  }

  Widget _detailView(Map<String, dynamic> d) {
    final area = d['area'] as String? ?? '';
    final city = d['city'] as String? ?? '';
    final loc = [area, city].where((s) => s.isNotEmpty).join(', ');
    final plotAddress = d['plotAddress'] as String? ?? '';
    final GeoPoint? plotLocation = d['plotLocation'] as GeoPoint?;
    final createdAt = d['createdAt'] as Timestamp?;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── NEW: photo gallery at the very top ──
        _buildImageGallery(d),
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
                        if (d['urgentRequired'] == true)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAEEDA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Urgent',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF854F0B),
                              ),
                            ),
                          ),
                        Text(
                          d['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d['projectType'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Posted ${timeago.format(createdAt.toDate())}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Rs ${d['budgetMin']} –\n${d['budgetMax']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F6E56),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade100),
              const SizedBox(height: 12),
              _row(Icons.location_on_outlined, 'Location', loc),
              if (plotAddress.isNotEmpty)
                _row(Icons.pin_drop_outlined, 'Exact address', plotAddress),
              if (plotLocation != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: GestureDetector(
                    onTap: () => _openInMaps(
                      plotLocation.latitude,
                      plotLocation.longitude,
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.map_rounded,
                          size: 16,
                          color: AppTheme.emerald,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'View exact plot on map',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _row(
                Icons.person_outline_rounded,
                'Posted by',
                d['clientName'] ?? 'Client',
              ),
              _row(
                Icons.calendar_today_outlined,
                'Start date',
                d['startDate'] ?? 'Flexible',
              ),
              _row(
                Icons.schedule_outlined,
                'Duration',
                d['duration'] ?? 'Not specified',
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                d['description'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.6,
                ),
              ),
              if ((d['services'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                const Text(
                  'Services needed',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (d['services'] as List)
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1F5EE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F6E56),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],

              // ── AI House Plan: read-only blueprint + room dimensions for
              //    the contractor (spec §28 — construction data ONLY, no
              //    3D/360/private visualizations) ───────────────────
              if ((d['housePlanId'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildBlueprintCard(d),
              ],

              const SizedBox(height: 24),
              Divider(color: Colors.grey.shade100),
              const SizedBox(height: 16),

              if (_alreadyBid) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F5EE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF5DCAA5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppTheme.emerald,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have already submitted a bid on this project.',
                          style: TextStyle(
                            color: Color(0xFF0F6E56),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ] else if (!widget.canBid) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lock_rounded, color: _red, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        widget.planName == 'Free'
                            ? 'Upgrade to Pro or Elite to bid on projects'
                            : 'No bids remaining this month on your ${widget.planName} plan',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.planName == 'Free'
                            ? 'Pro plan: 10 bids/month. Elite plan: 15 bids/month.'
                            : 'Upgrade to Elite for 15 bids/month.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.workspace_premium_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Upgrade Plan',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _amber,
                            foregroundColor: _navy,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _amber.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: _amber,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.bidsRemaining} bid${widget.bidsRemaining == 1 ? '' : 's'} remaining on your ${widget.planName} plan',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Place your bid',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Competitive bids with clear notes get picked faster.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                _lbl('Your bid amount (Rs) *'),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _dec('e.g. 85,000', prefixText: 'Rs '),
                ),
                const SizedBox(height: 14),
                _lbl('Days to complete *'),
                TextFormField(
                  controller: _daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _dec('e.g. 14', suffixText: ' days'),
                ),
                const SizedBox(height: 14),
                _lbl('Message to client'),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 4,
                  decoration: _dec('Explain your experience and approach...'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitBid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: _white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Bid',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _successView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFE1F5EE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 44,
              color: AppTheme.emerald,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Bid Submitted!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'The client will review your bid and contact you if selected.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${widget.bidsRemaining - 1} bid${(widget.bidsRemaining - 1) == 1 ? '' : 's'} remaining this month',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _amber,
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: _white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Browse More Projects',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ── AI House Plan: contractor card (spec §28) ────────────────
  // Construction data only: plot size, floors, rooms, blueprint preview,
  // room dimensions sheet. NO 3D / 360 / private visualizations —
  // HousePlanService.getForContractor never returns those URLs at all.
  Widget _buildBlueprintCard(Map<String, dynamic> d) {
    return FutureBuilder<HousePlanDoc?>(
      future: HousePlanService.getForContractor(widget.projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 90,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final doc = snap.data;
        if (doc == null || !doc.hasPlan) return const SizedBox.shrink();
        final plan = doc.plan!;
        final previewFloor = plan.floors.first.floor;
        final longSide = plan.plotWidthFt > plan.plotLengthFt
            ? plan.plotWidthFt
            : plan.plotLengthFt;
        final pxPerFt = 220 / longSide;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE1F5EE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.architecture_rounded,
                        size: 18, color: AppTheme.emerald),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Blueprint & Room Dimensions',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'v${doc.version}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F6E56)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${plan.plotWidthFt.round()} × ${plan.plotLengthFt.round()} ft · '
                '${plan.floors.length} floor${plan.floors.length > 1 ? 's' : ''} · '
                '${plan.totalRooms} rooms · '
                '${plan.coveredArea.round()} sq ft covered',
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: FittedBox(
                  child: SizedBox(
                    width: plan.plotWidthFt * pxPerFt + 40,
                    height: plan.plotLengthFt * pxPerFt + 40,
                    child: CustomPaint(
                      painter: BlueprintPainter(
                        plan: plan,
                        floor: previewFloor,
                        scale: pxPerFt,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlueprintViewScreen(
                        plan: plan,
                        mode: BlueprintViewerMode.contractor,
                        projectTitle: d['title'] as String? ?? 'Blueprint',
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.architecture_rounded, size: 17),
                  label: const Text('VIEW BLUEPRINT & DIMENSIONS',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.emerald),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
  );

  InputDecoration _dec(String hint, {String? prefixText, String? suffixText}) =>
      InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        suffixText: suffixText,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.emerald),
        ),
      );
}