// =============================================================================
// my_bids_screen.dart
//
// "My Bids" screen for the Thekaydaar role — opened from the profile drawer.
// Bids live inside projects/{id}.bids[] (array of maps written by
// BrowseProjectsScreen._submitBid), so we stream the projects collection and
// filter client-side for entries where theekaydaarId == my uid.
//
// Status shown per bid:
//   Accepted      → project.acceptedTkId == my uid
//   Pending       → project still 'open'
//   Not Selected  → project was awarded to someone else / is closed
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ali_app/Theekaydaar/browse_projects_screen.dart';

class MyBidsScreen extends StatefulWidget {
  const MyBidsScreen({super.key});

  @override
  State<MyBidsScreen> createState() => _MyBidsScreenState();
}

class _MyBidsScreenState extends State<MyBidsScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Plan gating — same source as BrowseProjectsScreen. Needed only to open
  // ProjectDetailScreen from a bid card.
  bool _canBid = false;
  int _bidsRemaining = 0;
  String _planName = 'Free';

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _amberD = Color(0xFFA8861D);
  static const _amberL = Color(0xFFFBF6E3);
  static const _green = Color(0xFF10B981);
  static const _greenL = Color(0xFFD1FAE5);
  static const _border = Color(0xFFE3E0D5);
  static const _surface = Color(0xFFF7F5EF);
  static const _white = Color(0xFFFFFFFF);
  static const _textPri = Color(0xFF0E3B2E);
  static const _textSec = Color(0xFF5D6B64);

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('thekaydaars')
          .doc(_uid)
          .get();
      if (!mounted || !doc.exists) return;
      final d = doc.data()!;
      setState(() {
        _canBid = d['canBid'] as bool? ?? false;
        _bidsRemaining = d['bidsRemaining'] as int? ?? 0;
        _planName = d['planName'] as String? ?? 'Free';
      });
    } catch (_) {
      // Plan info is only needed for tap-through; ignore load errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Bids',
          style: TextStyle(
            color: _white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('projects').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _amber),
            );
          }
          if (snap.hasError) {
            return _emptyState(
              Icons.error_outline_rounded,
              'Could not load your bids.\nPlease try again later.',
            );
          }

          // Flatten: one row per project where I have placed a bid.
          final rows = <_BidRow>[];
          for (final doc in snap.data?.docs ?? const <DocumentSnapshot>[]) {
            final raw = doc.data();
            if (raw == null) continue;
            final data = Map<String, dynamic>.from(raw as Map);
            final bids = (data['bids'] as List? ?? [])
                .map((b) => Map<String, dynamic>.from(b as Map))
                .where((b) => b['theekaydaarId'] == _uid)
                .toList();
            if (bids.isEmpty) continue;
            rows.add(
              _BidRow(projectId: doc.id, project: data, bid: bids.first),
            );
          }

          // Newest bids first (bids without a timestamp sink to bottom).
          final fallback = DateTime.fromMillisecondsSinceEpoch(0);
          rows.sort(
            (a, b) => (b.submittedAt ?? fallback).compareTo(
              a.submittedAt ?? fallback,
            ),
          );

          if (rows.isEmpty) {
            return _emptyState(
              Icons.gavel_rounded,
              'No bids yet.\nBrowse projects and place your first bid!',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _bidCard(rows[i]),
          );
        },
      ),
    );
  }

  Widget _emptyState(IconData icon, String msg) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: _amberL,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: _amberD),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSec,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _bidCard(_BidRow row) {
    final title = row.project['title'] as String? ?? 'Untitled project';
    final area = row.project['area'] as String? ?? '';
    final city = row.project['city'] as String? ?? '';
    final location = [area, city].where((s) => s.isNotEmpty).join(', ');
    final budget =
        row.project['budget']?.toString() ?? row.project['price']?.toString();
    final amount = row.bid['amount']?.toString() ?? '';
    final days = row.bid['completionDays']?.toString() ?? '';
    final projectStatus = row.project['status'] as String? ?? 'open';
    final acceptedTkId = row.project['acceptedTkId'] as String? ?? '';

    final isAccepted = acceptedTkId == _uid;
    final isPending = !isAccepted && projectStatus == 'open';

    final (chipLabel, chipBg, chipFg) = isAccepted
        ? ('Accepted', _greenL, _green)
        : isPending
            ? ('Pending', _amberL, _amberD)
            : ('Not Selected', const Color(0xFFF3F4F6), _textSec);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(
            projectId: row.projectId,
            data: row.project,
            canBid: _canBid,
            bidsRemaining: _bidsRemaining,
            planName: _planName,
            onBidSuccess: _loadPlan, // refresh bids-left chip
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + status chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPri,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    chipLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: chipFg,
                    ),
                  ),
                ),
              ],
            ),
            if (location.isNotEmpty || row.submittedAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (location.isNotEmpty) ...[
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: _textSec,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSec,
                        ),
                      ),
                    ),
                  ],
                  if (row.submittedAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Bid placed ${timeago.format(row.submittedAt!)}',
                      style: const TextStyle(fontSize: 12, color: _textSec),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Stats row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _stat('My Bid', amount.isNotEmpty ? 'PKR $amount' : '—'),
                  _stat(
                    'Delivery',
                    days.isNotEmpty ? '$days days' : '—',
                  ),
                  _stat(
                    'Client Budget',
                    (budget != null && budget.isNotEmpty)
                        ? 'PKR $budget'
                        : 'Open',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _textSec,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _amberD,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// One row = one project I bid on + my bid map.
// ─────────────────────────────────────────────────────────────
class _BidRow {
  final String projectId;
  final Map<String, dynamic> project;
  final Map<String, dynamic> bid;

  _BidRow({required this.projectId, required this.project, required this.bid});

  DateTime? get submittedAt =>
      DateTime.tryParse(bid['submittedAt'] as String? ?? '');
}
