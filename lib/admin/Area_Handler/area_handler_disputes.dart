import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class AreaHandlerDisputesScreen extends StatelessWidget {
  final String city, area;
  const AreaHandlerDisputesScreen(
      {super.key, required this.city, required this.area});

  static const Color _navy  = Color(0xFF0E3B2E);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _bg    = Color(0xFFF7F5EF);
  static const Color _amber = Color(0xFFC9A227);

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Disputes',
            style: TextStyle(
                color: _white,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('disputes')
            .where('city', isEqualTo: city)
            .where('status', isEqualTo: 'open')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: _amber));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gavel_rounded,
                      size: 52, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No open disputes',
                      style: TextStyle(
                          color: Color(0xFFA6B2AB),
                          fontSize: 15)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d =
                  docs[i].data() as Map<String, dynamic>;
              return _DisputeCard(
                  docId: docs[i].id, data: d);
            },
          );
        },
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _DisputeCard(
      {required this.docId, required this.data});

  Future<void> _resolve(BuildContext ctx, String verdict) async {
    await FirebaseFirestore.instance
        .collection('disputes')
        .doc(docId)
        .update({
      'status': 'resolved',
      'verdict': verdict,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('Dispute resolved: $verdict'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Dispute';
    final desc  = data['description'] as String? ?? '—';
    final client = data['clientEmail'] as String? ?? '—';
    final contractor =
        data['contractorEmail'] as String? ?? '—';
    final ts = data['createdAt'] as Timestamp?;
    final dateStr = ts != null
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
        : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      Colors.redAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gavel_rounded,
                    color: Colors.redAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2A26))),
              ),
              Text(dateStr,
                  style: const TextStyle(
                      color: Color(0xFFA6B2AB),
                      fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 10),
          Text(desc,
              style: const TextStyle(
                  color: Color(0xFF5D6B64),
                  fontSize: 13,
                  height: 1.5)),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.person_outline_rounded,
                size: 13, color: Color(0xFFA6B2AB)),
            const SizedBox(width: 4),
            Text('Client: $client',
                style: const TextStyle(
                    color: Color(0xFF5D6B64), fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.engineering_rounded,
                size: 13, color: Color(0xFFA6B2AB)),
            const SizedBox(width: 4),
            Text('Contractor: $contractor',
                style: const TextStyle(
                    color: Color(0xFF5D6B64), fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _resolve(context, 'favour_client'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC9A227),
                    side: const BorderSide(
                        color: Color(0xFFC9A227)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10)),
                  ),
                  child: const Text('Client wins',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      _resolve(context, 'favour_contractor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF1A5C46),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10)),
                  ),
                  child: const Text('Contractor wins',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}