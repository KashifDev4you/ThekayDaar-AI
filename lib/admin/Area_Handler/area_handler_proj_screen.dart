import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectsScreen extends StatelessWidget {
  final String city;
  final String area;

  const ProjectsScreen({super.key, required this.city, required this.area});

  void _toggleFlag(String docId, bool currentFlag) async {
    await FirebaseFirestore.instance.collection('projects').doc(docId).update({
      'isFlagged': !currentFlag,
      'flaggedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E3B2E),
        foregroundColor: Colors.white,
        title: const Text('Area Projects & Bids', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('projects').where('city', isEqualTo: city).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data?.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['area'] as String? ?? '') == area;
          }).toList() ?? [];

          if (docs.isEmpty) return const Center(child: Text('No projects running in your territory.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final String title = data['title'] ?? 'Untitled Task';
              final String budget = data['budget']?.toString() ?? 'Open';
              final bool isFlagged = data['isFlagged'] ?? false;
              final String description = data['description'] ?? '';

              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isFlagged ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                          Text('PKR $budget', style: const TextStyle(color: Color(0xFFA8861D), fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF5D6B64), fontSize: 13)),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _toggleFlag(doc.id, isFlagged),
                            icon: Icon(isFlagged ? Icons.outlined_flag : Icons.flag, color: Colors.red),
                            label: Text(isFlagged ? 'Unflag Project' : 'Flag Suspicious', style: const TextStyle(color: Colors.red)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}