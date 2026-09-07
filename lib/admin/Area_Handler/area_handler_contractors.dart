// Lists all contractors in the area handler's city.
// Actions: View profile, View NIC, Verify, Reject, Suspend/Reinstate, Add notes.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ali_app/Widgets/nic_viewer_sheet.dart';

class AreaHandlerContractorsScreen extends StatefulWidget {
  final String city, area;
  const AreaHandlerContractorsScreen(
      {super.key, required this.city, required this.area});

  @override
  State<AreaHandlerContractorsScreen> createState() =>
      _AreaHandlerContractorsScreenState();
}

class _AreaHandlerContractorsScreenState
    extends State<AreaHandlerContractorsScreen> {
  static const Color _navy  = Color(0xFF0E3B2E);
  static const Color _amber = Color(0xFFC9A227);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _bg    = Color(0xFFF7F5EF);

  // Filter state: All | Verified | Pending | Rejected | Suspended
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    // Query all thekaydaars in this city — filtering is done client-side
    final Query query = FirebaseFirestore.instance
        .collection('thekaydaars')
        .where('city', isEqualTo: widget.city);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              '${widget.city} Contractors',
              style: const TextStyle(
                  color: _white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              widget.area,
              style: const TextStyle(
                  color: Color(0xFFA6B2AB), fontSize: 11),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [

          // ── Filter chips row ─────────────────────────────────
          Container(
            color: _white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All',
                  'Verified',
                  'Pending',
                  'Rejected',
                  'Suspended'
                ]
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(f),
                            selected: _filter == f,
                            onSelected: (_) =>
                                setState(() => _filter = f),
                            backgroundColor: _bg,
                            selectedColor: _amber.withValues(alpha: 0.15),
                            checkmarkColor: _amber,
                            labelStyle: TextStyle(
                              color: _filter == f
                                  ? const Color(0xFFA8861D)
                                  : const Color(0xFF5D6B64),
                              fontSize: 13,
                              fontWeight: _filter == f
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: _filter == f
                                  ? _amber
                                  : const Color(0xFFE3E0D5),
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(20)),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),

          // ── Contractors list ─────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: _amber));
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: ${snap.error}',
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center),
                    ),
                  );
                }

                final allDocs = snap.data?.docs ?? [];

                // Client-side filter by NIC/account status
                final docs = allDocs.where((doc) {
                  final d        = doc.data() as Map<String, dynamic>;
                  final verified = d['nicVerified']   as bool?   ?? false;
                  final rejected = d['nicRejected']   as bool?   ?? false;
                  final status   = d['accountStatus'] as String? ?? 'active';

                  if (_filter == 'Verified') {
                    return verified && !rejected && status != 'suspended';
                  }
                  if (_filter == 'Pending') {
                    return !verified && !rejected && status != 'suspended';
                  }
                  if (_filter == 'Rejected') {
                    return rejected && status != 'suspended';
                  }
                  if (_filter == 'Suspended') {
                    return status == 'suspended';
                  }
                  return true; // All
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.engineering_rounded,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No contractors found',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 15)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  // ✅ Fixed: duplicate parameter (_, _) → (_, __) 
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final data =
                        docs[i].data() as Map<String, dynamic>;
                    return _ContractorCard(
                        uid: docs[i].id, data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTRACTOR CARD
// ─────────────────────────────────────────────────────────────────────────────
// Replace the entire _ContractorCard class with this:

class _ContractorCard extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _ContractorCard({required this.uid, required this.data});


  static const Color _amber = Color(0xFFC9A227);

  // Opens the NicViewerSheet — same as client screen
  void _openNicViewer(
    BuildContext context,
    String? frontUrl,
    String? backUrl, {
    int startIndex = 0,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => NicViewerSheet(
        frontUrl: frontUrl,
        backUrl: backUrl,
        startIndex: startIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Read all fields from Firestore document ──
    final name     = data['fullName']      as String? ?? '—';
    final nic      = data['nicNumber']     as String? ?? '—';
    final phone    = data['phone']         as String? ?? '—';
    final verified = data['nicVerified']   as bool?   ?? false;
    final rejected = data['nicRejected']   as bool?   ?? false;
    final status   = data['accountStatus'] as String? ?? 'active';
    final city     = data['city']          as String? ?? '—';
    final plan     = data['planName']      as String? ?? 'Free';

    // Convert empty string → null so viewer shows empty state
    final nicFront = (data['nic_front_url'] as String? ?? '').isEmpty
        ? null
        : data['nic_front_url'] as String;
    final nicBack = (data['nic_back_url'] as String? ?? '').isEmpty
        ? null
        : data['nic_back_url'] as String;

    // Derive NIC badge label + color
    final String nicLabel;
    final Color  nicColor;
    if (rejected) {
      nicLabel = 'Rejected';
      nicColor = Colors.redAccent;
    } else if (verified) {
      nicLabel = 'Verified';
      nicColor = const Color(0xFF10B981);
    } else {
      nicLabel = 'Pending';
      nicColor = const Color(0xFFC9A227);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E0D5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header: avatar + name + city + badges ────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Amber initial avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Color(0xFFA8861D),
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Color(0xFF1F2A26),
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(city,
                          style: const TextStyle(
                              color: Color(0xFFA6B2AB),
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      Text(phone,
                          style: const TextStyle(
                              color: Color(0xFFA6B2AB),
                              fontSize: 11)),
                    ],
                  ),
                ),
                // NIC status + account status badges stacked
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Badge(label: nicLabel, color: nicColor),
                    const SizedBox(height: 4),
                    _Badge(
                      label: status == 'suspended'
                          ? 'Suspended'
                          : 'Active',
                      color: status == 'suspended'
                          ? Colors.redAccent
                          : const Color(0xFF5D6B64),
                    ),
                    if (plan != 'Free') ...[
                      const SizedBox(height: 4),
                      _Badge(
                          label: plan,
                          color: const Color(0xFFA8861D)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE3E0D5)),

          // ── NIC number + info row ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined,
                    size: 16, color: Color(0xFFA6B2AB)),
                const SizedBox(width: 8),
                const Text('NIC  ',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFFA6B2AB))),
                Expanded(
                  child: Text(nic,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2A26)),
                      overflow: TextOverflow.ellipsis),
                ),
                // View Profile button inline
                GestureDetector(
                  onTap: () => _viewProfile(context, uid, data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E3B2E).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('View Profile',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0E3B2E))),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE3E0D5)),

          // ── NIC images + verify/reject/suspend actions ────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Section header
                const Row(
                  children: [
                    Icon(Icons.credit_card_rounded,
                        size: 15, color: Color(0xFF5D6B64)),
                    SizedBox(width: 6),
                    Text('NIC Verification',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5D6B64))),
                  ],
                ),
                const SizedBox(height: 10),

                // Front + Back thumbnails — same as client screen
                Row(
                  children: [
                    _NicThumb(
                      url: nicFront,
                      label: 'Front',
                      onTap: () => _openNicViewer(
                          context, nicFront, nicBack),
                    ),
                    const SizedBox(width: 10),
                    _NicThumb(
                      url: nicBack,
                      label: 'Back',
                      onTap: () => _openNicViewer(
                          context, nicFront, nicBack,
                          startIndex: 1),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── NIC status action row ─────────────────────
                // Shows Verify+Reject if pending/rejected
                // Shows Suspend/Reinstate if verified
                if (!verified || rejected) ...[
                  Row(
                    children: [
                      // Verify button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _verifyNIC(context, uid),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 11),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.30)),
                            ),
                            child: const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                    Icons
                                        .verified_user_rounded,
                                    size: 16,
                                    color: Color(0xFF10B981)),
                                SizedBox(width: 6),
                                Text('Verify NIC',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight:
                                            FontWeight.w700,
                                        color: Color(
                                            0xFF10B981))),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Reject button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showRejectDialog(
                              context, uid, name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626)
                                  .withValues(alpha: 0.07),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFDC2626)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.gpp_bad_rounded,
                                    size: 16,
                                    color: Color(0xFFDC2626)),
                                SizedBox(width: 6),
                                Text('Reject',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight:
                                            FontWeight.w700,
                                        color: Color(
                                            0xFFDC2626))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Verified → Suspend / Reinstate full-width
                  GestureDetector(
                    onTap: () =>
                        _toggleSuspend(context, uid, status),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: status == 'suspended'
                            ? const Color(0xFF10B981)
                                .withValues(alpha: 0.08)
                            : const Color(0xFFDC2626)
                                .withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: status == 'suspended'
                              ? const Color(0xFF10B981)
                                  .withValues(alpha: 0.30)
                              : const Color(0xFFDC2626)
                                  .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            status == 'suspended'
                                ? Icons.lock_open_rounded
                                : Icons.block_rounded,
                            size: 16,
                            color: status == 'suspended'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status == 'suspended'
                                ? 'Reinstate Account'
                                : 'Suspend Account',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: status == 'suspended'
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── Rejection reason banner ───────────────────
                if (rejected) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: Colors.red.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Rejected: ${data['rejectionReason'] as String? ?? 'No reason given'}',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.red.shade700,
                                height: 1.4),
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
    );
  }

  // ── All action methods stay exactly the same ──────────────

  void _showRejectDialog(
      BuildContext context, String uid, String name) {
    final reasonCtrl = TextEditingController();
    String? selectedReason = 'Fake/unclear NIC images';
    final reasons = [
      'Fake/unclear NIC images',
      'NIC not matching face',
      'Expired NIC',
      'Suspicious identity',
      'Incomplete information',
      'Other',
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding:
              const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding:
              const EdgeInsets.fromLTRB(20, 8, 20, 16),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.cancel_outlined,
                    color: Colors.red.shade600, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Reject NIC — $name',
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select rejection reason:',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5D6B64))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons.map((r) {
                    final sel = selectedReason == r;
                    return GestureDetector(
                      onTap: () => setDialogState(
                          () => selectedReason = r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel
                              ? Colors.red.shade50
                              : const Color(0xFFF7F5EF),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? Colors.redAccent
                                : const Color(0xFFE3E0D5),
                          ),
                        ),
                        child: Text(r,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: sel
                                  ? Colors.redAccent
                                  : const Color(0xFF5D6B64),
                            )),
                      ),
                    );
                  }).toList(),
                ),
                if (selectedReason == 'Other') ...[
                  const SizedBox(height: 14),
                  const Text('Additional notes:',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5D6B64))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe the issue…',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF7F5EF),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Colors.redAccent,
                            width: 1.5),
                      ),
                      contentPadding:
                          const EdgeInsets.all(12),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style:
                      TextStyle(color: Color(0xFF5D6B64))),
            ),
            ElevatedButton(
              onPressed: () async {
                final finalReason =
                    selectedReason == 'Other'
                        ? (reasonCtrl.text.trim().isEmpty
                            ? 'Other'
                            : reasonCtrl.text.trim())
                        : selectedReason!;
                Navigator.pop(ctx);
                await _rejectNIC(context, uid, finalReason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
              child: const Text('Confirm Reject',
                  style: TextStyle(
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _viewProfile(
      BuildContext ctx, String uid, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _ContractorProfileSheet(uid: uid, data: data),
    );
  }

  Future<void> _verifyNIC(BuildContext ctx, String uid) async {
    await FirebaseFirestore.instance
        .collection('thekaydaars')
        .doc(uid)
        .update({
      'nicVerified'     : true,
      'nicRejected'     : false,
      'rejectionReason' : '',
    });
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('NIC verified ✓'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _rejectNIC(
      BuildContext ctx, String uid, String reason) async {
    await FirebaseFirestore.instance
        .collection('thekaydaars')
        .doc(uid)
        .update({
      'nicVerified'     : false,
      'nicRejected'     : true,
      'rejectionReason' : reason,
    });
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('NIC rejected — $reason'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _toggleSuspend(
      BuildContext ctx, String uid, String currentStatus) async {
    final newStatus =
        currentStatus == 'suspended' ? 'active' : 'suspended';
    await FirebaseFirestore.instance
        .collection('thekaydaars')
        .doc(uid)
        .update({'accountStatus': newStatus});
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(newStatus == 'suspended'
            ? 'Account suspended'
            : 'Account reinstated'),
        backgroundColor: newStatus == 'suspended'
            ? Colors.redAccent
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NIC THUMBNAIL — same widget as client screen
// ─────────────────────────────────────────────────────────────────────────────

class _NicThumb extends StatelessWidget {
  final String? url;
  final String label;
  final VoidCallback onTap;

  const _NicThumb({
    required this.url,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: url != null ? onTap : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA6B2AB),
                        fontWeight: FontWeight.w500)),
                if (url == null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.warning_amber_rounded,
                      size: 11, color: Color(0xFFC9A227)),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Stack(
              children: [
                Container(
                  height: 88,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5EF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFE3E0D5)),
                    image: url != null
                        ? DecorationImage(
                            image: NetworkImage(url!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: url == null
                      ? const Center(
                          child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFFA9B5AE),
                              size: 26))
                      : null,
                ),
                if (url != null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.zoom_in_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}// ─────────────────────────────────────────────────────────────────────────────
// CONTRACTOR PROFILE BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ContractorProfileSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _ContractorProfileSheet(
      {required this.uid, required this.data});

  @override
  State<_ContractorProfileSheet> createState() =>
      _ContractorProfileSheetState();
}

class _ContractorProfileSheetState
    extends State<_ContractorProfileSheet> {
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill notes field with existing admin notes if any
    _notesCtrl = TextEditingController(
        text: widget.data['adminNotes'] as String? ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  // Saves admin notes to Firestore
// Saves admin notes to Firestore
  Future<void> _saveNotes() async {
    if (widget.uid.isEmpty) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('thekaydaars')
          .doc(widget.uid)
          .update({'adminNotes': _notesCtrl.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notes saved.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }  @override
  Widget build(BuildContext context) {
    final data     = widget.data;
    final name     = data['fullName']        as String? ?? '—';
    final nic      = data['nicNumber']       as String? ?? '—';
    final phone    = data['phone']           as String? ?? '—';
    final email    = data['email']           as String? ?? '—';
    final city     = data['city']            as String? ?? '—';
    final area     = data['area']            as String? ?? '—';
    final plan     = data['planName']        as String? ?? 'Free';
    final bids     = data['bidsRemaining']   as int?    ?? 0;
    final rejected = data['nicRejected']     as bool?   ?? false;
    final reason   = data['rejectionReason'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          // Shift up when keyboard appears
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(name,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2A26))),
          const SizedBox(height: 16),

          // Profile info rows
          _ProfileRow(label: 'NIC',       value: nic),
          _ProfileRow(label: 'Phone',     value: phone),
          _ProfileRow(label: 'Email',     value: email),
          _ProfileRow(label: 'City',      value: city),
          _ProfileRow(label: 'Area',      value: area),
          _ProfileRow(label: 'Plan',      value: plan),
          _ProfileRow(label: 'Bids left', value: '$bids'),

          // Rejection reason shown only if contractor is rejected
          if (rejected && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cancel_outlined,
                      size: 14, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Rejection reason: $reason',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Admin notes section
          const Text('Admin Notes',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2A26))),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add note about this contractor…',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF7F5EF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFFC9A227), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),

          // Save notes button with loading state
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveNotes,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E3B2E),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white))
                  : const Text('Save Notes',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

// Single label/value row used in the profile sheet
class _ProfileRow extends StatelessWidget {
  final String label, value;
  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFFA6B2AB),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFF1F2A26),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// Colored pill badge with border
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600)),
    );
  }
}

// Icon + label inline chip for NIC/phone/plan display
// ignore: unused_element
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFFA6B2AB)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF5D6B64), fontSize: 12)),
      ],
    );
  }
}