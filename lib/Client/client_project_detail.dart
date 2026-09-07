import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ali_app/MessageAndNotification/chat_meta_service.dart';
import 'package:ali_app/MessageAndNotification/chat_service.dart';
import 'package:ali_app/MessageAndNotification/chat_screen.dart';
import 'package:ali_app/MessageAndNotification/cloudinary_service.dart';
import 'package:ali_app/MessageAndNotification/cloudinary_config.dart';
import 'package:ali_app/contract/contract_screen.dart';
import 'package:ali_app/contract/contract_detail_screen.dart';
import 'package:ali_app/rating_system/rating_sheet.dart'; // adjust path if different
import 'package:ali_app/profile_sub_pages/notifications/notification_service.dart';
import 'package:ali_app/house_planner/screens/blueprint_view_screen.dart';
import 'package:ali_app/house_planner/services/house_plan_service.dart';
import 'package:ali_app/house_planner/widgets/blueprint_painter.dart';

// CLIENT PROJECT DETAIL SCREEN
// Client sees all bids on their project, views contractor profile, accepts bid
// =============================================================================
class ClientProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> data;

  const ClientProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.data,
  });

  @override
  State<ClientProjectDetailScreen> createState() =>
      _ClientProjectDetailScreenState();
}

class _ClientProjectDetailScreenState extends State<ClientProjectDetailScreen> {
  bool _accepting = false;

  // Fetched once so we can pass a real name into ContractDetailScreen /
  // the rating sheet instead of leaving it blank.
  String _myName = '';

  // ── Which gallery photo is currently shown big at the top.
  //    NOTE: we deliberately do NOT use a PageView/PageController
  //    here. This screen sits under a Firestore StreamBuilder, and
  //    every snapshot (even unrelated ones, e.g. a bid getting
  //    added) rebuilds this whole widget tree. A PageController
  //    tied to that lifecycle was snapping back to the old image
  //    after an arrow tap because the rebuild raced the animation.
  //    AnimatedSwitcher driven by plain setState has no such
  //    lifecycle to race, so it's reliable here. ──────────────────
  int _activeImageIndex = 0;
  bool _slideForward = true; // direction for the next transition

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _white = Color(0xFFFFFFFF);
  static const _bg = Color(0xFFF7F5EF);
  static const _label = Color(0xFF1F2A26);
  static const _sub = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _fill = Color(0xFFF7F5EF);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFDC2626);
  static const _blue = Color(0xFF1A5C46);

  @override
  void initState() {
    super.initState();
    _loadMyName();
  }

  Future<void> _loadMyName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('clients')
        .doc(uid)
        .get();
    if (mounted) {
      setState(() => _myName = doc.data()?['fullName'] as String? ?? '');
    }
  }

  Stream<DocumentSnapshot> get _projectStream => FirebaseFirestore.instance
      .collection('projects')
      .doc(widget.projectId)
      .snapshots();

  // ── Shared slide-to helper used by both arrows and thumbnails.
  //    Just flips the direction flag and updates the index — the
  //    AnimatedSwitcher in _buildImageGallery does the animating. ──
  void _goToImage(int index) {
    if (index == _activeImageIndex) return;
    setState(() {
      _slideForward = index > _activeImageIndex;
      _activeImageIndex = index;
    });
  }

  Future<void> _acceptBid(Map<String, dynamic> bid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Accept this bid?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          'You are hiring ${bid['theekaydaarName'] ?? 'this contractor'} '
          'for Rs ${bid['amount']}. This cannot be undone.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: _white,
            ),
            child: const Text('Yes, Hire'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _accepting = true);
    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = FieldValue.serverTimestamp();

      final clientDoc = await db.collection('clients').doc(uid).get();
      final resolvedClientName = clientDoc.data()?['fullName'] as String? ?? '';
      final resolvedClientPhoto =
          clientDoc.data()?['profilePic'] as String? ?? '';

      if (resolvedClientName.trim().isEmpty ||
          resolvedClientPhoto.trim().isEmpty) {
        setState(() => _accepting = false);
        if (mounted) {
          _snack(
            'Please complete your profile (name + photo) before hiring a contractor.',
            _red,
          );
        }
        return;
      }

      final tkId = bid['theekaydaarId'] as String? ?? '';
      String resolvedContractorPhoto = '';
      String resolvedContractorName = bid['theekaydaarName'] as String? ?? '';
      if (tkId.isNotEmpty) {
        final tkDoc = await db.collection('thekaydaars').doc(tkId).get();
        resolvedContractorPhoto = tkDoc.data()?['profilePic'] as String? ?? '';
        final liveName = tkDoc.data()?['fullName'] as String? ?? '';
        if (liveName.trim().isNotEmpty) resolvedContractorName = liveName;
      }

      await db.collection('projects').doc(widget.projectId).update({
        'status': 'in_progress',
        'acceptedBid': bid,
        'acceptedTkId': bid['theekaydaarId'],
        'acceptedTkName': resolvedContractorName,
        'acceptedTkPhoto': resolvedContractorPhoto,
        'acceptedAmount': bid['amount'],
        'updatedAt': now,
      });

      await db.collection('active_jobs').add({
        'projectId': widget.projectId,
        'projectTitle': widget.data['title'] ?? '',
        'clientId': uid,
        'clientName': resolvedClientName,
        'thekaydaarId': bid['theekaydaarId'],
        'thekaydaarName': resolvedContractorName,
        'amount': bid['amount'],
        'completionDays': bid['completionDays'] ?? '',
        'area': widget.data['area'] ?? '',
        'city': widget.data['city'] ?? '',
        'status': 'active',
        'createdAt': now,
      });

      await ChatMetaService.createChat(
        jobId: widget.projectId,
        jobTitle: widget.data['title'] ?? '',
        clientId: uid,
        clientName: resolvedClientName,
        contractorId: bid['theekaydaarId'] as String,
        contractorName: resolvedContractorName,
        clientPhotoUrl: resolvedClientPhoto,
        contractorPhotoUrl: resolvedContractorPhoto,
      );

      if ((bid['theekaydaarId'] as String? ?? '').isNotEmpty) {
        await db.collection('thekaydaars').doc(bid['theekaydaarId']).update({
          'activeJobs': FieldValue.increment(1),
        });
      }

      // ── Notify the contractor their bid was accepted ────
      await NotificationService.instance.notifyBidAccepted(
        contractorUid: bid['theekaydaarId'] as String? ?? '',
        clientName: resolvedClientName.isNotEmpty
            ? resolvedClientName
            : 'A client',
        projectTitle: widget.data['title'] as String? ?? 'your project',
        amount: '${bid['amount'] ?? ''}',
        projectId: widget.projectId,
      );

      _snack('Bid accepted! Now create the work agreement.', _green);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CreateContractScreen(
              projectId: widget.projectId,
              clientId: uid,
              clientName: resolvedClientName,
              contractorId: bid['theekaydaarId'] as String,
              contractorName: resolvedContractorName,
            ),
          ),
        );
      }
    } catch (e) {
      _snack('Error: $e', _red);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(color: _white, fontSize: 13),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Project & Bids',
          style: TextStyle(
            color: _white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _projectStream,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _amber),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Project not found'));
          }

          final d = snap.data!.data() as Map<String, dynamic>;
          final bids = List<Map<String, dynamic>>.from(
            (d['bids'] as List? ?? []).map(
              (b) => Map<String, dynamic>.from(b as Map),
            ),
          );
          final status = d['status'] as String? ?? 'open';
          final isOpen = status == 'open';
          final acceptedTkId = d['acceptedTkId'] as String? ?? '';

          // SafeArea bottom — keeps the bid list clear of the gesture
          // bar / home indicator (top is handled by AppBar).
          return SafeArea(
            top: false,
            child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── OLX/Upwork-style photo gallery, now with slide + arrows ──
              _buildImageGallery(d),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProjectSummary(d, status),
                    const SizedBox(height: 20),

                    // ── AI House Plan card (spec §27): requirements +
                    //    blueprint preview + View/Edit/3D/360 buttons ──
                    if ((d['housePlanId'] as String? ?? '').isNotEmpty) ...[
                      _buildHousePlanCard(d),
                      const SizedBox(height: 20),
                    ],

                    if (!isOpen && acceptedTkId.isNotEmpty) ...[
                      _buildAcceptedBanner(d),
                      const SizedBox(height: 20),
                    ],

                    Row(
                      children: [
                        const Icon(Icons.gavel_rounded, size: 16, color: _sub),
                        const SizedBox(width: 8),
                        Text(
                          'BIDS (${bids.length})'.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _sub,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (bids.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hourglass_empty_rounded,
                              color: Color(0xFFA9B5AE),
                              size: 40,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No bids yet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _sub,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Contractors will submit their bids here.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFA6B2AB),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...bids.map(
                        (bid) => _BidCard(
                          bid: bid,
                          isOpen: isOpen,
                          accepting: _accepting,
                          acceptedTkId: acceptedTkId,
                          onAccept: () => _acceptBid(bid),
                        ),
                      ),

                    const SizedBox(height: 40),
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

  // ── Builds the hero image + thumbnail strip, OLX/Upwork style.
  //    AnimatedSwitcher drives a slide transition between photos,
  //    plus left/right arrow buttons for tap-to-navigate. Thumbnail
  //    taps and arrows both go through the same _goToImage() helper
  //    so everything stays in sync. Shows a neutral placeholder if
  //    no photos exist. ─────────────────────────────────────────
  Widget _buildImageGallery(Map<String, dynamic> d) {
    final coverImage = d['coverImage'] as String?;
    final images = (d['images'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];

    // Build the full gallery list, cover image first (deduped).
    final gallery = <String>[
      if (coverImage != null && coverImage.trim().isNotEmpty) coverImage,
      ...images.where((u) => u.trim().isNotEmpty && u != coverImage),
    ];

    if (gallery.isEmpty) {
      return Container(
        height: 220,
        width: double.infinity,
        color: _fill,
        child: const Center(
          child: Icon(
            Icons.construction_rounded,
            size: 40,
            color: Color(0xFFA6B2AB),
          ),
        ),
      );
    }

    final activeIndex = _activeImageIndex.clamp(0, gallery.length - 1);
    final hasMultiple = gallery.length > 1;

    return Column(
      children: [
        SizedBox(
          height: 260,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Slide effect: arrow/thumbnail taps flip _activeImageIndex
              //    via setState, and this AnimatedSwitcher slides the old
              //    image out / new image in based on _slideForward. No
              //    PageController involved, so nothing to race with the
              //    Firestore StreamBuilder rebuilding above us. ──────────
              ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    final incoming = Tween<Offset>(
                      begin: Offset(_slideForward ? 1 : -1, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return SlideTransition(position: incoming, child: child);
                  },
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    fit: StackFit.expand,
                    children: [...previousChildren, ?currentChild],
                  ),
                  child: Image.network(
                    gallery[activeIndex],
                    key: ValueKey(gallery[activeIndex]),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: _fill,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _amber,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: _fill,
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 36,
                          color: Color(0xFFA6B2AB),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Left arrow ──
              if (hasMultiple && activeIndex > 0)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _galleryArrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _goToImage(activeIndex - 1),
                    ),
                  ),
                ),

              // ── Right arrow ──
              if (hasMultiple && activeIndex < gallery.length - 1)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _galleryArrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _goToImage(activeIndex + 1),
                    ),
                  ),
                ),

              if (hasMultiple)
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
        if (hasMultiple)
          Container(
            color: _white,
            height: 72,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: gallery.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = i == activeIndex;
                return GestureDetector(
                  onTap: () => _goToImage(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? _amber : _border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      gallery[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: _fill,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 16,
                          color: Color(0xFFA6B2AB),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── NEW: small circular arrow button used on both sides of the gallery ──
  Widget _galleryArrow({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: _white, size: 26),
        ),
      ),
    );
  }

  // ── AI House Plan card (spec §27) ─────────────────────────────
  // Requirements list + blueprint preview + View Blueprint / 3D / 360.
  // Client-only: 3D/360 buttons route to the client-mode viewer.
  Widget _buildHousePlanCard(Map<String, dynamic> d) {
    final planId = d['housePlanId'] as String;
    return FutureBuilder<HousePlanDoc?>(
      future: HousePlanService.getForClient(planId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2, color: _amber),
              ),
            ),
          );
        }
        final doc = snap.data;
        if (doc == null || !doc.hasPlan) {
          return const SizedBox.shrink();
        }
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
            color: _white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: _bg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.architecture_rounded,
                        size: 18, color: _amber),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'AI House Plan',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _navy),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'v${doc.version}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _blue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // stats strip
              Text(
                '${plan.plotWidthFt.round()} × ${plan.plotLengthFt.round()} ft · '
                '${plan.floors.length} floor${plan.floors.length > 1 ? 's' : ''} · '
                '${plan.totalRooms} rooms · '
                '${plan.coveredArea.round()} sq ft covered',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _navy),
              ),
              const SizedBox(height: 12),

              // blueprint preview (read-only thumbnail)
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

              // requirements chips
              if ((doc.requirements ?? const []).isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (doc.requirements!)
                      .map((r) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: _bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${r.label}${r.quantity > 1 ? ' ×${r.quantity}' : ''}',
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: _blue),
                            ),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),

              // actions (client mode → EDIT / 3D / 360 inside)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openBlueprint(
                    d,
                    clientMode: true,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: _white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.architecture_rounded, size: 17),
                  label: const Text('VIEW BLUEPRINT',
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

  /// Opens the blueprint viewer for this project's house plan.
  /// [clientMode] true → full client experience (EDIT / 3D / 360);
  /// false → read-only contractor view (construction data only).
  void _openBlueprint(Map<String, dynamic> d, {required bool clientMode}) async {
    final planId = d['housePlanId'] as String;
    final doc = await HousePlanService.getForClient(planId);
    if (!mounted) return;
    if (doc == null || !doc.hasPlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('House plan is unavailable.'),
            backgroundColor: _red),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlueprintViewScreen(
          plan: doc.plan!,
          mode: clientMode
              ? BlueprintViewerMode.client
              : BlueprintViewerMode.contractor,
          planId: doc.id,
          currentVersion: doc.version,
          projectTitle: d['title'] as String? ?? 'AI House Plan',
        ),
      ),
    );
  }

  Widget _buildProjectSummary(Map<String, dynamic> d, String status) {
    final isOpen = status == 'open';
    final isProgress = status == 'in_progress';
    final isDone = status == 'completed';

    final statusColor = isOpen
        ? _amber
        : isProgress
        ? _blue
        : isDone
        ? _green
        : _sub;
    final statusLabel = isOpen
        ? 'Open'
        : isProgress
        ? 'In Progress'
        : isDone
        ? 'Completed'
        : status;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _label,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d['projectType'] ?? '',
            style: const TextStyle(fontSize: 13, color: _sub),
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.location_on_outlined,
            '${d['area'] ?? ''}, ${d['city'] ?? ''}',
          ),
          _infoRow(
            Icons.payments_outlined,
            'Budget: Rs ${d['budgetMin']} \u2013 ${d['budgetMax']}',
          ),
          if ((d['duration'] as String? ?? '').isNotEmpty)
            _infoRow(Icons.schedule_outlined, 'Duration: ${d['duration']}'),
          if (d['urgentRequired'] == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF6E3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flash_on_rounded,
                    size: 14,
                    color: Color(0xFFA8861D),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Urgent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFA8861D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcceptedBanner(Map<String, dynamic> d) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isCompleted = d['status'] == 'completed';
    final alreadyRated = d['clientRated'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  color: _green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bid Accepted!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _green,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d['acceptedTkName'] ?? ''} is working on this for Rs ${d['acceptedAmount'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _sub,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () {
                ChatMetaService.markRead(widget.projectId, currentUid);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      jobId: widget.projectId,
                      currentUserId: currentUid,
                      otherPartyName: d['acceptedTkName'] ?? 'Contractor',
                      otherPartyPhotoUrl: d['acceptedTkPhoto'] as String?,
                      chatService: ChatService(
                        jobId: widget.projectId,
                        cloudinaryService: CloudinaryService(
                          cloudName: CloudinaryConfig.cloudName,
                          uploadPreset: CloudinaryConfig.uploadPreset,
                        ),
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text(
                'Message Contractor',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: _white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () async {
                final query = await FirebaseFirestore.instance
                    .collection('contracts')
                    .where('projectId', isEqualTo: widget.projectId)
                    .limit(1)
                    .get();

                if (!mounted) return;

                // CHANGED: instead of just showing a toast and dead-ending,
                // send the client straight into CreateContractScreen so
                // they can actually create the agreement right here — this
                // covers the case where bid-acceptance succeeded but the
                // contract itself was never finished (e.g. app closed
                // mid-flow, user backed out of the create screen, etc.)
                if (query.docs.isEmpty) {
                  final contractorId = d['acceptedTkId'] as String? ?? '';
                  final contractorName = d['acceptedTkName'] as String? ?? '';

                  if (contractorId.isEmpty) {
                    _snack(
                      'Contractor info missing \u2014 cannot create agreement.',
                      _red,
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateContractScreen(
                        projectId: widget.projectId,
                        clientId: currentUid,
                        clientName: _myName,
                        contractorId: contractorId,
                        contractorName: contractorName,
                      ),
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContractDetailScreen(
                      contractId: query.docs.first.id,
                      currentUserId: currentUid,
                      currentUserFullName: _myName,
                      isContractor: false,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text(
                'View Work Agreement',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: const BorderSide(color: _navy),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // \u2500\u2500 Rate Contractor \u2014 only once job is fully completed \u2500\u2500
          if (isCompleted) ...[
            const SizedBox(height: 10),
            if (!alreadyRated)
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final contractQuery = await FirebaseFirestore.instance
                        .collection('contracts')
                        .where('projectId', isEqualTo: widget.projectId)
                        .limit(1)
                        .get();
                    if (contractQuery.docs.isEmpty) return;
                    if (!mounted) return;

                    await showRateContractorSheet(
                      context: context,
                      projectId: widget.projectId,
                      contractId: contractQuery.docs.first.id,
                      thekaydaarId: d['acceptedTkId'] as String? ?? '',
                      thekaydaarName: d['acceptedTkName'] as String? ?? '',
                      clientId: currentUid,
                      clientName: _myName,
                    );
                  },
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text(
                    'Rate Contractor',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: _navy,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              )
            else
              Row(
                children: const [
                  Icon(Icons.check_circle_rounded, size: 14, color: _green),
                  SizedBox(width: 6),
                  Text(
                    'You rated this contractor',
                    style: TextStyle(
                      fontSize: 12,
                      color: _green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 14, color: _sub),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: _sub)),
        ),
      ],
    ),
  );
}

// =============================================================================
// BID CARD \u2014 unchanged from before
// =============================================================================
class _BidCard extends StatefulWidget {
  final Map<String, dynamic> bid;
  final bool isOpen;
  final bool accepting;
  final String acceptedTkId;
  final VoidCallback onAccept;

  const _BidCard({
    required this.bid,
    required this.isOpen,
    required this.accepting,
    required this.acceptedTkId,
    required this.onAccept,
  });

  @override
  State<_BidCard> createState() => _BidCardState();
}

class _BidCardState extends State<_BidCard> {
  Map<String, dynamic>? _tkProfile;
  bool _loadingProfile = true;
  bool _expanded = false;

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _white = Color(0xFFFFFFFF);
  static const _label = Color(0xFF1F2A26);
  static const _sub = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _fill = Color(0xFFF7F5EF);
  static const _green = Color(0xFF10B981);
  static const _blue = Color(0xFF1A5C46);

  @override
  void initState() {
    super.initState();
    _loadContractorProfile();
  }

  Future<void> _loadContractorProfile() async {
    final tkId = widget.bid['theekaydaarId'] as String? ?? '';
    if (tkId.isEmpty) {
      setState(() => _loadingProfile = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('thekaydaars')
          .doc(tkId)
          .get();
      if (doc.exists) setState(() => _tkProfile = doc.data());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    final p = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : p[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bid = widget.bid;
    final tkId = bid['theekaydaarId'] as String? ?? '';
    final tkName = bid['theekaydaarName'] as String? ?? 'Contractor';
    final amount = bid['amount'] as String? ?? '\u2014';
    final days = bid['completionDays'] as String? ?? '\u2014';
    final note = bid['note'] as String? ?? '';

    final isAccepted = widget.acceptedTkId == tkId && tkId.isNotEmpty;

    final rating = _tkProfile == null ? null : (_tkProfile!['rating'] ?? 0.0);
    final totalJobs = _tkProfile?['totalJobs'] as int? ?? 0;
    final skills = List<String>.from(_tkProfile?['skills'] as List? ?? []);
    final skill = _tkProfile?['skill'] as String? ?? '';
    final area = _tkProfile?['area'] as String? ?? '';
    final nicNumber = _tkProfile?['nicNumber'] as String? ?? '';
    final completion = _tkProfile?['completionRate'] as String? ?? '\u2014';
    final profilePic = _tkProfile?['profilePic'] as String? ?? '';
    final isVerified = nicNumber.isNotEmpty;
    final hasPic = profilePic.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted ? _green.withValues(alpha: 0.4) : _border,
          width: isAccepted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── FIX: show the contractor's real profilePic ──
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasPic
                      ? Image.network(
                          profilePic,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              _initials(tkName),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _navy,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _initials(tkName),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _navy,
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
                              tkName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _label,
                              ),
                            ),
                          ),
                          if (isAccepted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Text(
                                'Hired',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _green,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (skill.isNotEmpty || area.isNotEmpty)
                        Text(
                          [
                            if (skill.isNotEmpty) skill,
                            if (area.isNotEmpty) area,
                          ].join(' \u00b7 '),
                          style: const TextStyle(fontSize: 12, color: _sub),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (isVerified) ...[
                            _badge(
                              Icons.verified_rounded,
                              'NIC Verified',
                              _green,
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (rating != null)
                            _badge(
                              Icons.star_rounded,
                              '${(rating as num).toStringAsFixed(1)} Rating',
                              const Color(0xFFC9A227),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!_loadingProfile && _tkProfile != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: _fill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _statItem('Rs $amount', 'Bid Amount'),
                  _vDivider(),
                  _statItem('$days days', 'Completion'),
                  _vDivider(),
                  _statItem('$totalJobs', 'Jobs Done'),
                  _vDivider(),
                  _statItem(completion, 'Success Rate'),
                ],
              ),
            ),
          ] else if (!_loadingProfile) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: _fill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _statItem('Rs $amount', 'Bid Amount'),
                  _vDivider(),
                  _statItem('$days days', 'Completion'),
                ],
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(color: _amber, minHeight: 2),
            ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _blue.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MESSAGE FROM CONTRACTOR',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _blue,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _label,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (skills.isNotEmpty && _expanded) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SKILLS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _sub,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: skills
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _fill,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _border),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _label,
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
          if (isVerified && _expanded) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 14, color: _green),
                  const SizedBox(width: 6),
                  Text(
                    'CNIC: ${nicNumber.substring(0, 5)}-XXXXXXX-${nicNumber[nicNumber.length - 1]}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _sub,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_tkProfile != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded ? 'Show less' : 'View full profile',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: _blue,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (widget.isOpen) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: widget.accepting ? null : widget.onAccept,
                  icon: widget.accepting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: _white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.handshake_rounded, size: 18),
                  label: Text(
                    'Accept & Hire ${tkName.split(' ').first}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: _white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ] else if (isAccepted) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: _green, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'This bid was accepted',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _label,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: _sub),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 32,
    color: _border,
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );
}