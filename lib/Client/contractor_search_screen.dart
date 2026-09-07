// lib/Client/contractor_search_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ali_app/Theekaydaar/thekaydaar_public_profile.dart';
import 'package:ali_app/services/gemini_service.dart';

class ContractorSearchScreen extends StatefulWidget {
  const ContractorSearchScreen({super.key});

  @override
  State<ContractorSearchScreen> createState() => _ContractorSearchScreenState();
}

class _ContractorSearchScreenState extends State<ContractorSearchScreen> {
  static const _bg = Color(0xFFF7F5EF);
  static const _surface = Colors.white;
  static const _amber = Color(0xFFC9A227);
  static const _amberLight = Color(0xFFFBF6E3);
  static const _amberDark = Color(0xFFA8861D);
  static const _textPri = Color(0xFF0E3B2E);
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _projectNeedCtrl = TextEditingController();
  String _query = '';
  String _selectedFilter = 'All';
  bool _onlyAvailable = false;
  bool _aiMatchingLoading = false;
  final Map<String, AiContractorMatch> _aiMatches = {};
  List<QueryDocumentSnapshot> _lastDocs = [];

  final List<String> _filters = ['All', 'Plumber', 'Electrician', 'Carpenter', 'Painter'];

  Stream<QuerySnapshot> get _contractorStream {
    Query q = FirebaseFirestore.instance
        .collection('thekaydaars')
        .where('role', isEqualTo: 'Contractor');
    if (_selectedFilter != 'All') {
      q = q.where('skills', arrayContains: _selectedFilter);
    }
    return q.snapshots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _projectNeedCtrl.dispose();
    super.dispose();
  }

  Future<void> _rankWithAi() async {
    final need = _projectNeedCtrl.text.trim();
    if (need.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe your project need first')),
      );
      return;
    }
    if (_lastDocs.isEmpty) return;

    setState(() => _aiMatchingLoading = true);
    try {
      final contractors = _lastDocs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return data;
      }).toList();

      final matches = await GeminiService.rankContractors(
        projectNeed: need,
        city: '',
        contractors: contractors,
      );

      if (!mounted) return;
      setState(() {
        _aiMatches.clear();
        for (final m in matches) {
          _aiMatches[m.contractorId] = m;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI matching failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _aiMatchingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Find Contractors'),
        backgroundColor: _surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textPri),
        titleTextStyle: const TextStyle(
          color: _textPri,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name or skill...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _border),
                ),
              ),
            ),
          ),
          SizedBox(
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
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _projectNeedCtrl,
                  maxLines: 2,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Describe your project need for AI matching...',
                    hintStyle: const TextStyle(fontSize: 12.5),
                    prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 20),
                    filled: true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: _aiMatchingLoading ? null : _rankWithAi,
                    icon: _aiMatchingLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      _aiMatchingLoading ? 'AI matching…' : '✨ Find Best Matches',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textPri,
                      side: BorderSide(color: _amber, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Only show available now', style: TextStyle(fontSize: 13)),
            value: _onlyAvailable,
            activeThumbColor: _amber,
            onChanged: (v) => setState(() => _onlyAvailable = v),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _contractorStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _amber));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var docs = snapshot.data?.docs ?? [];

                docs = docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final name = (d['fullName'] as String? ?? '').toLowerCase();
                  final skills = (d['skills'] as List?)?.map((e) => e.toString().toLowerCase()).join(' ') ?? '';
                  final available = d['available'] as bool? ?? false;

                  final matchesQuery = _query.isEmpty || name.contains(_query) || skills.contains(_query);
                  final matchesAvailable = !_onlyAvailable || available;

                  return matchesQuery && matchesAvailable;
                }).toList();

                _lastDocs = docs;

                // Sort by AI match score if available, otherwise by rating.
                docs.sort((a, b) {
                  final aMatch = _aiMatches[a.id];
                  final bMatch = _aiMatches[b.id];
                  if (aMatch != null && bMatch != null) {
                    return bMatch.score.compareTo(aMatch.score);
                  }
                  if (aMatch != null) return -1;
                  if (bMatch != null) return 1;
                  final aR = (a.data() as Map<String, dynamic>)['rating'] as num? ?? 0;
                  final bR = (b.data() as Map<String, dynamic>)['rating'] as num? ?? 0;
                  return bR.compareTo(aR);
                });

                if (docs.isEmpty) {
                  return const Center(child: Text('No contractors match your search.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data() as Map<String, dynamic>;
                    final match = _aiMatches[doc.id];
                    return ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ThekaydaarPublicProfile(thekaydaarUid: doc.id),
                        ),
                      ),
                      tileColor: _surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: match != null ? _amber : _border,
                          width: match != null ? 1.5 : 1,
                        ),
                      ),
                      leading: match != null
                          ? CircleAvatar(
                              radius: 18,
                              backgroundColor: _amberLight,
                              child: Text(
                                '${match.score}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _amberDark,
                                ),
                              ),
                            )
                          : null,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(d['fullName'] as String? ?? 'Contractor'),
                          ),
                          if (match != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _amberLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '✨ AI Match',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _amberDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(((d['skills'] as List?)?.join(' · ')) ?? '—'),
                          if (match != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                match.reason,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textSec.withValues(alpha: 0.9),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: Text('⭐ ${(d['rating'] ?? 0.0).toStringAsFixed(1)}'),
                    );
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