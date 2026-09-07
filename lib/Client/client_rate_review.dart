import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// =============================================================================
// CLIENT RATE & REVIEW SCREEN
// Client rates thekaydaar after job is marked complete
// Writes to: reviews/{docId} + updates thekaydaar rating average
// Navigate to this screen from active_jobs when status == 'completed'
// =============================================================================
class ClientRateReviewScreen extends StatefulWidget {
  final String jobId;
  final String projectTitle;
  final String thekaydaarId;
  final String thekaydaarName;
  final String amount;

  const ClientRateReviewScreen({
    super.key,
    required this.jobId,
    required this.projectTitle,
    required this.thekaydaarId,
    required this.thekaydaarName,
    required this.amount,
  });

  @override
  State<ClientRateReviewScreen> createState() =>
      _ClientRateReviewScreenState();
}

class _ClientRateReviewScreenState extends State<ClientRateReviewScreen> {
  int    _rating       = 0;
  bool   _submitting   = false;
  bool   _submitted    = false;
  final  _reviewCtrl   = TextEditingController();

  // Sub-ratings
  int _qualityRating      = 0;
  int _timelinessRating   = 0;
  int _communicationRating = 0;

  static const _navy   = Color(0xFF0E3B2E);
  static const _amber  = Color(0xFFC9A227);
  static const _white  = Color(0xFFFFFFFF);
  static const _bg     = Color(0xFFF7F5EF);
  static const _label  = Color(0xFF1F2A26);
  static const _sub    = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _fill   = Color(0xFFF7F5EF);
  static const _green  = Color(0xFF10B981);
  static const _red    = Color(0xFFDC2626);

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    switch (_rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent!';
      default: return 'Tap to rate';
    }
  }

  Color get _ratingColor {
    switch (_rating) {
      case 1: return _red;
      case 2: return const Color(0xFFA8861D);
      case 3: return _amber;
      case 4: return const Color(0xFFE7C55A);
      case 5: return _green;
      default: return _sub;
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

  Future<void> _submitReview() async {
    if (_rating == 0) {
      _snack('Please select a star rating', _red);
      return;
    }
    if (_reviewCtrl.text.trim().isEmpty) {
      _snack('Please write a review', _red);
      return;
    }

    setState(() => _submitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final db  = FirebaseFirestore.instance;
      final now = FieldValue.serverTimestamp();

      // 1. Write review document
      await db.collection('reviews').add({
        'jobId'             : widget.jobId,
        'projectTitle'      : widget.projectTitle,
        'clientId'          : uid,
        'thekaydaarId'      : widget.thekaydaarId,
        'thekaydaarName'    : widget.thekaydaarName,
        'rating'            : _rating,
        'qualityRating'     : _qualityRating > 0 ? _qualityRating : _rating,
        'timelinessRating'  : _timelinessRating > 0 ? _timelinessRating : _rating,
        'communicationRating': _communicationRating > 0 ? _communicationRating : _rating,
        'review'            : _reviewCtrl.text.trim(),
        'createdAt'         : now,
      });

      // 2. Update thekaydaar rating average
      final tkDoc = await db.collection('thekaydaars').doc(widget.thekaydaarId).get();
      if (tkDoc.exists) {
        final tkData      = tkDoc.data()!;
        final currentRating = (tkData['rating'] as num?)?.toDouble() ?? 0.0;
        final totalJobs   = (tkData['totalJobs'] as int?) ?? 1;

        // Simple moving average
        final newRating = ((currentRating * (totalJobs - 1)) + _rating) / totalJobs;

        await db.collection('thekaydaars').doc(widget.thekaydaarId).update({
          'rating': double.parse(newRating.toStringAsFixed(1)),
        });
      }

      // 3. Mark job as reviewed
      await db.collection('active_jobs').doc(widget.jobId).update({
        'reviewed'  : true,
        'reviewedAt': now,
      });

      setState(() { _submitting = false; _submitted = true; });
    } catch (e) {
      _snack('Error: $e', _red);
      setState(() => _submitting = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: _white, fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
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
        title: const Text('Rate & Review',
            style: TextStyle(color: _white, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _submitted ? _buildSuccessView() : _buildReviewForm(),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
                color: _green.withValues(alpha:0.1), shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, color: _green, size: 50),
          ),
          const SizedBox(height: 24),
          const Text('Review Submitted!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _label)),
          const SizedBox(height: 10),
          Text(
            'Thank you for reviewing ${widget.thekaydaarName}. '
            'Your feedback helps improve the Thekaydaar platform.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _sub, height: 1.6),
          ),
          const SizedBox(height: 12),

          // Show rating given
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) =>
            Icon(i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                color: _amber, size: 30))),
          const SizedBox(height: 6),
          Text(_ratingLabel, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: _ratingColor)),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _amber, foregroundColor: _navy, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Back to Home',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildReviewForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [

        // ── Contractor info card ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: _navy.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(_initials(widget.thekaydaarName),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navy))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.thekaydaarName, style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _label)),
              const SizedBox(height: 4),
              Text(widget.projectTitle, style: const TextStyle(fontSize: 13, color: _sub),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('Paid: Rs ${widget.amount}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _green)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Overall rating ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            const Text('Overall Rating',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _label)),
            const SizedBox(height: 6),
            Text(_ratingLabel, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _ratingColor)),
            const SizedBox(height: 16),

            // Big star row
            Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: i < _rating ? _amber : const Color(0xFFA9B5AE),
                        size: 44,
                      ),
                    ),
                  );
                })),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Sub ratings ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Rate Specific Aspects',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _label)),
            const SizedBox(height: 4),
            const Text('Optional — helps contractors improve',
                style: TextStyle(fontSize: 12, color: _sub)),
            const SizedBox(height: 16),

            _subRatingRow('Work Quality',    Icons.build_outlined,    _qualityRating,       (v) => setState(() => _qualityRating = v)),
            const SizedBox(height: 14),
            _subRatingRow('Timeliness',      Icons.schedule_outlined, _timelinessRating,    (v) => setState(() => _timelinessRating = v)),
            const SizedBox(height: 14),
            _subRatingRow('Communication',   Icons.chat_outlined,     _communicationRating, (v) => setState(() => _communicationRating = v)),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Written review ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Written Review *',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _label)),
            const SizedBox(height: 4),
            const Text('Share your experience with this contractor',
                style: TextStyle(fontSize: 12, color: _sub)),
            const SizedBox(height: 12),
            TextField(
              controller: _reviewCtrl,
              maxLines: 5,
              style: const TextStyle(color: _label, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'How was the quality of work? Was the contractor professional and on time? Would you hire again?',
                hintStyle: const TextStyle(color: Color(0xFFA6B2AB), fontSize: 12.5),
                filled: true, fillColor: _fill,
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _amber, width: 1.5)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Quick tags ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Quick Tags',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _label)),
            const SizedBox(height: 4),
            const Text('Tap to add to your review',
                style: TextStyle(fontSize: 12, color: _sub)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                'Great quality work', 'On time', 'Professional',
                'Good communication', 'Would hire again',
                'Exceeded expectations', 'Clean work area',
                'Fair pricing',
              ].map((tag) {
                return GestureDetector(
                  onTap: () {
                    final current = _reviewCtrl.text;
                    if (!current.contains(tag)) {
                      _reviewCtrl.text = current.isEmpty
                          ? tag
                          : '$current, $tag';
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: _fill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _border)),
                    child: Text(tag, style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: _label)),
                  ),
                );
              }).toList(),
            ),
          ]),
        ),
        const SizedBox(height: 32),

        // ── Submit button ─────────────────────────────────────
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submitReview,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: _navy, strokeWidth: 2))
                : const Icon(Icons.star_rounded, size: 20),
            label: const Text('Submit Review',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber, foregroundColor: _navy, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Skip option
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip for now',
                style: TextStyle(fontSize: 13, color: _sub, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _subRatingRow(String label, IconData icon, int value, Function(int) onChanged) {
    return Row(children: [
      Icon(icon, size: 16, color: _sub),
      const SizedBox(width: 8),
      SizedBox(width: 110, child: Text(label, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: _label))),
      Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => onChanged(i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(
                  i < value ? Icons.star_rounded : Icons.star_border_rounded,
                  color: i < value ? _amber : const Color(0xFFA9B5AE),
                  size: 26,
                ),
              ),
            ))),
      ),
    ]);
  }
}

// =============================================================================
// COMPLETED JOBS LIST — Client sees completed jobs with rate button
// Add this to client.dart bottom nav tab 2 (Projects)
// =============================================================================
class ClientCompletedJobsScreen extends StatelessWidget {
  const ClientCompletedJobsScreen({super.key});

  static const _navy   = Color(0xFF0E3B2E);
  static const _amber  = Color(0xFFC9A227);
  static const _white  = Color(0xFFFFFFFF);
  static const _bg     = Color(0xFFF7F5EF);
  static const _label  = Color(0xFF1F2A26);
  static const _sub    = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _green  = Color(0xFF10B981);

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> get _stream =>
      FirebaseFirestore.instance
          .collection('active_jobs')
          .where('clientId', isEqualTo: _uid)
          .where('status', isEqualTo: 'completed')
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy, elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _white),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Completed Jobs',
            style: TextStyle(color: _white, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _amber));
          }

          var docs = snap.data?.docs ?? [];
          docs.sort((a, b) {
            final aT = (a.data() as Map<String,dynamic>)['completedAt'];
            final bT = (b.data() as Map<String,dynamic>)['completedAt'];
            if (aT == null && bT == null) return 0;
            if (aT == null) return 1; if (bT == null) return -1;
            return (bT as Timestamp).compareTo(aT as Timestamp);
          });

          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_outline_rounded, size: 52, color: Color(0xFFA9B5AE)),
              const SizedBox(height: 14),
              const Text('No completed jobs yet.',
                  style: TextStyle(fontSize: 13.5, color: _sub)),
            ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc      = docs[i];
              final d        = doc.data() as Map<String,dynamic>;
              final reviewed = d['reviewed'] as bool? ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03),
                      blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 44, height: 44,
                        decoration: BoxDecoration(
                            color: _green.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.check_circle_rounded, color: _green, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['projectTitle'] as String? ?? 'Project',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _label)),
                      const SizedBox(height: 2),
                      Text('Contractor: ${d['thekaydaarName'] ?? '—'}',
                          style: const TextStyle(fontSize: 12, color: _sub)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: _green.withValues(alpha:0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('Rs ${d['amount'] ?? '—'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _green)),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // Rate button or already reviewed badge
                  reviewed
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                              color: _green.withValues(alpha:0.07),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _green.withValues(alpha:0.2))),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.star_rounded, color: _green, size: 16),
                            SizedBox(width: 6),
                            Text('Review Submitted', style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: _green)),
                          ]))
                      : SizedBox(
                          width: double.infinity, height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ClientRateReviewScreen(
                                  jobId          : doc.id,
                                  projectTitle   : d['projectTitle'] as String? ?? '',
                                  thekaydaarId   : d['thekaydaarId'] as String? ?? '',
                                  thekaydaarName : d['thekaydaarName'] as String? ?? '',
                                  amount         : d['amount'] as String? ?? '',
                                ))),
                            icon: const Icon(Icons.star_rounded, size: 16),
                            label: const Text('Rate & Review',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _amber, foregroundColor: _navy, elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          )),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}